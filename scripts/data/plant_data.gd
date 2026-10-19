class_name PlantData
extends Resource
## 植物静态数据。数值来源与说明见 docs/values.md 第 3 节。

@export var id: String = ""
@export var display_name: String = ""
@export var cost: int = 100
@export var cooldown: float = 7.5
@export var max_hp: int = 300

## shooter：定时向本行发射子弹；producer：定时产出阳光；blocker：仅肉盾。
@export_enum("shooter", "producer", "blocker", "mine", "bomb", "chomper") var behavior: String = "shooter"

@export_group("攻击")
@export var damage: int = 20
@export var attack_interval: float = 1.4
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var projectile_color: Color = Color("4caf50")
@export var slow_factor: float = 0.0
@export var slow_duration: float = 0.0
@export var range_px: float = 0.0
@export var shots_per_volley: int = 1
@export var arm_time: float = 0.0
@export var fuse_time: float = 0.0
@export var aoe_cells: float = 0.0
@export var chew_time: float = 0.0

@export_group("产出")
@export var sun_amount: int = 0
@export var sun_interval: float = 0.0

@export_group("视觉占位")
@export var body_color: Color = Color("4caf50")
@export var accent_color: Color = Color("2e7d32")
