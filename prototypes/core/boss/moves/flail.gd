extends "res://boss/moves/move.gd"
# 痛到亂揮翅膀（第 2 段）：走到角色身邊（最多追 boss_chase_max 秒）→ 前搖 0.5 秒（可招架）
# → 對身體周圍攻擊 0.6 秒 → 接下一招。被招架：判定結束、直接接下一招（計畫 D4）。

const Palace := preload("res://boss/palace_arena.gd")
const L := preload("res://combat/layers.gd")
const REACH := 150.0

enum Step { CHASE, TELEGRAPH, ATTACK, DONE }


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.CHASE:
			var dx: float = boss.target.global_position.x - boss.position.x if boss.target != null else 0.0
			if absf(dx) <= REACH or t >= boss.tn.boss_chase_max:
				boss.face_target()
				boss.hitbox.configure(boss.tn.flail_box, Vector2(0, -boss.SIZE.y / 2.0), L.PLAYER_HURT)
				go(Step.TELEGRAPH)
				telegraphing = true
				signal_kind = Sig.PARRY
			else:
				var to := clampf(boss.target.global_position.x - signf(dx) * REACH, Palace.LEFT + 90.0, Palace.THRONE_X)
				boss.position.x = move_toward(boss.position.x, to, boss.tn.boss_walk_speed * delta)
		Step.TELEGRAPH:
			if t >= boss.tn.flail_telegraph:
				strike()
				go(Step.ATTACK)
		Step.ATTACK:
			if t >= boss.tn.flail_active:
				end_strike()
				return true
		Step.DONE:
			return true
	return false


func on_parried() -> void:
	end_strike()
	go(Step.DONE)
