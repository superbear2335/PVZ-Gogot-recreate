@tool
extends McpTestSuite
## M3 进度与选关界面测试。

const PROGRESS_SCRIPT := "res://scripts/systems/game_progress.gd"
const TEST_SAVE := "user://test_progress.json"


func suite_name() -> String:
	return "progression"


func test_progress_save_round_trip() -> void:
	var script := load(PROGRESS_SCRIPT) as GDScript
	assert_true(script != null, "进度脚本应存在")
	var progress: Node = script.new()
	progress.save_path = TEST_SAVE
	progress.reset_progress()
	assert_eq(progress.unlocked_level, 1, "初始只解锁 1-1")
	progress.unlock_next(1)
	assert_eq(progress.unlocked_level, 2, "通关 1-1 后解锁 1-2")
	progress.select_level("1_4")
	assert_eq(progress.pending_level_id, "1_4", "选关应记录待加载关卡")
	var reloaded: Node = script.new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	assert_eq(reloaded.unlocked_level, 2, "解锁进度应持久化")
	assert_eq(reloaded.last_played, 4, "最近关卡应持久化")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	progress.free()
	reloaded.free()


func test_main_menu_builds_ten_level_buttons() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	assert_true(packed != null, "主菜单场景应存在")
	if packed == null:
		return
	var menu := packed.instantiate()
	menu._ready()
	assert_eq(menu._level_buttons.size(), 10, "应生成 10 个关卡按钮")
	assert_false(menu._level_buttons[0].disabled, "1-1 默认可选")
	assert_true(menu._level_buttons[1].disabled, "未解锁关卡应禁用")
	assert_eq(menu._level_buttons[0].text, "1-1", "按钮文本应为关卡号")
	menu.free()
