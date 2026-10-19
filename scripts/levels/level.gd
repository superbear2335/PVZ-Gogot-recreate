@tool
extends Node2D
## 关卡总控（热重载由 script_patch 维护）：状态机、实体容器、阳光经济、输入与 UI 装配。
##
## 设计约定：
## - Level 是唯一持有实体数组的地方，按固定顺序 tick，保证可复现。
## - 实体不直接用 _physics_process，统一由 simulate() 驱动，测试可手动快进。
## - Ready/Set/Plant 倒计时、波次、房子扣血都使用 GameClock 的缩放 delta。

enum State { READY, SET, PLANT, PLAYING, WON, LOST, PAUSED }

const DEFAULT_LEVEL := "res://resources/levels/1_1.tres"
const PLANT_SCENE_PATH := "res://scenes/plant.tscn"
const ZOMBIE_SCENE_PATH := "res://scenes/zombie.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/projectile.tscn"
const SUN_SCENE_PATH := "res://scenes/sun.tscn"
const MOWER_SCENE_PATH := "res://scenes/mower.tscn"

const HOUSE_MAX_HP := 1000
const SUN_CAP := 9990
const SUN_COLLECT_RADIUS := 30.0

@export var level_data: LevelData

var data: LevelData
var clock := GameClock.new()
var signals: SignalHub
var state: int = State.READY
var _ready_voice_played := false
var sun_total := 0
var house_hp := HOUSE_MAX_HP
var wave_director: WaveDirector

var _plants: Dictionary = {}
var _zombies: Array = []
var _projectiles: Array = []
var _suns: Array = []
var _mowers: Array = []
var _house_timer := 0.0
var _has_background := false

var _plants_root: Node2D
var _zombies_root: Node2D
var _projectiles_root: Node2D
var _suns_root: Node2D
var _mowers_root: Node2D
var _ui_layer: CanvasLayer
var _card_bar: CardBar
var _banner: Label
var _tip: Label
var _wave_label: Label
var _end_overlay: Control
var _end_label: Label
var _pause_overlay: Control
var _pre_pause_state := State.PLAYING
var _banner_hidden_by_pause := false

var _plant_scene: PackedScene
var _zombie_scene: PackedScene
var _projectile_scene: PackedScene
var _sun_scene: PackedScene
var _mower_scene: PackedScene
var _plant_catalog: Dictionary = {}
var _zombie_catalog: Dictionary = {}

var _countdown := 0.0
var _banner_timer := 0.0
var _tip_timer := 0.0
var _sky_timer := 0.0
var _hover_cell := Vector2i(-1, -1)
var _selected_card := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	data = level_data
	var session: Node = null
	if is_inside_tree():
		session = get_node_or_null("/root/GameProgress")
	if session != null and not String(session.pending_level_id).is_empty():
		var pending := load("res://resources/levels/%s.tres" % String(session.pending_level_id)) as LevelData
		if pending != null:
			data = pending
	if data == null:
		data = load(DEFAULT_LEVEL) as LevelData
	if data == null:
		push_error("Level：找不到关卡数据，无法启动。")
		return
	clock = GameClock.new(data.seed_value)
	_rng.seed = data.seed_value + 7919
	sun_total = data.starting_sun
	house_hp = HOUSE_MAX_HP
	_plant_catalog = GameCatalog.load_plants()
	_zombie_catalog = GameCatalog.load_zombies()
	_plant_scene = load(PLANT_SCENE_PATH)
	_zombie_scene = load(ZOMBIE_SCENE_PATH)
	_projectile_scene = load(PROJECTILE_SCENE_PATH)
	_sun_scene = load(SUN_SCENE_PATH)
	_mower_scene = load(MOWER_SCENE_PATH)
	_build_background()
	_build_containers()
	_build_ui()
	wave_director = WaveDirector.new()
	wave_director.name = "WaveDirector"
	add_child(wave_director)
	wave_director.setup(self, data)
	signals.sun_changed.emit(sun_total)
	_play_music("day")
	_begin_countdown()
	queue_redraw()
	if is_inside_tree():
		_fade_in()


