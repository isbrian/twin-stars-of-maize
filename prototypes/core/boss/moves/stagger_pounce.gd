extends "res://boss/moves/move.gd"
# 失衡撲擊（第 3 段）：前搖 0.6 秒（可招架：衰弱到擋得住）→ 沿地面撲向「前搖開始時角色的 x」
# → 落地不穩 1.2 秒（近戰空檔）。被招架：判定結束、直接進入不穩。

const Palace := preload("res://boss/palace_arena.gd")

enum Step { TELEGRAPH, POUNCE, REST }

var aim_x := 0.0
var traveled := 0.0


func begin() -> void:
	aim_x = boss.target.global_position.x if boss.target != null else boss.position.x
	aim_x = clampf(aim_x, Palace.LEFT + 90.0, Palace.THRONE_X)
	boss.configure_body_hitbox()
	telegraphing = true
	signal_kind = Sig.PARRY


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.TELEGRAPH:
			if t >= boss.tn.pounce_telegraph:
				strike()
				go(Step.POUNCE)
		Step.POUNCE:
			var before: float = boss.position.x
			boss.position.x = move_toward(boss.position.x, aim_x, boss.tn.pounce_speed * delta)
			traveled += absf(boss.position.x - before)
			if absf(aim_x - boss.position.x) <= 20.0 or traveled >= boss.tn.pounce_max:
				end_strike()
				go(Step.REST)
		Step.REST:
			if t >= boss.tn.pounce_rest:
				return true
	return false


func on_parried() -> void:
	end_strike()
	go(Step.REST)
