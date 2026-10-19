@tool
extends McpTestSuite
## M0 冒烟测试：项目设置、入口场景与目录骨架。
##
## 运行方式：MCP test_run（编辑器内），或后续 tools/run_tests.gd（headless）。
## 只断言与 M0 验收相关的事实，不依赖编辑器当前打开的场景。

const MAIN_SCENE := "res://scenes/main.tscn"


func suite_name() -> String:
	return "smoke"


func test_project_resolution() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 800, "逻辑宽度必须为 800")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 600, "逻辑高度必须为 600")


func test_stretch_keeps_layout() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")


func test_project_name_is_set() -> void:
	var project_name: String = ProjectSettings.get_setting("application/config/name")
	assert_false(project_name.is_empty(), "项目名不能为空")


func test_main_scene_is_packed_scene() -> void:
	assert_true(ResourceLoader.exists(MAIN_SCENE, "PackedScene"), "入口场景必须存在")
	var packed := load(MAIN_SCENE) as PackedScene
	assert_true(packed != null, "入口场景必须能加载为 PackedScene")
	if packed == null:
		return
	var instance := packed.instantiate()
	assert_true(instance != null, "入口场景必须能实例化")
	if instance == null:
		return
	assert_eq(instance.name, "Main", "入口场景根节点名必须是 Main")
	assert_true(instance.has_node("UI/Layout/TitleLabel"), "启动画面必须包含标题 Label")
	assert_true(instance.has_node("UI/Layout/StatusLabel"), "启动画面必须包含状态 Label")
	assert_true(instance.get_script() != null, "入口场景根节点必须挂载 main.gd")
	instance.free()


func test_required_directories_exist() -> void:
	for path in [
		"res://scripts/core", "res://scripts/data", "res://scripts/entities",
		"res://scripts/world", "res://scripts/systems", "res://scripts/ui",
		"res://resources/plants", "res://resources/zombies", "res://resources/levels",
		"res://docs",
	]:
		assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)), "缺少目录：%s" % path)
