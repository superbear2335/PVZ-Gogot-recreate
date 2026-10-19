@tool
class_name PvzAssets
extends RefCounted
## 访问 pak 预渲染素材：assets/pvz/**。素材缺失时返回空字典/空纹理，调用方回退占位绘制。

const ROOT := "res://assets/pvz/"

static var _anim_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func anim_sheet(kind: String, id: String, anim: String) -> Dictionary:
	var base := "%s%s/%s_%s" % [ROOT, kind, id, anim]
	if _anim_cache.has(base):
		return _anim_cache[base]
	var json_path := base + ".json"
	var png_path := base + ".png"
	if not FileAccess.file_exists(json_path) or not ResourceLoader.exists(png_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		return {}
	var meta: Dictionary = parsed
	var tex := load(png_path) as Texture2D
	if tex == null:
		return {}
	var result := {
		"texture": tex,
		"frames": int(meta.get("frames", 1)),
		"fps": float(meta.get("fps", 12.0)),
		"ground": float(meta.get("ground", 0)),
		"origin_x": float(meta.get("origin_x", 0)),
		"frame_w": int(meta.get("frame_w", tex.get_width())),
		"frame_h": int(meta.get("frame_h", tex.get_height())),
	}
	_anim_cache[base] = result
	return result


static func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var full := path if path.begins_with("res://") else ROOT + path
	if not ResourceLoader.exists(full):
		return null
	var tex := load(full) as Texture2D
	if tex != null:
		_tex_cache[path] = tex
	return tex


static func plant_icon(id: String) -> Texture2D:
	return texture("icons/%s.png" % id)


static func background() -> Texture2D:
	return texture("ui/background1.jpg")


static func logo() -> Texture2D:
	return texture("ui/logo.png")


static func packet() -> Texture2D:
	return texture("ui/seed_packet.png")


static func sun_bank() -> Texture2D:
	return texture("ui/sun_bank.png")


static func seed_bank() -> Texture2D:
	return texture("ui/seed_bank.png")


static func projectile_texture(slow: bool) -> Texture2D:
	return texture("projectiles/snow_pea.png" if slow else "projectiles/pea.png")
