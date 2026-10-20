extends "res://boss/moves/move.gd"
# 假光閃耀（第 1 段、BOSS-6-2c）：飛回樹冠 → 1 秒前搖（展翅、全身聚光；不畫圓形或鋸齒、不能用射身體打斷）
# → 閃光：面向他的那一位白茫（由 boss_fight 判定並顯示）。

const Nance := preload("res://boss/nance_arena.gd")

enum Step { TRAVEL, TELEGRAPH }


func begin() -> void:
	body_interruptible = false


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.TRAVEL:
			if boss.fly_to(Nance.CANOPY, boss.tn.boss_fly_speed, delta):
				boss.face_target()
				go(Step.TELEGRAPH)
				telegraphing = true
		Step.TELEGRAPH:
			if t >= boss.tn.flash_telegraph:
				telegraphing = false
				boss.flashed.emit()
				return true
	return false


## 角色面向 Boss（同 x 視為面向）
static func is_facing(player_x: float, player_facing: int, boss_x: float) -> bool:
	return boss_x == player_x or (boss_x > player_x) == (player_facing > 0)


func draw(ci: CanvasItem) -> void:
	if step != Step.TELEGRAPH:
		return
	var k := clampf(t / boss.tn.flash_telegraph, 0.0, 1.0)
	var center := Vector2(0, -boss.SIZE.y * 0.55)
	for side in [-1, 1]:  # 展翅：身體兩側各 6 道金色光線，越接近閃光越長
		for i in 6:
			var dir := Vector2(side * cos(deg_to_rad(-60.0 + 24.0 * i)), sin(deg_to_rad(-60.0 + 24.0 * i)))
			ci.draw_line(center + dir * 70.0, center + dir * (110.0 + 160.0 * k), Color(1.0, 0.85, 0.35, 0.5 + 0.5 * k), 6.0)
