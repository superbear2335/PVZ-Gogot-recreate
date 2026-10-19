@tool
extends McpTestSuite
## M4 内容测试：Day 1-1 ~ 1-10 全量关卡定义、植物/僵尸名册、终局波次。
## 只读 .tres 与目录，不实例化关卡，保证快速稳定。

const LEVEL_DIR := "res://resources/levels/"
const TOTAL_LEVELS := 10
const PLANT_IDS := [
	"peashooter", "sunflower", "wallnut", "potatomine", "snowpea",
	"cherrybomb", "chomper", "repeater", "puffshroom",
]
const ZOMBIE_IDS := ["normal", "cone", "pole", "bucket", "flag", "football", "ducky"]


func suite_name() -> String:
	return "m4"


func _load_level(level_number: int) -> LevelData:
	var path := "%s1_%d.tres" % [LEVEL_DIR, level_number]
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelData


func test_all_ten_day_levels_exist() -> void:
	for number in range(1, TOTAL_LEVELS + 1):
		var level_data := _load_level(number)
		var expected_id := "1_%d" % number
		assert_true(level_data != null, "关卡资源应存在：%s" % expected_id)
		if level_data == null:
			continue
		assert_eq(level_data.id, expected_id, "关卡 id 应与文件名一致")
		assert_false(String(level_data.display_name).is_empty(), "%s 应有显示名" % expected_id)
		assert_false(level_data.available_plants.is_empty(), "%s 应有可用植物" % expected_id)
		assert_false(level_data.zombie_pool.is_empty(), "%s 应有僵尸池" % expected_id)
		assert_eq(
			level_data.waves.size(), number,
			"%s 波数应为 %d，实际 %d" % [expected_id, number, level_data.waves.size()]
		)


func test_waves_are_well_formed() -> void:
	for number in range(1, TOTAL_LEVELS + 1):
		var level_data := _load_level(number)
		if level_data == null:
			continue
		for wave_index in level_data.waves.size():
			var wave: Dictionary = level_data.waves[wave_index]
			assert_true(float(wave.get("delay", 0.0)) > 0.0, "%s 第 %d 波 delay 应 > 0" % [level_data.id, wave_index])
			assert_true(int(wave.get("count", 0)) >= 1, "%s 第 %d 波 count 应 >= 1" % [level_data.id, wave_index])
			var is_huge := bool(wave.get("is_huge", false))
			assert_eq(is_huge, wave_index == level_data.waves.size() - 1, "只有最后一波应为大波：%s" % level_data.id)


func test_day_plant_roster_complete() -> void:
	var catalog := GameCatalog.load_plants()
	for plant_id in PLANT_IDS:
		assert_true(catalog.has(plant_id), "植物目录应包含 %s" % plant_id)
		if catalog.has(plant_id):
			var data: PlantData = catalog[plant_id]
			assert_eq(data.id, plant_id, "植物 id 应与资源一致")
			assert_true(data.max_hp > 0, "%s 应有 HP" % plant_id)
	assert_true(catalog.size() >= PLANT_IDS.size(), "植物目录至少 9 种，实际 %d" % catalog.size())


func test_day_zombie_roster_complete() -> void:
	var catalog := GameCatalog.load_zombies()
	for zombie_id in ZOMBIE_IDS:
		assert_true(catalog.has(zombie_id), "僵尸目录应包含 %s" % zombie_id)
		if catalog.has(zombie_id):
			var data: ZombieData = catalog[zombie_id]
			assert_eq(data.id, zombie_id, "僵尸 id 应与资源一致")
			assert_true(data.max_hp > 0, "%s 应有本体 HP" % zombie_id)
	assert_true(catalog.size() >= ZOMBIE_IDS.size(), "僵尸目录至少 7 种，实际 %d" % catalog.size())


func test_level_references_are_valid() -> void:
	var plants := GameCatalog.load_plants()
	var zombies := GameCatalog.load_zombies()
	for number in range(1, TOTAL_LEVELS + 1):
		var level_data := _load_level(number)
		if level_data == null:
			continue
		for plant_id in level_data.available_plants:
			assert_true(plants.has(plant_id), "%s 引用不存在的植物 %s" % [level_data.id, plant_id])
		for zombie_id in level_data.zombie_pool:
			assert_true(zombies.has(zombie_id), "%s 引用不存在的僵尸 %s" % [level_data.id, zombie_id])


func test_finale_is_hardest() -> void:
	var finale := _load_level(TOTAL_LEVELS)
	var first := _load_level(1)
	assert_true(finale != null and first != null, "首尾关卡应存在")
	if finale == null or first == null:
		return
	assert_eq(finale.waves.size(), 10, "1-10 应为 10 波")
	assert_eq(first.waves.size(), 1, "1-1 应为 1 波")
	var finale_total := 0
	for wave in finale.waves:
		finale_total += int(wave.get("count", 0))
	var first_total := 0
	for wave in first.waves:
		first_total += int(wave.get("count", 0))
	assert_true(finale_total > first_total * 5, "终局总僵尸数应远高于 1-1（%d vs %d）" % [finale_total, first_total])
	assert_eq(finale.available_plants.size(), PLANT_IDS.size(), "1-10 应解锁全部 9 种植物")
	assert_true(first.available_plants.has("peashooter"), "1-1 应至少可用豌豆射手")
	assert_true(first.available_plants.size() <= 2, "1-1 不应解锁过多植物")
