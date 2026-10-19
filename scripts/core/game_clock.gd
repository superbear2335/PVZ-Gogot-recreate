class_name GameClock
extends RefCounted
## 关卡时钟：统一承载时间倍率、已流逝的玩法时间与随机源。
##
## 所有玩法计时（冷却、攻速、波次、阳光）都走 tick() 返回的缩放后 delta，
## 保证 1×/2×/3× 倍速只影响玩法，不影响输入与渲染帧。


var time_scale: float = 1.0
var elapsed: float = 0.0
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value
	elapsed = 0.0


## 返回缩放后的玩法 delta，并累加 elapsed。
func tick(real_delta: float) -> float:
	var scaled := real_delta * time_scale
	elapsed += scaled
	return scaled
