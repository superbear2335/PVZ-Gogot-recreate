@tool
class_name WaveDirector
extends Node
## 波次导演：把 LevelData.waves 展开成绝对时间表，逐只投放僵尸。
##
## M1 只做“按数量抽取 + 行随机”；M2 换成点数预算与旗帜波逻辑时，
## 保持 tick()/total_waves() 接口不变即可。

var level: Node
var data: LevelData

var _schedule: Array = []
var _clock := 0.0
var _started := false
var _last_wave_started := -1
var _victory_timer := 0.0
var _victory_pending := false
var _finished := false


func setup(p_level: Node, p_data: LevelData) -> void:
	level = p_level
	data = p_data
	_build_schedule()


func _build_schedule() -> void:
	_schedule.clear()
	var rng: RandomNumberGenerator = level.clock.rng
	var t := 0.0
	for wave_index in data.waves.size():
		var wave: Dictionary = data.waves[wave_index]
		t += float(wave.get("delay", 10.0))
		var count := int(wave.get("count", 1))
		for i in count:
			_schedule.append({
				"time": t,
				"wave_index": wave_index,
				"is_huge": bool(wave.get("is_huge", false)),
			})
			t += rng.randf_range(0.8, 1.2)


func start() -> void:
	_started = true
	_clock = 0.0


func total_waves() -> int:
	return data.waves.size()


func waves_started() -> int:
	return _last_wave_started + 1


func tick(delta: float) -> void:
	if not _started or _finished:
		return
	_clock += delta
	while not _schedule.is_empty() and float(_schedule[0]["time"]) <= _clock:
		var entry: Dictionary = _schedule.pop_front()
		_on_spawn_entry(entry)
	if _schedule.is_empty() and _last_wave_started >= data.waves.size() - 1:
		if _victory_pending:
			_victory_timer -= delta
			if _victory_timer <= 0.0:
				_finished = true
				level.on_victory()
		elif level.alive_zombie_count() == 0:
			_victory_pending = true
			_victory_timer = 2.0


func _on_spawn_entry(entry: Dictionary) -> void:
	var wave_index := int(entry["wave_index"])
	if wave_index != _last_wave_started:
		_last_wave_started = wave_index
		level.signals.wave_started.emit(wave_index, bool(entry["is_huge"]))
		if bool(entry["is_huge"]):
			level.show_huge_wave_banner()
			# 旗帜波：额外放一只旗帜僵尸作为波次标志（仅当卡池包含 flag）。
			# 注意：旗帜僵尸不计入 LevelData.waves 的 count。
			if data.zombie_pool.has("flag"):
				level.spawn_zombie("flag", level.pick_spawn_row())
	level.spawn_zombie(_pick_zombie_id(), level.pick_spawn_row())


func _pick_zombie_id() -> String:
	var pool: Array = data.zombie_pool
	if pool.is_empty():
		return "normal"
	return String(pool[level.clock.rng.randi_range(0, pool.size() - 1)])
