@tool
class_name Plant
extends Node2D
## 植物基类：由 PlantData.behavior 驱动通用逻辑。
## 已实现：shooter / producer / blocker / mine / bomb / chomper。
## 坐标约定：position = 格子中心（草坪地面），视觉向上绘制。

var data: PlantData
var cell := Vector2i(-1, -1)
var level: Node
var hp := 300
var dead := false

var _timer := 0.0
var _flash := 0.0
var _armed := false
var _chewing := 0.0
var _bite_timer := 0.0
var _anim: AnimSprite

const VISUAL_SCALE := {
	"peashooter": 1.2,
	"sunflower": 1.15,
	"wallnut": 1.15,
	"potatomine": 1.05,
	"cherrybomb": 1.0,
	"chomper": 0.95,
	"snowpea": 1.2,
	"repeater": 1.2,
	"puffshroom": 1.3,
}


func setup(p_data: PlantData, p_cell: Vector2i, p_level: Node) -> void:
	data = p_data
	cell = p_cell
	level = p_level
	position = LawnGrid.cell_center(cell)
	hp = data.max_hp
	match data.behavior:
		"shooter":
			_timer = 0.35
		"producer":
			_timer = data.sun_interval
		"mine":
			_timer = data.arm_time
		"bomb":
			_timer = maxf(0.1, data.fuse_time)
		_:
			_timer = 0.0
	z_index = 3
	_setup_visual()
	queue_redraw()


func _setup_visual() -> void:
	var scale_value: float = VISUAL_SCALE.get(data.id, 1.1)
	_anim = AnimSprite.new()
	add_child(_anim)
	if not _anim.setup("plants", data.id, "idle", scale_value, Color.WHITE, 34.0):
		_anim.queue_free()
		_anim = null


func tick(delta: float) -> void:
	if dead:
		return
	_flash = maxf(0.0, _flash - delta)
	if _anim != null:
		_anim.advance(delta)
	match data.behavior:
		"shooter":
			_timer -= delta
			if _timer <= 0.0:
				if level.has_zombie_ahead(cell.y, position.x, data.range_px):
					for i in maxi(1, data.shots_per_volley):
						level.spawn_projectile(self, data)
					_timer = maxf(0.1, data.attack_interval)
				else:
					_timer = 0.0
		"producer":
			_timer -= delta
			if _timer <= 0.0:
				level.spawn_plant_sun(self)
				_timer = maxf(1.0, data.sun_interval)
		"mine":
			if not _armed:
				_timer -= delta
				if _timer <= 0.0:
					_armed = true
					if _anim != null:
						_anim.play("armed")
					queue_redraw()
			elif level.zombie_on_cell(cell):
				level.explode_at(position, data.damage, data.aoe_cells)
				_die()
				return
		"bomb":
			_timer -= delta
			if _timer <= 0.25 and _anim != null:
				_anim.play("explode")
			if _timer <= 0.0:
				level.explode_at(position, data.damage, data.aoe_cells)
				_die()
				return
		"chomper":
			if _bite_timer > 0.0:
				_bite_timer = maxf(0.0, _bite_timer - delta)
				if _bite_timer <= 0.0 and _anim != null:
					_anim.play("chew")
			elif _chewing > 0.0:
				_chewing -= delta
				if _chewing <= 0.0 and _anim != null:
					_anim.play("idle")
			else:
				var target: Node = level.zombie_in_front(cell.y, position.x, data.range_px)
				if target != null:
					target.take_damage(data.damage, 0.0, 0.0)
					if level.has_method("play_sfx"):
						level.play_sfx("chomp")
					_chewing = data.chew_time
					_bite_timer = 0.45
					if _anim != null:
						_anim.play("bite", true)
					queue_redraw()
	queue_redraw()


func take_damage(amount: int) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.12
	if hp <= 0:
		_die()


func alive() -> bool:
	return not dead


func _die() -> void:
	if dead:
		return
	dead = true
	if level != null and level.has_method("on_plant_died"):
		level.on_plant_died(self)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 4), 18.0, Color(0, 0, 0, 0.18))
	if _anim == null:
		match data.behavior:
			"producer":
				_draw_sunflower()
			"blocker":
				_draw_blocker()
			"mine":
				_draw_mine()
			"bomb":
				_draw_bomb()
			"chomper":
				_draw_chomper()
			_:
				_draw_peashooter()
	if _flash > 0.0:
		draw_circle(Vector2(0, -28), 24.0, Color(1, 1, 1, _flash * 4.0))


func _draw_stem() -> void:
	draw_rect(Rect2(-4, -26, 8, 28), data.accent_color)
	draw_circle(Vector2(-8, -6), 7.0, data.accent_color)
	draw_circle(Vector2(8, -4), 7.0, data.accent_color)


func _draw_peashooter() -> void:
	_draw_stem()
	draw_circle(Vector2(0, -32), 15.0, data.body_color)
	draw_rect(Rect2(11, -38, 14, 10), data.accent_color.darkened(0.15))
	draw_circle(Vector2(-4, -36), 3.0, Color(0.05, 0.1, 0.05))
	draw_circle(Vector2(-4.5, -36.5), 1.0, Color(1, 1, 1, 0.8))


func _draw_sunflower() -> void:
	_draw_stem()
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var petal := Vector2(cos(angle), sin(angle)) * 15.0 + Vector2(0, -34)
		draw_circle(petal, 6.0, Color("ffd54f"))
	draw_circle(Vector2(0, -34), 11.0, Color("8d6e3f"))
	draw_circle(Vector2(0, -34), 8.0, data.body_color)
	draw_circle(Vector2(-3, -36), 2.0, Color(0.1, 0.08, 0.02))


func _draw_blocker() -> void:
	draw_rect(Rect2(-22, -52, 44, 54), data.body_color)
	draw_rect(Rect2(-22, -52, 8, 54), data.accent_color)
	draw_rect(Rect2(14, -52, 8, 54), data.accent_color)
	draw_circle(Vector2(-6, -34), 3.0, Color(0.1, 0.07, 0.02))
	draw_circle(Vector2(6, -34), 3.0, Color(0.1, 0.07, 0.02))


func _draw_mine() -> void:
	if _armed:
		draw_circle(Vector2(0, -6), 16.0, Color("6b4a2b"))
		draw_line(Vector2(0, -6), Vector2(0, -22), Color("4a3320"), 3.0)
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.01)
		draw_circle(Vector2(0, -24), 4.0, Color(1.0, 0.2, 0.15, blink))
	else:
		draw_circle(Vector2(0, 0), 13.0, Color("6b4a2b"))
		draw_circle(Vector2(0, -2), 7.0, Color("8a6238"))


func _draw_bomb() -> void:
	var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
	draw_circle(Vector2(-8, -14), 13.0 * pulse, Color("d83b3b"))
	draw_circle(Vector2(9, -12), 12.0, Color("b52c2c"))
	draw_line(Vector2(0, -24), Vector2(4, -36), Color("4a6a1a"), 3.0)
	draw_circle(Vector2(4, -38), 3.0, Color("ffb300"))


func _draw_chomper() -> void:
	_draw_stem()
	draw_circle(Vector2(0, -30), 18.0, Color("7b3fa0"))
	draw_circle(Vector2(6, -26), 10.0, Color("4a1f63"))
	if _chewing > 0.0:
		draw_line(Vector2(10, -32), Vector2(20, -30), Color("4a1f63"), 2.0)
	else:
		draw_circle(Vector2(10, -32), 2.0, Color(1, 1, 1))