func _fade_in() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.size = Vector2(800, 600)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.35)
	tween.finished.connect(func() -> void: layer.queue_free())


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	simulate(delta)


# ---------------------------------------------------------------- 主循环

func simulate(delta: float) -> void:
	if state == State.WON or state == State.LOST or state == State.PAUSED:
		return
	var scaled := clock.tick(delta)
	if _banner_timer > 0.0:
		_banner_timer -= scaled
		if _banner_timer <= 0.0 and _banner != null:
			_banner.visible = false
	if _tip_timer > 0.0:
		_tip_timer -= scaled
		if _tip_timer <= 0.0 and _tip != null:
			_tip.visible = false
	match state:
		State.READY:
			if not _ready_voice_played:
				_ready_voice_played = true
				_play_sfx("ready_set_plant")
			_advance_countdown(scaled, State.SET, "Set!", 1.5)
		State.SET:
			_advance_countdown(scaled, State.PLANT, "Plant!", 1.5)
		State.PLANT:
			_advance_countdown(scaled, State.PLAYING, "", 2.0)
		State.PLAYING:
			_tick_playing(scaled)


func _advance_countdown(delta: float, next_state: int, next_text: String, next_time: float) -> void:
	_countdown -= delta
	if _countdown > 0.0:
		return
	state = next_state
	_countdown = next_time
	if not next_text.is_empty():
		_show_banner(next_text)
	elif next_state == State.PLAYING:
		_banner.visible = false
		_start_battle()


func _start_battle() -> void:
	_sky_timer = data.sky_sun_first
	wave_director.start()


func _tick_playing(delta: float) -> void:
	_card_bar.tick(delta)
	_sky_timer -= delta
	if _sky_timer <= 0.0:
		spawn_sky_sun()
		_sky_timer = _rng.randf_range(data.sky_sun_min, data.sky_sun_max)
	for cell in _plants.keys():
		var plant = _plants[cell]
		if is_instance_valid(plant) and plant.alive():
			plant.tick(delta)
	for zombie in _zombies:
		if is_instance_valid(zombie):
			zombie.tick(delta)
	for mower in _mowers:
		if is_instance_valid(mower):
			mower.tick(delta)
	_trigger_mowers()
	for projectile in _projectiles:
		if is_instance_valid(projectile):
			projectile.tick(delta)
	for sun in _suns:
		if is_instance_valid(sun):
			sun.tick(delta)
	wave_director.tick(delta)
	_update_house(delta)
	_cleanup()
	_update_wave_label()


func _update_house(delta: float) -> void:
	var under_attack := false
	for zombie in _zombies:
		if is_instance_valid(zombie) and zombie.reached_house():
			under_attack = true
			break
	if not under_attack:
		return
	_house_timer += delta
	var dps := 100.0 if _house_timer < 5.0 else 500.0
	house_hp -= dps * delta
	if house_hp <= 0.0:
		house_hp = 0.0
		_on_defeat()


func _cleanup() -> void:
	for i in range(_plants.keys().size() - 1, -1, -1):
		var cell: Vector2i = _plants.keys()[i]
		var plant = _plants[cell]
		if not is_instance_valid(plant) or not plant.alive():
			_plants.erase(cell)
	for i in range(_zombies.size() - 1, -1, -1):
		if not is_instance_valid(_zombies[i]) or _zombies[i].is_dead():
			_zombies.remove_at(i)
	for i in range(_projectiles.size() - 1, -1, -1):
		if not is_instance_valid(_projectiles[i]) or _projectiles[i].is_dead():
			_projectiles.remove_at(i)
	for i in range(_suns.size() - 1, -1, -1):
		if not is_instance_valid(_suns[i]):
			_suns.remove_at(i)
	for i in range(_mowers.size() - 1, -1, -1):
		if not is_instance_valid(_mowers[i]):
			_mowers.remove_at(i)


# ---------------------------------------------------------------- 关卡结束

