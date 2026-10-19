@tool
extends Node2D
## 主菜单 / 关卡选择（@tool 以便编辑器内测试直接调用 _ready；script_patch 热重载）。
##
## 布局：标题、状态、[继续/音效/音乐] 操作行、10 个关卡按钮。
## 解锁与设置来自 autoload GameProgress；音频来自 autoload AudioManager。

const LEVEL_SCENE := "res://scenes/level.tscn"
const LEVEL_COUNT := 10

var _title_label: Label
var _status_label: Label
var _layout: VBoxContainer
var _grid: GridContainer

var _progress: Node
var _audio: Node
var _level_buttons: Array[Button] = []
var _continue_button: Button
var _sfx_button: Button
var _music_button: Button


func _ready() -> void:
	_title_label = $UI/Layout/TitleLabel
	_status_label = $UI/Layout/StatusLabel
	_layout = $UI/Layout
	_progress = null
	_audio = null
	if is_inside_tree():
		_progress = get_node_or_null("/root/GameProgress")
		_audio = get_node_or_null("/root/AudioManager")
	_title_label.text = "植物大战僵尸 · Godot 复刻"
	_title_label.add_theme_color_override("font_color", Color("f2ffc4"))
	_title_label.add_theme_color_override("font_outline_color", Color("22330a"))
	_title_label.add_theme_constant_override("outline_size", 8)
	_status_label.text = "选择关卡"
	_status_label.add_theme_color_override("font_outline_color", Color("22330a"))
	_status_label.add_theme_constant_override("outline_size", 5)
	_build_background()
	_build_controls()
	_build_level_grid()
	_refresh_buttons()
	if _audio != null:
		_audio.play_music("menu")
	if is_inside_tree():
		_fade_in()


func _build_background() -> void:
	var ui := $UI as CanvasLayer
	var fallback := ui.get_node_or_null("Background") as CanvasItem
	if fallback != null:
		fallback.visible = false
	var tex := PvzAssets.background()
	if tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(200, 0, 800, 600)
		var rect := TextureRect.new()
		rect.name = "ArtBackground"
		rect.texture = atlas
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.size = Vector2(800, 600)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(rect)
		ui.move_child(rect, 0)


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


func _build_controls() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_layout.add_child(row)
	_continue_button = _make_button("继续游戏", 150)
	_continue_button.pressed.connect(_on_continue_pressed)
	row.add_child(_continue_button)
	_sfx_button = _make_button("音效：开", 110)
	_sfx_button.pressed.connect(_on_toggle_sfx)
	row.add_child(_sfx_button)
	_music_button = _make_button("音乐：开", 110)
	_music_button.pressed.connect(_on_toggle_music)
	row.add_child(_music_button)


func _make_button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 34)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("ffeec2"))
	button.add_theme_color_override("font_disabled_color", Color("9fae86"))
	_style_button(button)
	return button


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _wood_box(Color("4a2f1a"), Color("2a1a0d")))
	button.add_theme_stylebox_override("hover", _wood_box(Color("6b4426"), Color("3a2412")))
	button.add_theme_stylebox_override("pressed", _wood_box(Color("2f1d10"), Color("1c1108")))
	button.add_theme_stylebox_override("disabled", _wood_box(Color("2f3a22"), Color("1c2314")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _wood_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


func _build_level_grid() -> void:
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_layout.add_child(_grid)
	for i in LEVEL_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 54)
		button.text = "1-%d" % (i + 1)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("ffeec2"))
		button.add_theme_color_override("font_disabled_color", Color("9fae86"))
		_style_button(button)
		button.pressed.connect(_on_level_pressed.bind(i + 1))
		_grid.add_child(button)
		_level_buttons.append(button)


func _refresh_buttons() -> void:
	var unlocked := 1
	var last_played := 1
	var sfx_muted := false
	var music_muted := false
	if _progress != null:
		unlocked = int(_progress.unlocked_level)
		last_played = int(_progress.last_played)
		sfx_muted = bool(_progress.sfx_muted)
		music_muted = bool(_progress.music_muted)
	for i in _level_buttons.size():
		var button := _level_buttons[i]
		button.disabled = i + 1 > unlocked
		button.tooltip_text = "" if not button.disabled else "通关前一关后解锁"
		if button.disabled:
			button.text = "1-%d 🔒" % (i + 1)
		else:
			button.text = "1-%d" % (i + 1)
	if _continue_button != null:
		var continue_level := clampi(last_played, 1, unlocked)
		_continue_button.text = "继续 1-%d" % continue_level
		_continue_button.disabled = unlocked < 1
	if _sfx_button != null:
		_sfx_button.text = "音效：关" if sfx_muted else "音效：开"
	if _music_button != null:
		_music_button.text = "音乐：关" if music_muted else "音乐：开"


func _on_continue_pressed() -> void:
	var target := 1
	if _progress != null:
		target = clampi(int(_progress.last_played), 1, int(_progress.unlocked_level))
	_on_level_pressed(target)


func _on_toggle_sfx() -> void:
	if _progress == null:
		return
	_progress.sfx_muted = not bool(_progress.sfx_muted)
	_progress.save_progress()
	_refresh_buttons()
	if _audio != null:
		_audio.apply_volumes()


func _on_toggle_music() -> void:
	if _progress == null:
		return
	_progress.music_muted = not bool(_progress.music_muted)
	_progress.save_progress()
	_refresh_buttons()
	if _audio != null:
		_audio.apply_volumes()
		if bool(_progress.music_muted):
			_audio.stop_music()
		else:
			_audio.play_music("menu")


func _on_level_pressed(level_number: int) -> void:
	var level_id := "1_%d" % level_number
	if _audio != null:
		_audio.play_sfx("click")
	if _progress != null:
		_progress.select_level(level_id)
	else:
		push_warning("GameProgress autoload 不存在，直接加载关卡")
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
