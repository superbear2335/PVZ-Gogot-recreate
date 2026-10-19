@tool
extends McpTestSuite
## M1 关卡玩法测试（script_patch 热重载）：实例化关卡后手动调用 _ready()，不依赖编辑器打开的场景，
## 用 debug_fast_forward 以固定 60Hz 步进模拟，保证与运行时同一套代码路径。

const LEVEL_SCENE := "res://scenes/level.tscn"

const STATE_READY := 0
const STATE_SET := 1
const STATE_PLANT := 2
const STATE_PLAYING := 3
const STATE_WON := 4
const STATE_LOST := 5


func suite_name() -> String:
	return "level"


func _make_level() -> Node:
	var packed := load(LEVEL_SCENE) as PackedScene
	assert_true(packed != null, "关卡场景必须存在")
	if packed == null:
		return null
	var level := packed.instantiate()
	level._ready()
	return level


func test_countdown_flow() -> void:
	var level := _make_level()
	if level == null:
		return
	assert_eq(level.state, STATE_READY, "开局应为 Ready")
	level.debug_fast_forward(1.6)
	assert_eq(level.state, STATE_SET, "1.5s 后进入 Set")
	level.debug_fast_forward(1.6)
	assert_eq(level.state, STATE_PLANT, "再过 1.5s 进入 Plant")
	level.debug_fast_forward(2.1)
	assert_eq(level.state, STATE_PLAYING, "Plant 2s 后进入战斗")
	level.free()


func test_plant_shoots_zombie() -> void:
	var level := _make_level()
	if level == null:
		return
	level.debug_start_battle()
	level.debug_clear_waves()
	var plant: Node = level.debug_spawn_plant("peashooter", Vector2i(1, 2))
	assert_true(plant != null, "豌豆射手应成功放置")
	var zombie: Node = level.debug_spawn_zombie("normal", 2)
	assert_true(zombie != null, "普通僵尸应成功生成")
	zombie.position.x = 480.0
	level.debug_fast_forward(9.0)
	var dead_or_hurt: bool = not is_instance_valid(zombie) or zombie.is_dead() or zombie.hp < 200
	assert_true(dead_or_hurt, "豌豆必须命中并造成伤害")
	assert_true(is_instance_valid(plant) and plant.alive(), "豌豆射手不应在 9s 内被吃")
	level.free()


func test_sun_collection() -> void:
	var level := _make_level()
	if level == null:
		return
	level.debug_start_battle()
	level.debug_clear_waves()
	var before: int = level.sun_total
	level.spawn_sky_sun()
	assert_eq(level.debug_suns().size(), 1, "应生成一颗天降阳光")
	var sun: Node = level.debug_suns()[0]
	level.collect_sun(sun)
	assert_eq(level.sun_total, before + 25, "收集后阳光 +25")
	assert_true(sun.is_collected(), "阳光应标记为已收集")
	level.free()


func test_try_plant_costs_sun_and_blocks_stack() -> void:
	var level := _make_level()
	if level == null:
		return
	level.debug_start_battle()
	level.debug_clear_waves()
	level.sun_total = 200
	var ok: bool = level.try_plant(0, Vector2i(2, 1))
	assert_true(ok, "阳光足够时应种植成功")
	assert_eq(level.sun_total, 100, "种植后扣除 100 阳光")
	var stacked: bool = level.try_plant(0, Vector2i(2, 1))
	assert_false(stacked, "同一格不能重复种植")
	var sun_ok: bool = level.try_plant(1, Vector2i(0, 0))
	assert_true(sun_ok, "阳光足够时向日葵应种植成功")
	assert_eq(level.sun_total, 50, "向日葵造价 50")
	assert_eq(level._plants[Vector2i(0, 0)].data.id, "sunflower", "第 0 列应长出向日葵")
	level.free()


func test_zombie_eats_plant() -> void:
	var level := _make_level()
	if level == null:
		return
	level.debug_start_battle()
	level.debug_clear_waves()
	var plant: Node = level.debug_spawn_plant("sunflower", Vector2i(3, 0))
	var zombie: Node = level.debug_spawn_zombie("normal", 0)
	zombie.position.x = plant.position.x + 20.0
	level.debug_fast_forward(14.0)
	assert_true(not is_instance_valid(plant) or not plant.alive(), "僵尸应啃死向日葵（HP300，60 DPS）")
	level.free()


func test_house_defeat() -> void:
	var level := _make_level()
	if level == null:
		return
	level.debug_start_battle()
	level.debug_clear_waves()
	# 本用例验证“无小推车时僵尸进屋”，先清空小推车，避免被推车救场。
	level._mowers.clear()
	var zombie: Node = level.debug_spawn_zombie("normal", 1)
	zombie.position.x = 1.0
	level.debug_fast_forward(7.0)
	assert_eq(level.state, STATE_LOST, "僵尸进房 7s 后房子血量应归零")
	level.free()
