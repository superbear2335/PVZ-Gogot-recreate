@tool
class_name CardBar
extends Control
## 顶部卡片栏：阳光计数 + 植物卡片 + 冷却遮罩。自绘，不依赖图片资源。
## 鼠标事件只在自己的 84px 高度内拦截，草坪点击继续交给 Level。

signal card_selected(index: int)

const CARD_SIZE := Vector2(60, 72)
const CARD_GAP := 4.0
const CARDS_ORIGIN := Vector2(88, 4)
const PANEL_HEIGHT := 84.0

var level: Node
var plant_datas: Array[PlantData] = []
var cooldowns: Array[float] = []
var selected_index := -1

var _sun_total := 0
var _font: Font


func setup(p_level: Node, plant_ids: Array) -> void:
	level = p_level
	_font = ThemeDB.fallback_font
	var catalog := GameCatalog.load_plants()
	for raw_id in plant_ids:
		var id := String(raw_id)
		var plant_data: PlantData = catalog.get(id)
		if plant_data == null:
			push_warning("CardBar：找不到植物数据 %s" % id)
			continue
		plant_datas.append(plant_data)
		cooldowns.append(0.0)
	position = Vector2.ZERO
	size = Vector2(800, PANEL_HEIGHT)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_sun(total: int) -> void:
	_sun_total = total
	queue_redraw()


func tick(delta: float) -> void:
	var changed := false
	for i in cooldowns.size():
		if cooldowns[i] > 0.0:
			cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
			changed = true
	if changed:
		queue_redraw()


func selected_data() -> PlantData:
	if selected_index < 0 or selected_index >= plant_datas.size():
		return null
	return plant_datas[selected_index]


func is_on_cooldown(index: int) -> bool:
	return index >= 0 and index < cooldowns.size() and cooldowns[index] > 0.0


func start_cooldown(index: int) -> void:
	if index < 0 or index >= cooldowns.size():
		return
	cooldowns[index] = maxf(0.1, plant_datas[index].cooldown)
	selected_index = -1
	queue_redraw()


func clear_selection() -> void:
	selected_index = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	for i in plant_datas.size():
		if _card_rect(i).has_point(mouse.position):
			if not is_on_cooldown(i):
				selected_index = -1 if selected_index == i else i
				queue_redraw()
				card_selected.emit(selected_index)
			accept_event()
			return


func _draw() -> void:
	# 面板：左侧原版 SeedBank（含阳光槽），右侧延伸深棕木色。
	var seed_panel := PvzAssets.seed_bank()
	if seed_panel != null:
		draw_texture_rect(seed_panel, Rect2(0, 0, 446, 84), false)
		draw_rect(Rect2(446, 0, maxf(0.0, size.x - 446.0), PANEL_HEIGHT), Color("3b2414"))
	else:
		draw_rect(Rect2(0, 0, size.x, PANEL_HEIGHT), Color(0.11, 0.15, 0.07, 0.96))
	draw_line(Vector2(0, PANEL_HEIGHT), Vector2(size.x, PANEL_HEIGHT), Color(0.23, 0.13, 0.05), 2.0)
	# 阳光计数
	if seed_panel == null:
		var bank := PvzAssets.sun_bank()
		if bank != null:
			draw_texture_rect(bank, Rect2(2, 0, 78, 84), false)
		else:
			draw_rect(Rect2(4, 4, 78, 72), Color(0.19, 0.24, 0.12))
			draw_circle(Vector2(24, 30), 14.0, Color("ffd21f"))
			for i in 8:
				var angle := TAU * float(i) / 8.0
				draw_line(
					Vector2(24, 30) + Vector2(cos(angle), sin(angle)) * 16.0,
					Vector2(24, 30) + Vector2(cos(angle), sin(angle)) * 21.0,
					Color("ffd21f"), 2.0,
				)
	draw_string(_font, Vector2(9, 78), str(_sun_total), HORIZONTAL_ALIGNMENT_CENTER, 64, 14, Color("2a1c08"))
	draw_string(_font, Vector2(8, 77), str(_sun_total), HORIZONTAL_ALIGNMENT_CENTER, 64, 14, Color("fff3c4"))
	# 卡片
	for i in plant_datas.size():
		_draw_card(i)


func _draw_card(index: int) -> void:
	var plant_data := plant_datas[index]
	var rect := _card_rect(index)
	var affordable := _sun_total >= plant_data.cost
	var ready := not is_on_cooldown(index)
	var packet := PvzAssets.packet()
	if packet != null:
		draw_texture_rect(packet, rect, false)
	else:
		draw_rect(rect, Color(0.86, 0.82, 0.64))
		draw_rect(rect.grow(-3), Color(0.72, 0.78, 0.5))
	var icon := PvzAssets.plant_icon(plant_data.id)
	if icon != null:
		draw_texture_rect(icon, Rect2(rect.position + Vector2(7, 0), Vector2(46, 46)), false)
	else:
		var icon_center := rect.position + Vector2(CARD_SIZE.x * 0.5, 24)
		draw_circle(icon_center, 15.0, plant_data.body_color)
		draw_circle(icon_center + Vector2(-5, -5), 4.0, plant_data.accent_color)
	# 名称与造价
	draw_string(
		_font, rect.position + Vector2(0, 56), plant_data.display_name,
		HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 9, Color(0.12, 0.12, 0.06),
	)
	draw_string(
		_font, rect.position + Vector2(5, 70), str(plant_data.cost),
		HORIZONTAL_ALIGNMENT_CENTER, 34, 11, Color(0.08, 0.08, 0.04),
	)
	# 不可用遮罩
	if not affordable or not ready:
		draw_rect(rect.grow(-3), Color(0, 0, 0, 0.42))
	if not ready:
		var ratio: float = cooldowns[index] / maxf(0.1, plant_data.cooldown)
		var overlay_height := CARD_SIZE.y * clampf(ratio, 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(CARD_SIZE.x, overlay_height)), Color(0.05, 0.05, 0.1, 0.55))
	# 选中框
	if index == selected_index:
		draw_rect(rect.grow(1), Color(1.0, 0.9, 0.3), false, 3.0)


func _card_rect(index: int) -> Rect2:
	return Rect2(CARDS_ORIGIN + Vector2(index * (CARD_SIZE.x + CARD_GAP), 0), CARD_SIZE)
