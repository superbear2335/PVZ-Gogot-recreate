@tool
extends McpTestSuite
## M1 核心规则测试：网格、时钟、数据目录。
## 纯静态断言，不实例化场景，headless 也能跑。

func suite_name() -> String:
	return "core"


func test_grid_centers() -> void:
	assert_eq(LawnGrid.cell_center(Vector2i(0, 0)), Vector2(80, 130), "第 0 列第 0 行中心")
	assert_eq(LawnGrid.cell_center(Vector2i(8, 4)), Vector2(720, 530), "第 8 列第 4 行中心")
	assert_eq(LawnGrid.row_center_y(0), 138.0, "僵尸脚底 y = 行中心 + 8")


func test_world_to_cell_roundtrip() -> void:
	for cell in [Vector2i(0, 0), Vector2i(4, 2), Vector2i(8, 4)]:
		assert_eq(LawnGrid.world_to_cell(LawnGrid.cell_center(cell)), cell, "格子中心应反向解析回同一格")


func test_world_to_cell_outside() -> void:
	assert_eq(LawnGrid.world_to_cell(Vector2(10, 100)), Vector2i(-1, -1), "左侧房区无效")
	assert_eq(LawnGrid.world_to_cell(Vector2(790, 100)), Vector2i(-1, -1), "右侧屏外无效")
	assert_eq(LawnGrid.world_to_cell(Vector2(100, 590)), Vector2i(-1, -1), "底部无效")


func test_clock_scaling() -> void:
	var clock := GameClock.new(7)
	clock.time_scale = 2.0
	assert_true(absf(clock.tick(0.5) - 1.0) < 0.0001, "2 倍速 delta 应为 1.0")
	assert_true(absf(clock.elapsed - 1.0) < 0.0001, "elapsed 应累计缩放后时间")


func test_clock_seed_reproducible() -> void:
	var a := GameClock.new(42)
	var b := GameClock.new(42)
	for i in 8:
		assert_eq(a.rng.randi_range(0, 100000), b.rng.randi_range(0, 100000), "同种子必须同序列")


func test_catalog_loads() -> void:
	var plants := GameCatalog.load_plants()
	var zombies := GameCatalog.load_zombies()
	var levels := GameCatalog.load_levels()
	assert_true(plants.size() >= 2, "至少要有豌豆射手和向日葵")
	assert_true(zombies.has("normal"), "至少要有普通僵尸")
	assert_true(levels.has("1_1"), "至少要有 1-1 关卡")


func test_peashooter_values() -> void:
	var plant_data: PlantData = GameCatalog.load_plants()["peashooter"]
	assert_eq(plant_data.cost, 100)
	assert_eq(plant_data.max_hp, 300)
	assert_eq(plant_data.damage, 20)
	assert_true(absf(plant_data.attack_interval - 1.4) < 0.001)
	assert_true(plant_data.projectile_scene != null, "豌豆射手必须绑定子弹场景")


func test_sunflower_values() -> void:
	var plant_data: PlantData = GameCatalog.load_plants()["sunflower"]
	assert_eq(plant_data.cost, 50)
	assert_eq(plant_data.behavior, "producer")
	assert_eq(plant_data.sun_amount, 25)
	assert_true(absf(plant_data.sun_interval - 24.0) < 0.001)


func test_level_one_data() -> void:
	var level_data: LevelData = load("res://resources/levels/1_1.tres")
	assert_true(level_data != null, "1-1 关卡数据必须存在")
	assert_eq(level_data.id, "1_1")
	assert_eq(level_data.starting_sun, 50)
	assert_eq(level_data.available_plants.size(), 2)
	assert_eq(level_data.waves.size(), 1)
