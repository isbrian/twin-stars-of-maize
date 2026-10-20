extends Node2D
# 眼中寶石光束的特效外觀（MV-SLICE-001c1「瞄準虛線＋柔光光束」）：掛在 Boss 底下，讀 boss.move（是 beam 時）。
# MV-SLICE-001c4c2：也能掛在反光型底下（讀它的 state、beam_rect、glow_at、state_time）。
# 蓄力：地面閃出一條虛線＝判定矩形的中線、範圍相同（眼睛的微亮光暈由 LightFx 畫）；
# 出招：眼睛到光束起點的連結亮線＋光束（實心＝判定，中心白、上下金邊、往前流動）。

const FxKit := preload("res://world/fx/fx_kit.gd")
const Beam := preload("res://core/boss/moves/beam.gd")
const Enemy := preload("res://core/enemies/enemy.gd")

const SOFT := 6.0  # 光束上下柔光
const FLOW_SPEED := 1400.0  # 往前流動的光紋速度（px/秒）
const STREAKS := 5

var boss: Node2D
var _t := 0.0


static func attach(b: Node2D) -> Node2D:
	var fx = new()
	fx.name = "BeamFx"
	fx.boss = b
	fx.material = FxKit.add_material()
	b.add_child(fx)
	if b.has_method("blocks"):  # 反光型：光束畫在本體（骨架）後面，看起來從反光面前方出來（c4c2 最終審查）
		fx.show_behind_parent = true
		b.move_child(fx, 0)
	return fx


func _beam():
	return boss.move if boss.move is Beam else null


func _reflector() -> bool:
	return boss.has_method("blocks")


## 0＝沒有光束、1＝蓄力、2＝射出
func phase() -> int:
	if _reflector():
		return 1 if boss.state == Enemy.State.TELEGRAPH else (2 if boss.state == Enemy.State.ATTACK else 0)
	var m = _beam()
	if m == null:
		return 0
	return 1 if m.step == Beam.Step.CHARGE else (2 if m.step == Beam.Step.FIRE else 0)


## 光束實心（本地座標）＝判定；不是光束時為空
func core_rect() -> Rect2:
	if _reflector():
		return boss.beam_rect if phase() > 0 else Rect2()
	var m = _beam()
	return m.area() if m != null else Rect2()


## 瞄準虛線兩端（靠 Boss 那端在前）：判定中線、x 範圍相同；不是光束時為空
func aim_line() -> PackedVector2Array:
	if phase() == 0:
		return PackedVector2Array()
	var a := core_rect()
	var y := a.get_center().y
	var near := a.position.x if boss.facing > 0 else a.end.x
	var far := a.end.x if boss.facing > 0 else a.position.x
	return PackedVector2Array([Vector2(near, y), Vector2(far, y)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var ph := phase()
	if ph == 0:
		return
	var ln := aim_line()
	match ph:
		1:
			var k := 0.5 + 0.5 * sin(_t * TAU * 3.0)
			draw_dashed_line(ln[0], ln[1], Color(FxKit.CORE, 0.35 + 0.35 * k), 4.0, 24.0)
		2:
			var a := core_rect()
			var eye: Vector2 = boss.glow_at if _reflector() else boss.light.position
			var flow_t: float = boss.state_time if _reflector() else _beam().t
			draw_line(eye, ln[0], Color(FxKit.GOLD, 0.6), 8.0)
			draw_line(eye, ln[0], Color(FxKit.CORE, 0.9), 3.0)
			draw_rect(a.grow_individual(0, SOFT, 0, SOFT), Color(FxKit.GOLD, 0.2))  # 柔光
			draw_rect(a, Color(FxKit.GOLD, 0.6))
			draw_rect(Rect2(a.position.x, a.position.y + a.size.y * 0.3, a.size.x, a.size.y * 0.4), Color(FxKit.CORE, 0.8))
			var dir: float = boss.facing
			for i in STREAKS:  # 往前流動的光紋
				var d := fposmod(flow_t * FLOW_SPEED + i * a.size.x / STREAKS, a.size.x)
				var x := ln[0].x + dir * d
				draw_rect(Rect2(x - 40.0, a.position.y + a.size.y * 0.4, 80.0, a.size.y * 0.2), Color(FxKit.CORE, 0.4))
