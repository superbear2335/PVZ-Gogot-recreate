class_name GameCatalog
extends RefCounted
## 从 resources/ 目录加载所有静态数据，按 id 建索引。
## 加载失败只警告并跳过，保证缺一个 .tres 不会让整关崩溃。

const PLANT_DIR := "res://resources/plants"
const ZOMBIE_DIR := "res://resources/zombies"
const LEVEL_DIR := "res://resources/levels"


static func load_plants() -> Dictionary:
	return _load_dir(PLANT_DIR)


static func load_zombies() -> Dictionary:
	return _load_dir(ZOMBIE_DIR)


static func load_levels() -> Dictionary:
	return _load_dir(LEVEL_DIR)


static func _load_dir(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("GameCatalog：目录不存在 %s" % dir_path)
		return result
	for file_name in dir.get_files():
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var path := dir_path.path_join(file_name)
		var resource: Resource = load(path)
		if resource == null:
			push_warning("GameCatalog：加载失败 %s" % path)
			continue
		var id: String = String(resource.get("id"))
		if id.is_empty():
			id = file_name.get_basename()
		result[id] = resource
	return result