func on_victory() -> void:
	if state == State.WON or state == State.LOST:
		return
	state = State.WON
	_show_end("关卡胜利！", Color("ffe98a"))
	signals.level_won.emit()
	var session := get_node_or_null("/root/GameProgress")
	if session != null and data != null:
		session.unlock_next(session.level_number_from_id(data.id))


func _on_defeat() -> void:
	if state == State.WON or state == State.LOST:
		return
	state = State.LOST
	_show_end("僵尸吃掉了你的脑子……", Color("ff8a8a"))
	signals.level_lost.emit()


func _show_end(text: String, color: Color) -> void:
	_banner.visible = false
	_hover_cell = Vector2i(-1, -1)
	queue_redraw()
	_end_overlay.visible = true
	_end_label.text = text
	_end_label.add_theme_color_override("font_color", color)
	_card_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _restart() -> void:
	if get_tree() != null and get_tree().current_scene != null:
		get_tree().reload_current_scene()


func _return_to_menu() -> void:
	_play_music("menu")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func toggle_pause() -> void:
	if state == State.PAUSED:
		_resume_game()
	elif state in [State.READY, State.SET, State.PLANT, State.PLAYING]:
		_pause_game()


func _pause_game() -> void:
	if state == State.PAUSED:
		return
	_pre_pause_state = state
	state = State.PAUSED
	_selected_card = -1
	_card_bar.clear_selection()
	_hover_cell = Vector2i(-1, -1)
	_banner_hidden_by_pause = _banner.visible
	if _banner_hidden_by_pause:
		_banner.visible = false
	_pause_overlay.visible = true
	_card_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _resume_game() -> void:
	if state != State.PAUSED:
		return
	state = _pre_pause_state
	_pause_overlay.visible = false
	if _banner_hidden_by_pause:
		_banner.visible = true
		_banner_hidden_by_pause = false
	_card_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func is_paused() -> bool:
	return state == State.PAUSED


func _audio_root() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/AudioManager")


func _play_sfx(id: String) -> void:
	var audio := _audio_root()
	if audio != null:
		audio.play_sfx(id)


func play_sfx(id: String) -> void:
	_play_sfx(id)


func _play_music(id: String) -> void:
	var audio := _audio_root()
	if audio != null:
		audio.play_music(id)


func _on_plant_placed_sfx(_plant: Node) -> void:
	_play_sfx("plant")


func _on_sun_collected_sfx(_value: int, _at: Vector2) -> void:
	_play_sfx("sun")


func _on_zombie_died_sfx(_zombie: Node) -> void:
	_play_sfx("zombie_die")


func _on_wave_started_sfx(_index: int, is_huge: bool) -> void:
	if is_huge:
		_play_sfx("huge_wave")


func _on_victory_sfx() -> void:
	_play_sfx("win")


func _on_defeat_sfx() -> void:
	_play_sfx("lose")


# ---------------------------------------------------------------- 输入

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := LawnGrid.world_to_cell(_screen_to_world(motion.position))
		if cell != _hover_cell:
			_hover_cell = cell
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(_screen_to_world(mouse.position))
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				clock.time_scale = 1.0
			KEY_2:
				clock.time_scale = 2.0
			KEY_3:
				clock.time_scale = 3.0
			KEY_ESCAPE:
				if state == State.WON or state == State.LOST:
					_return_to_menu()
				else:
					toggle_pause()
			KEY_R:
				if state == State.WON or state == State.LOST:
					_restart()
			KEY_ENTER, KEY_KP_ENTER:
				if state == State.WON or state == State.LOST:
					_return_to_menu()


func _handle_click(world_position: Vector2) -> void:
	var sun := _sun_at(world_position)
	if sun != null:
		collect_sun(sun)
		return
	if state != State.PLAYING:
		return
	var cell := LawnGrid.world_to_cell(world_position)
	if not LawnGrid.is_valid_cell(cell):
		return
	if _selected_card >= 0:
		try_plant(_selected_card, cell)


