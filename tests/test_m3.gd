@tool
extends McpTestSuite
## M3 内容测试：樱桃炸弹、大嘴花、双发射手、旗帜波，以及 1-5~1-8 数据引用。

const LEVEL_SCENE := "res://scenes/level.tscn"


func suite_name() -> String:
	return "m3"


func _make_level(level_id: String = "1_1") -> Node:
	var packed := load(LEVEL_SCENE) as PackedScene
	assert_true(packed != null, "关卡场景必须存在")
	if packed == null:
		return null
	var level := packed.instantiate()
	level.level_data = load("res://resources/levels/%s.tres" % level_id)
	level._ready()
	level.debug_start_battle()
	level.debug_clear_waves()
	level.sun_total = 2000
	return level


func test_cherry_bomb_clears_neighbours() -> void:
	var level := _make_level()
	if level == null:
		return
	var bomb: Node = level.debug_spawn_plant("cherrybomb", Vector2i(4, 2))
	assert_true(bomb != null, "樱桃炸弹应可放置")
	var targets: Array = []
	for cell in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(4, 1)]:
		var zombie: Node = level.debug_spawn_zombie("normal", cell.y)
		zombie.position = LawnGrid.cell_center(cell)
		targets.append(zombie)
	level.debug_fast_forward(1.4)
	for zombie in targets:
		assert_true(zombie.is_dead(), "范围内的僵尸应被 1800 伤害炸死")
	assert_false(level._plants.has(Vector2i(4, 2)), "炸弹爆炸后应消失")
	level.free()


func test_chomper_eats_then_chews() -> void:
	var level := _make_level()
	if level == null:
		return
	var chomper: Node = level.debug_spawn_plant("chomper", Vector2i(2, 1))
	var zombie: Node = level.debug_spawn_zombie("normal", 1)
	zombie.position = LawnGrid.cell_center(Vector2i(2, 1)) + Vector2(70, 0)
	level.debug_fast_forward(0.3)
	assert_true(zombie.is_dead(), "大嘴花应一口吞掉僵尸")
	assert_true(chomper._chewing > 30.0, "吞噬后应进入约 40s 的咀嚼冷却")
	level.free()


func test_repeater_fires_two_peas() -> void:
	var level := _make_level()
	if level == null:
		return
	var plant: Node = level.debug_spawn_plant("repeater", Vector2i(0, 2))
	assert_true(plant != null, "双发射手应可放置")
	assert_eq(plant.data.shots_per_volley, 2, "双发射手每轮应有 2 发")
	var zombie: Node = level.debug_spawn_zombie("normal", 2)
	zombie.position.x = 300.0
	level.debug_fast_forward(0.5)
	assert_eq(level._projectiles.size(), 2, "一轮应生成 2 颗豌豆，实际 %d" % level._projectiles.size())
	level.debug_fast_forward(1.0)
	assert_eq(zombie.hp, 160, "一轮双发应造成 40 点伤害，实际 HP=%d" % zombie.hp)
	level.free()


func test_huge_wave_spawns_flag_zombie() -> void:
	var level := _make_level("1_8")
	if level == null:
		return
	assert_eq(level.data.id, "1_8", "关卡数据应为 1-8")
	assert_true(level.data.zombie_pool.has("flag"), "1-8 卡池应包含 flag")
	assert_true(GameCatalog.load_zombies().has("flag"), "僵尸目录应包含 flag")
	var director_script := ResourceLoader.load(
		"res://scripts/systems/wave_director.gd", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GDScript
	assert_true(director_script != null, "波次脚本应存在")
	var director: Node = director_script.new()
	director.setup(level, level.data)
	director._on_spawn_entry({"wave_index": 0, "is_huge": true, "time": 0.0})
	var flags := 0
	for zombie in level._zombies:
		if is_instance_valid(zombie) and zombie.data.id == "flag":
			flags += 1
	var ids: Array = []
	for zombie in level._zombies:
		ids.append(zombie.data.id if is_instance_valid(zombie) else "?")
	assert_true(flags >= 1, "旗帜波应额外生成旗帜僵尸；场上：%s" % str(ids))
	assert_eq(level._zombies.size(), 2, "旗帜波应生成 2 只僵尸；场上：%s" % str(ids))
	level.free()


func test_levels_1_5_to_1_8_reference_valid_ids() -> void:
	var plants := GameCatalog.load_plants()
	var zombies := GameCatalog.load_zombies()
	for level_id in ["1_5", "1_6", "1_7", "1_8"]:
		var level_data: LevelData = load("res://resources/levels/%s.tres" % level_id)
		assert_true(level_data != null, "关卡资源应存在：%s" % level_id)
		if level_data == null:
			continue
		assert_eq(level_data.id, level_id, "关卡 id 应与文件名一致")
		assert_true(level_data.waves.size() >= 2, "%s 至少两波" % level_id)
		for plant_id in level_data.available_plants:
			assert_true(plants.has(plant_id), "%s 引用了不存在的植物 %s" % [level_id, plant_id])
		for zombie_id in level_data.zombie_pool:
			assert_true(zombies.has(zombie_id), "%s 引用了不存在的僵尸 %s" % [level_id, zombie_id])
