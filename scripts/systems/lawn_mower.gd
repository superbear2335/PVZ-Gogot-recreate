@tool
class_name LawnMower
extends Node2D
## 每行一辆的小推车。僵尸抵达触发线后向右冲刺，途中斩杀本行全部僵尸。

const SPEED := 300.0
const HIT_RADIUS := 44.0

var row: int = 0
var level: Node
var used := false
var running := false
var _anim: AnimSprite


func setup(p_row: int, p_level: Node) -> void:
	row = p_row
	level = p_level
	position = Vector2(LawnGrid.MOWER_X, LawnGrid.row_center_y(row))
	z_index = 2
	_anim = AnimSprite.new()
	add_child(_anim)
	if not _anim.setup("mower", "mower", "idle", 0.7, Color.WHITE, 22.0):
		_anim.queue_free()
		_anim = null


func trigger() -> void:
	if used:
		return
	used = true
	running = true
	queue_redraw()


func tick(delta: float) -> void:
	if _anim != null:
		_anim.advance(delta)
	if not running:
		return
	position.x += SPEED * delta
	if level != null:
		level.mower_hit_row(self, row)
	if position.x > LawnGrid.MOWER_END_X:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 0), 18.0, Color(0, 0, 0, 0.18))
	if _anim != null:
		return
	draw_rect(Rect2(-26, -30, 52, 24), Color("b94a3a"))
	draw_rect(Rect2(-18, -36, 30, 8), Color("d9d2b0"))
	draw_rect(Rect2(-26, -30, 52, 4), Color("d9735a"))
	draw_circle(Vector2(-16, -4), 9.0, Color("2b2b2b"))
	draw_circle(Vector2(16, -4), 9.0, Color("2b2b2b"))
	draw_circle(Vector2(-16, -4), 3.0, Color("6b6b6b"))
	draw_circle(Vector2(16, -4), 3.0, Color("6b6b6b"))
	if running:
		draw_line(Vector2(-30, -18), Vector2(-48, -18), Color(1, 1, 1, 0.35), 2.0)
