@tool
class_name AnimSprite
extends Sprite2D
## 预渲染 PVZ 动画精灵：横向 strip + JSON 元数据，按 tick 推进帧。
## 以脚底为锚点：offset=(-origin_x, -ground)，实体 position 即落地位置。

var frames_total := 1
var anim_fps := 12.0
var anim_name := ""
var sheet_id := ""
var sheet_kind := ""

var _time := 0.0
var _ground_offset := 0.0


func setup(p_kind: String, p_id: String, p_anim: String, p_scale: float = 1.0, p_modulate := Color.WHITE, p_ground_offset: float = 0.0) -> bool:
	sheet_kind = p_kind
	sheet_id = p_id
	anim_name = p_anim
	var meta := PvzAssets.anim_sheet(p_kind, p_id, p_anim)
	if meta.is_empty():
		return false
	texture = meta["texture"]
	frames_total = maxi(1, int(meta["frames"]))
	anim_fps = maxf(1.0, float(meta["fps"]))
	hframes = frames_total
	frame = 0
	centered = false
	offset = Vector2(-float(meta["origin_x"]), -float(meta["ground"]) + p_ground_offset)
	_ground_offset = p_ground_offset
	scale = Vector2(p_scale, p_scale)
	modulate = p_modulate
	_time = 0.0
	return true


func play(p_anim: String, reset := false) -> bool:
	if p_anim == anim_name and not reset:
		return true
	var meta := PvzAssets.anim_sheet(sheet_kind, sheet_id, p_anim)
	if meta.is_empty():
		return false
	anim_name = p_anim
	texture = meta["texture"]
	frames_total = maxi(1, int(meta["frames"]))
	anim_fps = maxf(1.0, float(meta["fps"]))
	hframes = frames_total
	frame = 0
	offset = Vector2(-float(meta["origin_x"]), -float(meta["ground"]) + _ground_offset)
	_time = 0.0
	return true


func advance(delta: float) -> void:
	if frames_total <= 1:
		return
	_time += delta
	frame = int(_time * anim_fps) % frames_total
