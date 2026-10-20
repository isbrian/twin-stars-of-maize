extends "res://boss/moves/move.gd"
# 吃果子（第 1 段）：降到低枝吃 2.5 秒，下顎微亮（近戰空檔）；微亮被射中 → 中斷（下一招的移動會飛回樹冠）。

const Nance := preload("res://boss/nance_arena.gd")

enum Step { TRAVEL, EAT }


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.TRAVEL:
			if boss.fly_to(Nance.PERCH, boss.tn.boss_fly_speed, delta):
				go(Step.EAT)
				boss.light.set_state(Light.State.GLOW)
		Step.EAT:
			if t >= boss.tn.eat_time:
				boss.light.set_state(Light.State.OFF)
				return true
	return false


func on_glow_hit() -> bool:
	return true
