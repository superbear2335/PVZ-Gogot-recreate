@tool
extends McpTestSuite
## 临时诊断：确认编辑器内关卡脚本以 @tool 实例化。


func suite_name() -> String:
	return "diag"


func test_level_script_is_tool() -> void:
	var packed := load("res://scenes/level.tscn") as PackedScene
	var level := packed.instantiate()
	var script := level.get_script() as GDScript
	print("[diag] script=%s tool=%s simulate=%s" % [script.resource_path, script.is_tool(), level.has_method("simulate")])
	level._ready()
	print("[diag] state=%d plants=%d" % [level.state, level._plants.size()])
	assert_true(script.is_tool(), "关卡脚本应为 @tool")
	assert_true(level.has_method("simulate"), "应可调用 simulate")
	level.free()
