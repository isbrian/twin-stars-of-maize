extends "res://core/boss/moves/move.gd"
# 撞向寶座（第 2 段）：先移到「角色在他與寶座之間」的位置 → 前搖 0.8 秒（不可招架）
# → 高速衝向寶座（翻滾穿過或跳上兩側低台）→ 撞上寶座落下反光柱（第一道在角色位置，計畫 D16）→ 接下一招。

const Palace := preload("res://core/boss/palace_arena.gd")
const Pillar := preload("res://core/boss/pillar.gd")
const BEHIND := 350.0  # 站在角色左邊多遠（寶座在右）

enum Step { REPOSITION, TELEGRAPH, CHARGE, PILLARS }


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.REPOSITION:
			var px: float = boss.target.global_position.x if boss.target != null else Palace.HOME.x
			var to := Vector2(maxf(px - BEHIND, Palace.LEFT + 10.0), Palace.GROUND_Y)
			if boss.fly_to(to, boss.tn.boss_walk_speed, delta):
				boss.facing = 1  # 面向寶座
				boss._place_light()
				boss.configure_body_hitbox()
				go(Step.TELEGRAPH)
				telegraphing = true
				signal_kind = Sig.UNPARRY
		Step.TELEGRAPH:
			if t >= boss.tn.charge_telegraph:
				strike()
				go(Step.CHARGE)
		Step.CHARGE:
			if boss.fly_to(Vector2(Palace.THRONE_X, Palace.GROUND_Y), boss.tn.charge_speed, delta):
				end_strike()
				sfx(&"boss_sm_throne_hit")
				_drop_pillars()
				go(Step.PILLARS)
		Step.PILLARS:
			if t >= boss.tn.pillar_warn + boss.tn.pillar_active:
				return true
	return false


func _drop_pillars() -> void:
	var px: float = boss.target.global_position.x if boss.target != null else Palace.HOME.x
	for x in Palace.pillar_xs(boss.tn.pillar_count, px):
		var pl = Pillar.new()
		pl.tn = boss.tn
		pl.position = Vector2(x, Palace.GROUND_Y)
		boss.get_parent().add_child(pl)