func try_plant(card_index: int, cell: Vector2i) -> bool:
	if card_index < 0 or card_index >= _card_bar.plant_datas.size():
		return false
	var plant_data: PlantData = _card_bar.plant_datas[card_index]
	if _plants.has(cell) and is_instance_valid(_plants[cell]) and _plants[cell].alive():
		return false
	if sun_total < plant_data.cost:
		_flash_tip("阳光不足")
		return false
	if _card_bar.is_on_cooldown(card_index):
		return false
	sun_total -= plant_data.cost
	signals.sun_changed.emit(sun_total)
	_card_bar.set_sun(sun_total)
	_card_bar.start_cooldown(card_index)
	_selected_card = -1
	var plant := _plant_scene.instantiate()
	_plants_root.add_child(plant)
	plant.setup(plant_data, cell, self)
	_plants[cell] = plant
	signals.plant_placed.emit(plant)
	queue_redraw()
	return true


# ---------------------------------------------------------------- 生成

func spawn_zombie(zombie_id: String, row: int) -> Node:
	var zombie_data: ZombieData = _zombie_catalog.get(zombie_id)
	if zombie_data == null:
		var keys := _zombie_catalog.keys()
		if keys.is_empty():
			push_error("Level：僵尸目录为空")
			return null
		zombie_data = _zombie_catalog[keys[0]]
	var zombie := _zombie_scene.instantiate()
	_zombies_root.add_child(zombie)
	zombie.setup(zombie_data, row, self)
	_zombies.append(zombie)
	signals.zombie_spawned.emit(zombie)
	return zombie


func spawn_plant_sun(plant: Node) -> void:
	if _suns.size() >= 12:
		return
	var sun := _sun_scene.instantiate()
	_suns_root.add_child(sun)
	sun.position = plant.position + Vector2(0, -34)
	sun.target_y = sun.position.y
	sun.setup(data.sun_value, false, self)
	_suns.append(sun)


func spawn_sky_sun() -> void:
	if _suns.size() >= 12:
		return
	var sun := _sun_scene.instantiate()
	_suns_root.add_child(sun)
	sun.position = Vector2(_rng.randf_range(40.0, 760.0), -30.0)
	sun.target_y = _rng.randf_range(100.0, 560.0)
	sun.setup(data.sun_value, true, self)
	_suns.append(sun)


func spawn_projectile(plant: Node, plant_data: PlantData) -> void:
	if _projectiles.size() >= 120 or plant_data.projectile_scene == null:
		return
	var projectile := _projectile_scene.instantiate()
	_projectiles_root.add_child(projectile)
	projectile.position = plant.position + Vector2(24, -30)
	projectile.setup(
		plant_data.damage, plant_data.projectile_speed, plant.cell.y, self,
		plant_data.projectile_color, plant_data.slow_factor, plant_data.slow_duration,
	)
	_projectiles.append(projectile)


func collect_sun(sun: Node) -> void:
	if sun == null or not sun.collect():
		return
	sun_total = mini(SUN_CAP, sun_total + int(sun.value))
	signals.sun_changed.emit(sun_total)
	signals.sun_collected.emit(int(sun.value), sun.global_position)
	_card_bar.set_sun(sun_total)
	sun.queue_free()


# ---------------------------------------------------------------- 查询

func has_zombie_ahead(row: int, from_x: float, range_px: float = 0.0) -> bool:
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead() or zombie.row != row:
			continue
		if zombie.position.x < from_x:
			continue
		if range_px <= 0.0 or zombie.position.x - from_x <= range_px:
			return true
	return false


func find_zombie_in_row_at(row: int, x: float) -> Node:
	var best: Node = null
	var best_distance := 26.0
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead() or zombie.row != row:
			continue
		var distance := absf(zombie.position.x - x)
		if distance <= best_distance:
			best = zombie
			best_distance = distance
	return best


func find_plant_at_world(world_position: Vector2) -> Node:
	var cell := LawnGrid.world_to_cell(world_position)
	if not _plants.has(cell):
		return null
	var plant = _plants[cell]
	return plant if is_instance_valid(plant) and plant.alive() else null


