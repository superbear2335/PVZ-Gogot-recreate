@tool
extends McpTestSuite
## M2 行为测试：坚果阻挡、寒冰减速、地雷布防、小推车、撑杆跳、关卡数据引用。

const LEVEL_SCENE := "res://scenes/level.tscn"

const STATE_PLAYING := 3
const STATE_LOST := 5


func suite_name() -> String:
	return "behaviors"


func _make_level() -> Node:
	var packed := load(LEVEL_SCENE) as PackedScene
	assert_true(packed != null, "关卡场景必须存在")
	if packed == null:
		return null
	var level := packed.instantiate()
	level._ready()
	level.debug_start_battle()
	level.debug_clear_waves()
	level.sun_total = 1000
	return level


func test_wallnut_blocks_without_dying() -> void:
	var level := _make_level()
	if level == null:
		return
	var wallnut: Node = level.debug_spawn_plant("wallnut", Vector2i(3, 1))
	assert_true(wallnut != null, "坚果墙应成功放置")
	assert_eq(wallnut.hp, 4000, "坚果墙 HP 应为 4000")
	var zombie: Node = level.debug_spawn_zombie("normal", 1)
	zombie.position.x = wallnut.position.x + 10.0
	level.debug_fast_forward(10.0)
	assert_true(wallnut.alive(), "坚果墙 10s 内不应被啃死（4000 HP / 60 DPS）")
	assert_eq(zombie.state, "eat", "僵尸应停下啃坚果")
	assert_true(zombie.position.x > 300.0, "僵尸不应穿过坚果墙")
	level.free()


func test_snowpea_applies_slow() -> void:
	var level := _make_level()
	if level == null:
		return
	var snowpea: Node = level.debug_spawn_plant("snowpea", Vector2i(1, 2))
	assert_true(snowpea != null, "寒冰射手应成功放置")
	var zombie: Node = level.debug_spawn_zombie("normal", 2)
	zombie.position.x = 480.0
	level.debug_fast_forward(2.0)
	assert_true(zombie.alive(), "2s 内僵尸不应死亡")
	assert_true(zombie.is_slowed(), "寒冰豌豆命中后应进入减速状态")
	assert_true(zombie.hp < 200, "寒冰豌豆应造成 20 点伤害")
	level.debug_fast_forward(5.0)
	assert_true(zombie.alive(), "减速状态不应叠加成秒杀")
	level.free()


func test_potato_mine_arms_then_kills() -> void:
	var level := _make_level()
	if level == null:
		return
	var cell := Vector2i(4, 3)
	var mine: Node = level.debug_spawn_plant("potatomine", cell)
	assert_true(mine != null, "土豆雷应成功放置")
	level.debug_fast_forward(15.2)
	assert_true(mine._armed, "15s 后土豆雷应完成布防")
	var zombie: Node = level.debug_spawn_zombie("normal", 3)
	zombie.position = LawnGrid.cell_center(cell)
	level.debug_fast_forward(0.3)
	assert_true(not is_instance_valid(zombie) or zombie.is_dead(), "僵尸踩雷应被 1800 伤害击杀")
	assert_false(level._plants.has(cell), "土豆雷爆炸后应从格子移除")
	level.free()


func test_mower_saves_row_once() -> void:
	var level := _make_level()
	if level == null:
		return
	var zombie: Node = level.debug_spawn_zombie("normal", 0)
	zombie.position.x = 20.0
	level.debug_fast_forward(1.0)
	assert_true(not is_instance_valid(zombie) or zombie.is_dead(), "小推车应击杀越线僵尸")
	var mower: Node = null
	for candidate in level.debug_mowers():
		if candidate.row == 0:
			mower = candidate
	assert_true(mower != null and mower.used, "该行小推车应已被使用")
	# 第二只僵尸越线时该行已无小推车，房子应被打穿。
	var second: Node = level.debug_spawn_zombie("normal", 0)
	second.position.x = 1.0
	level.debug_fast_forward(12.0)
	assert_eq(level.state, STATE_LOST, "没有小推车后僵尸进屋应判负")
	level.free()


func test_pole_vaults_first_plant() -> void:
	var level := _make_level()
	if level == null:
		return
	var wallnut: Node = level.debug_spawn_plant("wallnut", Vector2i(3, 1))
	assert_true(wallnut != null, "坚果墙应成功放置")
	var zombie: Node = level.debug_spawn_zombie("pole", 1)
	assert_true(zombie != null, "撑杆跳僵尸应成功生成")
	zombie.position.x = wallnut.position.x + 90.0
	level.debug_fast_forward(2.5)
	assert_true(wallnut.alive(), "撑杆跳僵尸不应啃到坚果")
	assert_false(zombie.has_pole(), "撑杆应已被丢弃")
	assert_true(zombie.position.x < wallnut.position.x - 40.0, "僵尸应已跳过坚果落到左侧")
	level.free()


func test_levels_1_2_to_1_4_reference_valid_ids() -> void:
	var plants := GameCatalog.load_plants()
	var zombies := GameCatalog.load_zombies()
	for level_id in ["1_2", "1_3", "1_4"]:
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
