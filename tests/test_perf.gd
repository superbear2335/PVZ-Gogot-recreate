@tool
extends McpTestSuite
## M6 性能与容量测试：150 僵尸压力场景、子弹上限。
## 记录的是编辑器内逻辑 tick 成本；绘制成本需在实机截图/帧率里另行确认。

const LEVEL_SCENE := "res://scenes/level.tscn"
const STRESS_ZOMBIES := 150
const STRESS_FRAMES := 120


func suite_name() -> String:
	return "perf"


func _make_level() -> Node:
	var packed := load(LEVEL_SCENE) as PackedScene
	if packed == null:
		return null
	var level := packed.instantiate()
	level._ready()
	level.debug_start_battle()
	level.debug_clear_waves()
	level.sun_total = 9990
	return level


func test_hundred_fifty_zombies_tick_budget() -> void:
	var level := _make_level()
	assert_true(level != null, "关卡场景必须存在")
	if level == null:
		return
	for i in STRESS_ZOMBIES:
		var zombie: Node = level.debug_spawn_zombie("normal", i % LawnGrid.ROWS)
		zombie.position = Vector2(200.0 + (i % 60) * 10.0, LawnGrid.row_center_y(i % LawnGrid.ROWS))
	var started := Time.get_ticks_usec()
	for frame in STRESS_FRAMES:
		level.simulate(1.0 / 60.0)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var per_frame := elapsed_ms / float(STRESS_FRAMES)
	print("[perf] %d 僵尸 × %d 帧：总 %.2f ms，平均 %.3f ms/帧" % [STRESS_ZOMBIES, STRESS_FRAMES, elapsed_ms, per_frame])
	assert_true(level._zombies.size() > 0, "压力场景僵尸应存活")
	assert_true(per_frame < 16.0, "逻辑 tick 平均耗时应低于 16 ms/帧，实际 %.3f" % per_frame)
	level.free()


func test_projectile_cap_respected() -> void:
	var level := _make_level()
	if level == null:
		return
	for col in LawnGrid.COLS:
		level.debug_spawn_plant("repeater", Vector2i(col, 2))
	for i in 20:
		var zombie: Node = level.debug_spawn_zombie("normal", 2)
		zombie.position.x = 500.0 + i * 12.0
	level.debug_fast_forward(12.0)
	print("[perf] 12s 后子弹数：%d" % level._projectiles.size())
	assert_true(level._projectiles.size() <= 130, "子弹数应受 120 上限约束，实际 %d" % level._projectiles.size())
	level.free()
