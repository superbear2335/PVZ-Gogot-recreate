@tool
extends McpTestSuite
## M6 资源契约与占位降级测试。
## assets/ 目录可以整体缺席（第一阶段占位）；一旦存在，则按契约校验命名、尺寸与可加载性。

const ASSET_ROOT := "res://assets"
const DOCS := ["res://docs/values.md", "res://docs/asset-contract.md"]
const LEVEL_SCENE := "res://scenes/level.tscn"

const PLANT_IDS := [
	"peashooter", "sunflower", "wallnut", "potatomine", "snowpea",
	"cherrybomb", "chomper", "repeater", "puffshroom",
]
const ZOMBIE_IDS := ["normal", "cone", "pole", "bucket", "flag", "football", "ducky"]


func suite_name() -> String:
	return "assets"


func test_contract_docs_exist() -> void:
	for path in DOCS:
		assert_true(FileAccess.file_exists(path), "契约文档应存在：%s" % path)
	assert_true(FileAccess.file_exists("res://project.godot"), "项目文件应存在")


func test_assets_dir_is_optional() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ASSET_ROOT)):
		assert_true(true, "assets/ 缺席时使用占位绘制，合法")
		return
	var pvz_root := "%s/pvz" % ASSET_ROOT
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(pvz_root)):
		for plant_id in PLANT_IDS:
			assert_true(FileAccess.file_exists("%s/icons/%s.png" % [pvz_root, plant_id]), "植物图标应存在：%s" % plant_id)
			assert_true(ResourceLoader.exists("%s/plants/%s_idle.png" % [pvz_root, plant_id]), "植物 idle 精灵表应存在：%s" % plant_id)
		for zombie_id in ZOMBIE_IDS:
			assert_true(ResourceLoader.exists("%s/zombies/%s_walk.png" % [pvz_root, zombie_id]), "僵尸 walk 精灵表应存在：%s" % zombie_id)
		assert_true(ResourceLoader.exists("%s/ui/background1.jpg" % pvz_root), "关卡背景应存在")
		return
	for plant_id in PLANT_IDS:
		_validate_entity_dir("plants", plant_id, Vector2(80, 100))
	for zombie_id in ZOMBIE_IDS:
		_validate_entity_dir("zombies", zombie_id, Vector2(80, 120))


func _validate_entity_dir(category: String, entity_id: String, expected_size: Vector2) -> void:
	var directory := "%s/%s/%s" % [ASSET_ROOT, category, entity_id]
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return
	var file_names := DirAccess.get_files_at(directory)
	var png_count := 0
	for file_name in file_names:
		if not String(file_name).ends_with(".png"):
			continue
		png_count += 1
		var texture := load("%s/%s" % [directory, file_name]) as Texture2D
		assert_true(texture != null, "PNG 应可加载：%s/%s" % [directory, file_name])
		if texture == null:
			continue
		var size := texture.get_size()
		assert_true(
			absf(size.x - expected_size.x) <= expected_size.x * 0.1
			and absf(size.y - expected_size.y) <= expected_size.y * 0.1,
			"%s 尺寸应接近 %s，实际 %s" % [file_name, expected_size, size]
		)
	if png_count == 0:
		push_warning("%s/%s 存在但为空，运行时将回退占位" % [category, entity_id])


func test_placeholder_fallback_all_entities() -> void:
	var packed := load(LEVEL_SCENE) as PackedScene
	assert_true(packed != null, "关卡场景必须存在")
	if packed == null:
		return
	var level := packed.instantiate()
	level.level_data = load("res://resources/levels/1_10.tres")
	level._ready()
	level.debug_start_battle()
	level.debug_clear_waves()
	level.sun_total = 5000
	var cells := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0),
	]
	for i in PLANT_IDS.size():
		var plant: Node = level.debug_spawn_plant(PLANT_IDS[i], cells[i])
		assert_true(plant != null, "无素材时 %s 应能放置" % PLANT_IDS[i])
	for i in ZOMBIE_IDS.size():
		var zombie: Node = level.debug_spawn_zombie(ZOMBIE_IDS[i], i % LawnGrid.ROWS)
		assert_true(zombie != null, "无素材时 %s 应能生成" % ZOMBIE_IDS[i])
		zombie.position.x = 360.0 + i * 24.0
	level.debug_fast_forward(0.5)
	assert_true(level._plants.size() >= PLANT_IDS.size(), "9 种植物应全部在场")
	level.free()
