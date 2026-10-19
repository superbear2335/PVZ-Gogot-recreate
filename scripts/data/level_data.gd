class_name LevelData
extends Resource
## 关卡静态数据。waves 为字典数组，避免为每个波次单独建 .tres：
##   { "delay": float, "count": int, "is_huge": bool }
## delay 是相对上一波“开始出怪”的间隔。

@export var id: String = ""
@export var display_name: String = ""
@export var seed_value: int = 1
@export var starting_sun: int = 50

## 本关可用的植物 id 列表，决定卡片栏顺序。
@export var available_plants: Array = []

## 本关可能出现的僵尸 id 列表（波次按点数抽取，M1 先按数量抽取）。
@export var zombie_pool: Array = []
@export var waves: Array = []

@export_group("阳光")
@export var sky_sun_first: float = 4.5
@export var sky_sun_min: float = 4.5
@export var sky_sun_max: float = 9.0
@export var sun_value: int = 25
