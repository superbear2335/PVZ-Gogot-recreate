class_name ZombieData
extends Resource
## 僵尸静态数据。数值来源与说明见 docs/values.md 第 4 节。

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 200
@export var armor_hp: int = 0
@export var speed: float = 11.0
@export var eat_damage: int = 30
@export var eat_interval: float = 0.5
@export var point_cost: int = 1

## 特殊能力："" | "pole"（撑杆跳，跳过第一株植物）。
@export var ability: String = ""

@export_group("视觉占位")
@export var body_color: Color = Color("9aa4a8")
@export var armor_color: Color = Color("d9832a")
@export var armor_label: String = ""