func alive_zombie_count() -> int:
	var count := 0
	for zombie in _zombies:
		if is_instance_valid(zombie) and not zombie.is_dead():
			count += 1
	return count


func pick_spawn_row() -> int:
	return _rng.randi_range(0, LawnGrid.ROWS - 1)


func _sun_at(world_position: Vector2) -> Node:
	for sun in _suns:
		if not is_instance_valid(sun) or sun.is_collected():
			continue
		if sun.global_position.distance_to(world_position) <= SUN_COLLECT_RADIUS:
			return sun
	return null


func zombie_on_cell(cell: Vector2i) -> bool:
	var center_x := LawnGrid.cell_center(cell).x
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead() or zombie.row != cell.y:
			continue
		if absf(zombie.position.x - center_x) <= 44.0:
			return true
	return false


func zombie_in_front(row: int, from_x: float, range_px: float) -> Node:
	var best: Node = null
	var best_dx := INF
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead() or zombie.row != row:
			continue
		var dx: float = zombie.position.x - from_x
		if dx < 0.0:
			continue
		if range_px > 0.0 and dx > range_px:
			continue
		if dx < best_dx:
			best_dx = dx
			best = zombie
	return best


func plant_in_front(row: int, from_x: float, range_px: float) -> Node:
	var best: Node = null
	var best_dx := range_px
	for cell in _plants.keys():
		if cell.y != row:
			continue
		var plant = _plants[cell]
		if not is_instance_valid(plant) or not plant.alive():
			continue
		var dx: float = from_x - plant.position.x
		if dx < 0.0 or dx > best_dx:
			continue
		best = plant
		best_dx = dx
	return best


func explode_at(world_position: Vector2, damage: int, radius_cells: float) -> void:
	_play_sfx("cherrybomb")
	var origin_cell := LawnGrid.world_to_cell(world_position)
	if not LawnGrid.is_valid_cell(origin_cell):
		return
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead():
			continue
		if absi(zombie.row - origin_cell.y) > int(ceil(radius_cells)):
			continue
		if absf(zombie.position.x - world_position.x) <= radius_cells * LawnGrid.CELL_SIZE.x + 32.0:
			zombie.take_damage(damage)


func mower_for_row(row: int) -> Node:
	for mower in _mowers:
		if is_instance_valid(mower) and mower.row == row and not mower.used:
			return mower
	return null


func mower_hit_row(mower: Node, row: int) -> void:
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead() or zombie.row != row:
			continue
		if absf(zombie.position.x - mower.position.x) <= 44.0:
			zombie.take_damage(99999)


func _trigger_mowers() -> void:
	for zombie in _zombies:
		if not is_instance_valid(zombie) or zombie.is_dead() or zombie.reached_house():
			continue
		if zombie.position.x >= LawnGrid.MOWER_TRIGGER_X:
			continue
		var mower := mower_for_row(zombie.row)
		if mower != null:
			mower.trigger()
			_play_sfx("mower")


# ---------------------------------------------------------------- UI

func _build_background() -> void:
	var tex := PvzAssets.background()
	if tex == null:
		return
	# background1.jpg 为 1400×600，裁掉左侧 200px 房子外景，使草坪从 x=40 开始。
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(200, 0, 800, 600)
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.texture = atlas
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.z_index = -20
	add_child(bg)
	_has_background = true


func _build_containers() -> void:
	signals = SignalHub.new()
	signals.name = "Signals"
	add_child(signals)
	_plants_root = _make_layer("Plants")
	_zombies_root = _make_layer("Zombies")
	_projectiles_root = _make_layer("Projectiles")
	_suns_root = _make_layer("Suns")
	_mowers_root = _make_layer("Mowers")
	signals.plant_placed.connect(_on_plant_placed_sfx)
	signals.sun_collected.connect(_on_sun_collected_sfx)
	signals.zombie_died.connect(_on_zombie_died_sfx)
	signals.wave_started.connect(_on_wave_started_sfx)
	signals.level_won.connect(_on_victory_sfx)
	signals.level_lost.connect(_on_defeat_sfx)
	for row in LawnGrid.ROWS:
		var mower := _mower_scene.instantiate()
		_mowers_root.add_child(mower)
		mower.setup(row, self)
		_mowers.append(mower)


