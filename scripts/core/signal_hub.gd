class_name SignalHub
extends Node
## 关卡内的事件总线。Level 持有唯一实例，UI / 实体通过它解耦。
##
## 约定：参数保持 Variant（Node）而非具体类，避免实体与 Level 的类型循环依赖。

signal sun_changed(total: int)
signal sun_collected(amount: int, world_position: Vector2)
signal plant_placed(plant: Node)
signal plant_died(plant: Node)
signal zombie_spawned(zombie: Node)
signal zombie_died(zombie: Node)
signal wave_started(index: int, is_huge: bool)
signal level_won
signal level_lost
