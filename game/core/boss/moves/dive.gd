extends "res://core/boss/moves/move.gd"
# 俯衝（第 1 段）：飛回樹冠 → 前搖 0.7 秒（不可招架）→ 朝「前搖開始時角色的位置」斜衝到地面
# → 落地喘 1.2 秒（近戰空檔）。角色在空中時沿同一方向衝到地面為止。

const Nance := preload("res://core/boss/nance_arena.gd")

enum Step { TRAVEL, TELEGRAPH, DIVE, REST }

var landing := Vector2.ZERO


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.TRAVEL:
			if boss.fly_to(Nance.CANOPY, boss.tn.boss_fly_speed, delta):
				boss.face_target()
				landing = _landing(boss.target.global_position if boss.target != null else boss.position)
				boss.configure_body_hitbox()
				go(Step.TELEGRAPH)
				telegraphing = true
				signal_kind = Sig.UNPARRY
		Step.TELEGRAPH:
			if t >= boss.tn.dive_telegraph:
				strike()
				sfx(&"boss_sm_dive")
				go(Step.DIVE)
		Step.DIVE:
			if boss.fly_to(landing, boss.tn.dive_speed, delta):
				boss.position = landing
				end_strike()
				go(Step.REST)
		Step.REST:
			if t >= boss.tn.dive_rest:
				return true
	return false


## 從目前位置經過 aim 延伸到地面的落點（x 夾在場地內）
func _landing(aim: Vector2) -> Vector2:
	var from: Vector2 = boss.position
	var p := aim
	if aim.y > from.y:
		p = from + (aim - from) * ((Nance.GROUND_Y - from.y) / (aim.y - from.y))
	var half: float = maxf(-boss.body_rect.position.x, boss.body_rect.end.x)  # 身體框離原點較遠的一側：兩個面向都不穿出場地
	return Vector2(clampf(p.x, Nance.LEFT + half, Nance.RIGHT - half), Nance.GROUND_Y)