func _make_layer(layer_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = layer_name
	add_child(node)
	return node


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_card_bar = CardBar.new()
	_card_bar.name = "CardBar"
	_ui_layer.add_child(_card_bar)
	_card_bar.setup(self, data.available_plants)
	_card_bar.set_sun(sun_total)
	_card_bar.card_selected.connect(_on_card_selected)

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.position = Vector2(0, 170)
	_banner.size = Vector2(800, 90)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 38)
	_banner.add_theme_color_override("font_color", Color("fff6d0"))
	_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.04))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.visible = false
	_ui_layer.add_child(_banner)

	_tip = Label.new()
	_tip.name = "Tip"
	_tip.position = Vector2(100, 548)
	_tip.size = Vector2(600, 28)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_font_size_override("font_size", 14)
	_tip.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 0.9))
	_tip.visible = false
	_ui_layer.add_child(_tip)

	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.position = Vector2(636, 556)
	_wave_label.size = Vector2(158, 24)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.85, 0.85))
	_ui_layer.add_child(_wave_label)

	_end_overlay = Control.new()
	_end_overlay.name = "EndOverlay"
	_end_overlay.size = Vector2(800, 600)
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.visible = false
	_ui_layer.add_child(_end_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.01, 0.62)
	dim.size = Vector2(800, 600)
	_end_overlay.add_child(dim)
	_end_label = Label.new()
	_end_label.position = Vector2(0, 230)
	_end_label.size = Vector2(800, 90)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 40)
	_end_label.add_theme_color_override("font_color", Color("ffe98a"))
	_end_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_end_label.add_theme_constant_override("outline_size", 6)
	_end_overlay.add_child(_end_label)
	var hint := Label.new()
	hint.position = Vector2(0, 330)
	hint.size = Vector2(800, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "按 R 重新开始 · Enter 返回选关"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.87, 0.8))
	_end_overlay.add_child(hint)

	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.size = Vector2(800, 600)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	_ui_layer.add_child(_pause_overlay)
	var pause_dim := ColorRect.new()
	pause_dim.color = Color(0.02, 0.04, 0.01, 0.68)
	pause_dim.size = Vector2(800, 600)
	_pause_overlay.add_child(pause_dim)
	var pause_title := Label.new()
	pause_title.position = Vector2(0, 150)
	pause_title.size = Vector2(800, 80)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.text = "已暂停"
	pause_title.add_theme_font_size_override("font_size", 44)
	pause_title.add_theme_color_override("font_color", Color("f3f0d2"))
	pause_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	pause_title.add_theme_constant_override("outline_size", 6)
	_pause_overlay.add_child(pause_title)
	var pause_box := VBoxContainer.new()
	pause_box.position = Vector2(270, 270)
	pause_box.size = Vector2(260, 190)
	pause_box.add_theme_constant_override("separation", 12)
	_pause_overlay.add_child(pause_box)
	for entry in [
		["继续游戏", _resume_game],
		["重新开始", _restart],
		["返回选关", _return_to_menu],
	]:
		var button := Button.new()
		button.text = String(entry[0])
		button.custom_minimum_size = Vector2(260, 46)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(entry[1])
		pause_box.add_child(button)
	var pause_hint := Label.new()
	pause_hint.position = Vector2(0, 480)
	pause_hint.size = Vector2(800, 28)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.text = "按 Esc 继续"
	pause_hint.add_theme_font_size_override("font_size", 15)
	pause_hint.add_theme_color_override("font_color", Color(0.82, 0.85, 0.76))
	_pause_overlay.add_child(pause_hint)


