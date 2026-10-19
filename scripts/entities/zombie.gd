@tool
class_name Zombie
extends Node2D
## 僵尸基类：行走 → 啃食 → 进房/死亡。支持 "pole" 撑杆跳能力。
## 坐标约定：position 为双脚落点（行中心 + 8）。

const BODY_HALF_WIDTH := 16.0
const VISUAL_SCALE := 0.7

var _jump_timer := 0.0
var _anim: AnimSprite

var data: ZombieData
var level: Node
var row: int = 0
var hp: int = 200
var armor: int = 0
var speed: float = 11.0
var state := "walk"

var _eat_timer := 0.0
var _slow_timer := 0.0
var _flash := 0.0
var _dead := false
var _reached_house := false
var _pole_used := false
var _eat_target: Node = null


func setup(p_data: ZombieData, p_row: int, p_level: Node) -> void:
	data = p_data
	row = p_row
	level = p_level
	hp = data.max_hp
	armor = data.armor_hp
	speed = data.speed
	position = Vector2(LawnGrid.SPAWN_X, LawnGrid.row_center_y(row))
	z_index = 4
	_setup_visual()
	queue_redraw()


func _setup_visual() -> void:
	_anim = AnimSprite.new()
	add_child(_anim)
	if not _anim.setup("zombies", data.id, "walk", VISUAL_SCALE, Color.WHITE, 36.0):
		_anim.queue_free()
		_anim = null


func tick(delta: float) -> void:
	if _dead:
		return
	_flash = maxf(0.0, _flash - delta)
	_slow_timer = maxf(0.0, _slow_timer - delta)
	if _anim != null:
		_anim.advance(delta)
		_anim.modulate = Color(0.72, 0.86, 1.0) if _slow_timer > 0.0 else Color.WHITE
	if _jump_timer > 0.0:
		_jump_timer = maxf(0.0, _jump_timer - delta)
		if _jump_timer <= 0.0 and _anim != null:
			_anim.play("walk")
	var factor := 0.5 if _slow_timer > 0.0 else 1.0
	if state == "eat":
		if _anim != null:
			_anim.play("eat")
		_tick_eating(delta * factor)
		queue_redraw()
		return
	if _reached_house:
		return
	if position.x <= LawnGrid.HOUSE_X:
		_enter_house()
		return
	# 撑杆跳：遇到第一株植物前起跳，落到植物左侧后不再跳。
	if data.ability == "pole" and not _pole_used:
		var jump_target: Node = level.plant_in_front(row, position.x, 70.0)
		if jump_target != null:
			_pole_used = true
			position.x = jump_target.position.x - 72.0
			state = "walk"
			_eat_target = null
			_jump_timer = 0.5
			if _anim != null:
				_anim.play("jump", true)
			queue_redraw()
			return
	var plant: Node = level.find_plant_at_world(Vector2(position.x - 24.0, position.y - 20.0))
	if plant != null and plant.alive():
		state = "eat"
		_eat_target = plant
		_eat_timer = 0.0
		queue_redraw()
		return
	position.x -= speed * factor * delta
	queue_redraw()


func _tick_eating(delta: float) -> void:
	if _eat_target == null or not is_instance_valid(_eat_target) or not _eat_target.alive():
		state = "walk"
		_eat_target = null
		if _anim != null:
			_anim.play("walk")
		return
	_eat_timer += delta
	if _eat_timer >= data.eat_interval:
		_eat_timer -= data.eat_interval
		_eat_target.take_damage(data.eat_damage)


func _enter_house() -> void:
	_reached_house = true
	state = "house"
	position.x = 0.0
	if level != null and level.has_method("on_zombie_reached_house"):
		level.on_zombie_reached_house(self)


func take_damage(amount: int, slow_factor: float = 0.0, slow_duration: float = 0.0) -> void:
	if _dead:
		return
	if armor > 0:
		armor -= amount
		if armor < 0:
			hp += armor
			armor = 0
	else:
		hp -= amount
	if slow_factor > 0.0:
		_slow_timer = maxf(_slow_timer, slow_duration)
	_flash = 0.1
	if hp <= 0:
		_die()
		return
	queue_redraw()


func _die() -> void:
	if _dead:
		return
	_dead = true
	if level != null and level.has_method("on_zombie_died"):
		level.on_zombie_died(self)
	# 死亡表现：短促后仰淡出，再释放节点。
	z_index = -1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.55)
	tween.tween_property(self, "rotation", -0.45, 0.55)
	tween.chain().tween_callback(queue_free)


func is_dead() -> bool:
	return _dead


func alive() -> bool:
	return not _dead and not is_queued_for_deletion()


func reached_house() -> bool:
	return _reached_house


func is_slowed() -> bool:
	return _slow_timer > 0.0


func has_pole() -> bool:
	return data != null and data.ability == "pole" and not _pole_used


func _draw() -> void:
	draw_circle(Vector2(0, 0), 20.0, Color(0, 0, 0, 0.18))
	if _anim != null:
		if _flash > 0.0:
			draw_rect(Rect2(-16, -76, 32, 60), Color(1, 1, 1, _flash * 3.0))
		return
	var walk := sin(Time.get_ticks_msec() * 0.006 + float(row)) * 3.0
	draw_rect(Rect2(-11, -18, 8, 18), data.body_color.darkened(0.25))
	draw_rect(Rect2(3, -18, 8, 18 + walk), data.body_color.darkened(0.25))
	draw_rect(Rect2(-15, -52, 30, 36), data.body_color)
	draw_rect(Rect2(12, -46, 8, 26), data.body_color.darkened(0.1))
	draw_circle(Vector2(0, -62), 12.0, data.body_color.lightened(0.12))
	draw_circle(Vector2(5, -64), 2.2, Color(0.75, 0.1, 0.1))
	draw_rect(Rect2(2, -57, 8, 2), Color(0.15, 0.1, 0.1))
	if armor > 0:
		draw_rect(Rect2(-15, -74, 30, 14), data.armor_color)
		draw_rect(Rect2(-15, -74, 30, 3), data.armor_color.lightened(0.25))
	if has_pole():
		draw_line(Vector2(-8, -4), Vector2(14, -78), Color("7a5a32"), 4.0)
	if _slow_timer > 0.0:
		draw_circle(Vector2(0, -42), 26.0, Color(0.55, 0.85, 1.0, 0.18))
	if _flash > 0.0:
		draw_rect(Rect2(-16, -76, 32, 60), Color(1, 1, 1, _flash * 3.0))
