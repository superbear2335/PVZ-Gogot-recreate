@tool
class_name Projectile
extends Node2D
## 直线飞行的子弹（豌豆/孢子）。命中由 Level 查询本行僵尸后回调。

var damage: int = 20
var speed: float = 300.0
var row: int = 0
var level: Node
var color := Color("4caf50")
var slow_factor: float = 0.0
var slow_duration: float = 0.0

var _dead := false
var _trail: Array[Vector2] = []
var _sprite: Sprite2D


func setup(
	p_damage: int,
	p_speed: float,
	p_row: int,
	p_level: Node,
	p_color: Color,
	p_slow_factor: float = 0.0,
	p_slow_duration: float = 0.0,
) -> void:
	damage = p_damage
	speed = p_speed
	row = p_row
	level = p_level
	color = p_color
	slow_factor = p_slow_factor
	slow_duration = p_slow_duration
	z_index = 6
	var tex := PvzAssets.projectile_texture(slow_factor > 0.0)
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2(0.55, 0.55)
		add_child(_sprite)


func tick(delta: float) -> void:
	if _dead:
		return
	position.x += speed * delta
	if position.x > 820.0:
		_dead = true
		queue_free()
		return
	var zombie: Node = level.find_zombie_in_row_at(row, position.x)
	if zombie != null:
		zombie.take_damage(damage, slow_factor, slow_duration)
		_dead = true
		queue_free()


func is_dead() -> bool:
	return _dead


func _draw() -> void:
	if _sprite != null:
		return
	draw_circle(Vector2.ZERO, 8.0, color)
	draw_circle(Vector2(-2.5, -2.5), 3.0, Color(1, 1, 1, 0.55))
