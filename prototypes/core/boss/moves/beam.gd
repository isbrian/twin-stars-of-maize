extends "res://boss/moves/move.gd"
# 眼中寶石光束（第 3 段）：蓄力 1.2 秒、眼睛微亮（不可招架、不能用射身體打斷）
# → 貼地的水平光束（離地 beam_band）持續 0.5 秒，單跳跳得過。射中微亮 → 打斷、晃 1.0 秒（近戰空檔）。
# 光束長度＝Boss 前緣到面向那一側的場地邊界（計畫 D17）。

const Palace := preload("res://boss/palace_arena.gd")
const L := preload("res://combat/layers.gd")

enum Step { CHARGE, FIRE, WOBBLE }

var _rect := Rect2()  # 光束範圍（Boss 本地座標）


func begin() -> void:
	body_interruptible = false
	boss.light.set_state(Light.State.GLOW)
	telegraphing = true
	signal_kind = Sig.UNPARRY
	var band: Vector2 = boss.tn.beam_band
	var front: float = boss.facing * boss.SIZE.x / 2.0
	var edge: float = (Palace.LEFT if boss.facing < 0 else Palace.RIGHT) - boss.position.x
	_rect = Rect2(minf(front, edge), -band.y, absf(edge - front), band.y - band.x)
	boss.hitbox.configure(_rect.size, _rect.get_center(), L.PLAYER_HURT)


func tick(delta: float) -> bool:
	t += delta
	match step:
		Step.CHARGE:
			if t >= boss.tn.beam_charge:
				boss.light.set_state(Light.State.OFF)
				strike()
				go(Step.FIRE)
		Step.FIRE:
			if t >= boss.tn.beam_active:
				end_strike()
				return true
		Step.WOBBLE:
			if t >= boss.tn.beam_wobble:
				return true
	return false


func on_glow_hit() -> bool:
	if step != Step.CHARGE:
		return false
	telegraphing = false
	boss.light.set_state(Light.State.OFF)
	go(Step.WOBBLE)
	return false


func draw(ci: CanvasItem) -> void:
	if step == Step.FIRE:
		ci.draw_rect(_rect, Color(1, 1, 0.9, 0.9))
	elif step == Step.WOBBLE:  # 晃動：身上兩道斜線
		var k := sin(t * 30.0) * 12.0
		ci.draw_line(Vector2(-60 + k, -boss.SIZE.y - 20), Vector2(60 + k, -boss.SIZE.y - 50), Color(0.8, 0.85, 1.0), 5.0)
