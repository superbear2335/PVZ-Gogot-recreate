@tool
class_name Sun
extends Node2D
## 阳光实体：天降时下落，植物产出的原地出现；12 秒后消失。
## 点击判定由 Level 统一处理（避免每个阳光挂 Area2D）。

const VALUE := 25
const RADIUS := 20.0
const LIFETIME := 12.0

var value: int = VALUE
var level: Node
var falling := false
var fall_speed := 70.0
var target_y := 0.0
var life := LIFETIME

var _collected := false
var _age := 0.0
var _phase := 0.0
var _sprite: Sprite2D
var _frames := 0
var _fps := 12.0
var _anim_time := 0.0


func setup(p_value: int, p_falling: bool, p_level: Node) -> void:
	value = p_value
	falling = p_falling
	level = p_level
	life = LIFETIME
	_phase = randf() * TAU
	z_index = 8
	var meta := PvzAssets.anim_sheet("sun", "sun", "sun")
	if not meta.is_empty():
		_sprite = Sprite2D.new()
		_sprite.texture = meta["texture"]
		_frames = int(meta["frames"])
		_fps = float(meta["fps"])
		_sprite.hframes = _frames
		_sprite.centered = true
		_sprite.scale = Vector2(0.4, 0.4)
		add_child(_sprite)


func tick(delta: float) -> void:
	_age += delta
	_phase += delta * 2.0
	if _sprite != null:
		_anim_time += delta
		_anim_time = fmod(_anim_time, 10.0)
		_sprite.frame = int(_anim_time * _fps) % _frames
		_sprite.modulate.a = 1.0 if life >= 3.0 else 0.45 + 0.55 * absf(sin(life * 6.0))
	if falling and position.y < target_y:
		position.y = min(target_y, position.y + fall_speed * delta)
		if is_equal_approx(position.y, target_y):
			falling = false
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func collect() -> bool:
	if _collected:
		return false
	_collected = true
	return true


func is_collected() -> bool:
	return _collected


func _draw() -> void:
	if _sprite != null:
		return
	var alpha := 1.0
	if life < 3.0:
		alpha = 0.35 + 0.65 * absf(sin(life * 6.0))
	var color := Color(1.0, 0.82, 0.12, alpha)
	var glow := Color(1.0, 0.9, 0.35, alpha * 0.35)
	draw_circle(Vector2.ZERO, RADIUS + 7.0 + sin(_phase) * 2.0, glow)
	draw_circle(Vector2.ZERO, RADIUS, color)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + _phase * 0.15
		var from := Vector2(cos(angle), sin(angle)) * (RADIUS + 2.0)
		var to := Vector2(cos(angle), sin(angle)) * (RADIUS + 8.0)
		draw_line(from, to, color, 2.0)
	draw_circle(Vector2(-5.0, -5.0), 4.0, Color(1, 1, 0.85, alpha * 0.8))
