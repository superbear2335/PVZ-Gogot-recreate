@tool
extends McpTestSuite
## M5 测试：暂停时钟、暂停遮罩、音频缺失降级、静音设置持久化、主菜单继续入口。

const LEVEL_SCENE := "res://scenes/level.tscn"
const PROGRESS_SCRIPT := "res://scripts/systems/game_progress.gd"
const AUDIO_SCRIPT := "res://scripts/systems/audio_manager.gd"
const MENU_SCENE := "res://scenes/main.tscn"

const STATE_PLAYING := 3


func suite_name() -> String:
	return "m5"


func _make_level() -> Node:
	var packed := load(LEVEL_SCENE) as PackedScene
	assert_true(packed != null, "关卡场景必须存在")
	if packed == null:
		return null
	var level := packed.instantiate()
	level._ready()
	level.debug_start_battle()
	level.debug_clear_waves()
	level.sun_total = 2000
	return level


func test_pause_freezes_clock_and_resumes() -> void:
	var level := _make_level()
	if level == null:
		return
	assert_eq(level.state, STATE_PLAYING, "调试开战后应处于 PLAYING")
	level.debug_fast_forward(0.5)
	var before: float = level.clock.elapsed
	level.toggle_pause()
	assert_true(level.is_paused(), "Esc 后应进入暂停")
	assert_true(level._pause_overlay.visible, "暂停遮罩应显示")
	level.debug_fast_forward(2.0)
	assert_eq(level.clock.elapsed, before, "暂停期间时钟不应推进")
	level.toggle_pause()
	assert_eq(level.state, STATE_PLAYING, "再按 Esc 应恢复 PLAYING")
	assert_false(level._pause_overlay.visible, "恢复后暂停遮罩应隐藏")
	level.debug_fast_forward(1.0)
	assert_true(level.clock.elapsed > before, "恢复后时钟应继续推进")
	level.free()


func test_audio_missing_degrades_silently() -> void:
	var script := load(AUDIO_SCRIPT) as GDScript
	assert_true(script != null, "AudioManager 脚本应存在")
	if script == null:
		return
	var audio: Node = script.new()
	audio._ready()
	assert_false(audio.play_sfx("__missing_sfx__"), "缺失音效应返回 false")
	assert_false(audio.play_music("__missing_music__"), "缺失音乐应返回 false")
	audio.apply_volumes()
	audio.free()


func test_muted_settings_persist() -> void:
	var script := load(PROGRESS_SCRIPT) as GDScript
	assert_true(script != null, "GameProgress 脚本应存在")
	if script == null:
		return
	var path := "user://test_m5_progress.json"
	var writer: Node = script.new()
	writer.save_path = path
	writer.sfx_muted = true
	writer.music_muted = true
	writer.sfx_volume = 0.35
	writer.save_progress()
	var reader: Node = script.new()
	reader.save_path = path
	reader.load_progress()
	assert_true(reader.sfx_muted, "静音音效应被持久化")
	assert_true(reader.music_muted, "静音音乐应被持久化")
	assert_true(absf(reader.sfx_volume - 0.35) < 0.001, "音量应被持久化")
	writer.free()
	reader.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_menu_has_continue_and_audio_toggles() -> void:
	var packed := load(MENU_SCENE) as PackedScene
	assert_true(packed != null, "主菜单场景应存在")
	if packed == null:
		return
	var menu := packed.instantiate()
	menu._ready()
	assert_eq(menu._level_buttons.size(), 10, "主菜单应有 10 个关卡按钮")
	assert_true(menu._continue_button != null, "主菜单应有继续按钮")
	assert_true(menu._sfx_button != null and menu._music_button != null, "主菜单应有音效/音乐开关")
	assert_true(menu._continue_button.text.begins_with("继续"), "继续按钮应显示目标关卡")
	menu.free()
