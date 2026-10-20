extends "res://combat/hurtbox.gd"
# Boss 的光源（MV-PROTO-003 規格書第 2 節、BOSS-6-2b）：熄滅／微亮／最亮。
# 只有飛鏢的射線查得到（碰撞層 LIGHT）；熄滅時拿掉層，飛鏢穿過去打身體（計畫 D2）。

const L := preload("res://combat/layers.gd")

enum State { OFF, GLOW, BRIGHT }
enum Effect { NONE, GLOW_HIT, SETUP }

var state := State.OFF
var _t := 0.0


func set_state(s: int) -> void:
	state = s
	set_deferred("collision_layer", 0 if s == State.OFF else L.LIGHT)  # 射線查詢不看 monitorable，要拿掉層
	queue_redraw()


## 飛鏢射中的效果：微亮＝誰的箭都算；最亮＝只有能觸發設局的箭（發射時決定）
static func effect(s: int, can_setup: bool) -> int:
	if s == State.GLOW:
		return Effect.GLOW_HIT
	if s == State.BRIGHT and can_setup:
		return Effect.SETUP
	return Effect.NONE


func _process(delta: float) -> void:
	_t += delta
	if state != State.OFF:
		queue_redraw()


func _draw() -> void:
	match state:
		State.OFF:  # 暗珠寶色小圓：位置看得到，但沒有光
			draw_circle(Vector2.ZERO, 6.0, Color(0.35, 0.45, 0.4))
		State.GLOW:  # 微亮：小光點，0.5 秒週期脈動（ART_SPEC「弱點」）
			var k := 0.5 + 0.5 * sin(_t * TAU * 2.0)
			draw_circle(Vector2.ZERO, 9.0 + 3.0 * k, Color(1.0, 1.0, 0.75, 0.6 + 0.4 * k))
		State.BRIGHT:  # 最亮：整個光源爆亮、向外放射，加上往外擴散的光環（Brian 試打 2026-10-05：硬直時不知道該打哪裡）
			for j in 2:
				var k := fmod(_t / 0.6 + j * 0.5, 1.0)  # 0.6 秒一圈，兩圈錯開
				draw_arc(Vector2.ZERO, 50.0 + 120.0 * k, 0.0, TAU, 48, Color(1, 1, 0.8, 0.9 * (1.0 - k)), 8.0)
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0 + _t)
				draw_line(dir * 40.0, dir * 140.0, Color(1, 1, 0.85, 0.9), 8.0)
			draw_circle(Vector2.ZERO, 40.0, Color(1, 1, 0.9))
