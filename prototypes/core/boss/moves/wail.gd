extends "res://boss/moves/move.gd"
# 捧著下顎哀嚎（第 2 段）：原地 2.5 秒，玉牙微亮（近戰空檔）；微亮被射中 → 中斷。


func begin() -> void:
	boss.light.set_state(Light.State.GLOW)


func tick(delta: float) -> bool:
	t += delta
	if t >= boss.tn.wail_time:
		boss.light.set_state(Light.State.OFF)
		return true
	return false


func on_glow_hit() -> bool:
	return true
