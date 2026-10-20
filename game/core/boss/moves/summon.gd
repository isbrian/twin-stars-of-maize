extends "res://core/boss/moves/move.gd"
# 召喚（規格書第 3 節）：前搖只亮輪廓（不畫圓形或鋸齒）、不能用射身體打斷；
# 實際補造物由 boss_fight 接 summon_requested 處理（第 1 段各 1 隻、第 3 段各 2 隻）。


func begin() -> void:
	body_interruptible = false
	telegraphing = true
	sfx(&"boss_sm_gather")


func tick(delta: float) -> bool:
	t += delta
	if t < boss.tn.summon_telegraph:
		return false
	telegraphing = false
	boss.summon_requested.emit(boss.summon_cap())
	return true