func _begin_countdown() -> void:
	state = State.READY
	_countdown = 1.5
	_show_banner("Ready?")


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func show_huge_wave_banner() -> void:
	_show_banner("一大波僵尸正在接近！")
	_banner_timer = 3.0


func _flash_tip(text: String) -> void:
	_tip.text = text
	_tip.visible = true
	_tip_timer = 1.4


func _on_card_selected(index: int) -> void:
	_selected_card = index
	if index >= 0:
		_play_sfx("click")
	queue_redraw()


func _update_wave_label() -> void:
	if _wave_label == null or wave_director == null:
		return
	var total := wave_director.total_waves()
	var started := clampi(wave_director.waves_started(), 0, total)
	_wave_label.text = "波次 %d / %d" % [started, total]


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	if not _has_background:
		draw_rect(Rect2(0, 0, 800, 600), Color("3c5a1b"))
		for row in LawnGrid.ROWS:
			for col in LawnGrid.COLS:
				var cell := Vector2i(col, row)
				var light := (row + col) % 2 == 0
				var color := Color("6f9a2e") if light else Color("5f8726")
				draw_rect(LawnGrid.cell_rect(cell), color)
		# 左侧房子墙体 + 车道
		draw_rect(Rect2(0, 80, 40, 500), Color("8a6a44"))
		for y in range(88, 580, 26):
			draw_line(Vector2(0, y), Vector2(40, y + 14), Color(0.36, 0.25, 0.14, 0.5), 2.0)
		# 网格弱分隔线
		for col in range(LawnGrid.COLS + 1):
			var x := LawnGrid.ORIGIN.x + col * LawnGrid.CELL_SIZE.x
			draw_line(Vector2(x, 80), Vector2(x, 580), Color(0.15, 0.25, 0.08, 0.25), 1.0)
		for row in range(LawnGrid.ROWS + 1):
			var y := LawnGrid.ORIGIN.y + row * LawnGrid.CELL_SIZE.y
			draw_line(Vector2(40, y), Vector2(760, y), Color(0.15, 0.25, 0.08, 0.25), 1.0)
	# 种植预览
	if state == State.PLAYING and _card_bar != null:
		var plant_data := _card_bar.selected_data()
		if plant_data != null and LawnGrid.is_valid_cell(_hover_cell):
			var occupied: bool = _plants.has(_hover_cell) and is_instance_valid(_plants[_hover_cell]) and _plants[_hover_cell].alive()
			var ok: bool = not occupied and sun_total >= plant_data.cost
			var tint := Color(0.4, 1.0, 0.4, 0.28) if ok else Color(1.0, 0.3, 0.3, 0.32)
			draw_rect(LawnGrid.cell_rect(_hover_cell), tint)
			if ok:
				draw_circle(LawnGrid.cell_center(_hover_cell) + Vector2(0, -12), 14.0, Color(0.4, 1.0, 0.4, 0.45))


# ---------------------------------------------------------------- 测试钩子

func debug_start_battle() -> void:
	state = State.PLAYING
	_countdown = 0.0
	if _banner != null:
		_banner.visible = false
	if wave_director != null:
		wave_director.start()


func debug_clear_waves() -> void:
	if wave_director != null:
		wave_director._schedule.clear()


func debug_spawn_plant(plant_id: String, cell: Vector2i) -> Node:
	var plant_data: PlantData = _plant_catalog.get(plant_id)
	if plant_data == null or _plants.has(cell):
		return null
	var plant := _plant_scene.instantiate()
	_plants_root.add_child(plant)
	plant.setup(plant_data, cell, self)
	_plants[cell] = plant
	return plant


func debug_spawn_zombie(zombie_id: String, row: int) -> Node:
	return spawn_zombie(zombie_id, row)


func debug_fast_forward(seconds: float) -> void:
	var step := 1.0 / 60.0
	var remaining := seconds
	while remaining > 0.0:
		simulate(minf(step, remaining))
		remaining -= step


func debug_suns() -> Array:
	return _suns


func debug_mowers() -> Array:
	return _mowers
