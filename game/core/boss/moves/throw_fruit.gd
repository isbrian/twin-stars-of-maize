extends "res://core/boss/moves/move.gd"
# 擲果（第 1 段）：飛回樹冠 → 前搖 0.6 秒（可招架）→ 朝角色擲出一顆果子 → 停在樹冠。

const Nance := preload("res://core/boss/nance_arena.gd")
const Fruit := preload("res://core/boss/fruit.gd")

enum Step { TRAVEL, TELEGRAPH }


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.TRAVEL:
			if boss.fly_to(Nance.CANOPY, boss.tn.boss_fly_speed, delta):
				boss.face_target()
				go(Step.TELEGRAPH)
				telegraphing = true
				signal_kind = Sig.PARRY
		Step.TELEGRAPH:
			if t >= boss.tn.throw_telegraph:
				telegraphing = false
				_throw()
				return true
	return false


func _throw() -> void:
	sfx(&"boss_sm_throw")
	if boss.target == null:
		return
	var f = Fruit.new()
	f.tn = boss.tn
	f.boss = boss
	var from: Vector2 = boss.global_position + Vector2(boss.facing * 70.0, -80.0)
	f.direction = from.direction_to(boss.target.global_position + Vector2(0, -90))
	boss.get_parent().add_child(f)
	f.global_position = from
