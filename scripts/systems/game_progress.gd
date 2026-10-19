extends Node
## 冒险进度与设置（autoload 名：GameProgress）。
##
## 文件：user://progress.json；版本号用于将来迁移。
## 关卡 id 采用 "1_5" 形式，与 resources/levels/*.tres 文件名一致。

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 1
const MAX_LEVEL := 10

var save_path := SAVE_PATH
var unlocked_level := 1
var last_played := 1
var pending_level_id := ""
var music_volume := 0.7
var sfx_volume := 0.8
var music_muted := false
var sfx_muted := false


func _ready() -> void:
	load_progress()


func is_unlocked(level_number: int) -> bool:
	return level_number <= clampi(unlocked_level, 1, MAX_LEVEL)


func level_number_from_id(level_id: String) -> int:
	var parts := level_id.split("_")
	if parts.size() < 2:
		return 1
	return clampi(int(parts[1]), 1, MAX_LEVEL)


func select_level(level_id: String) -> void:
	pending_level_id = level_id
	last_played = level_number_from_id(level_id)
	save_progress()


func unlock_next(level_number: int) -> void:
	var target := clampi(level_number + 1, 1, MAX_LEVEL)
	if target > unlocked_level:
		unlocked_level = target
		save_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("GameProgress：无法读取存档 %s" % save_path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("GameProgress：存档格式损坏，使用默认进度")
		return
	var dict: Dictionary = parsed
	unlocked_level = clampi(int(dict.get("unlocked_level", 1)), 1, MAX_LEVEL)
	last_played = clampi(int(dict.get("last_played", 1)), 1, MAX_LEVEL)
	music_volume = clampf(float(dict.get("music_volume", 0.7)), 0.0, 1.0)
	sfx_volume = clampf(float(dict.get("sfx_volume", 0.8)), 0.0, 1.0)
	music_muted = bool(dict.get("music_muted", false))
	sfx_muted = bool(dict.get("sfx_muted", false))


func save_progress() -> void:
	var dict := {
		"version": SAVE_VERSION,
		"unlocked_level": unlocked_level,
		"last_played": last_played,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("GameProgress：无法写入存档 %s" % save_path)
		return
	file.store_string(JSON.stringify(dict, "\t"))
	file.close()


func reset_progress() -> void:
	unlocked_level = 1
	last_played = 1
	pending_level_id = ""
	save_progress()
