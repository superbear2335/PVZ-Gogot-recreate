class_name LawnGrid
extends RefCounted
## 9×5 草坪网格的几何换算。纯函数，无状态，所有实体共用同一套坐标。

const COLS := 9
const ROWS := 5
const CELL_SIZE := Vector2(80.0, 100.0)
const ORIGIN := Vector2(40.0, 80.0)

const SPAWN_X := 830.0
const HOUSE_X := 0.0
const MOWER_X := 10.0
const MOWER_TRIGGER_X := 30.0
const MOWER_END_X := 760.0


static func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


static func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(
		(cell.x + 0.5) * CELL_SIZE.x,
		(cell.y + 0.5) * CELL_SIZE.y,
	)


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cell.x * CELL_SIZE.x, cell.y * CELL_SIZE.y), CELL_SIZE)


static func row_center_y(row: int) -> float:
	return ORIGIN.y + (row + 0.5) * CELL_SIZE.y + 8.0


static func column_center_x(col: int) -> float:
	return ORIGIN.x + (col + 0.5) * CELL_SIZE.x


## 世界坐标 → 格子；落在网格外返回 (-1, -1)。
static func world_to_cell(world_position: Vector2) -> Vector2i:
	var local := world_position - ORIGIN
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var col := int(floor(local.x / CELL_SIZE.x))
	var row := int(floor(local.y / CELL_SIZE.y))
	var cell := Vector2i(col, row)
	return cell if is_valid_cell(cell) else Vector2i(-1, -1)
