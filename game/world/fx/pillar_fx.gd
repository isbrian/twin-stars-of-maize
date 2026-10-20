extends Node2D
# 寶座反光柱的特效外觀（MV-SLICE-001c1「柔光光柱」）：掛在光柱底下，依 pillar.t 畫落點或光柱。
# 落點（pillar_warn 秒內）：地面光斑寬＝柱寬＋垂直虛線；光柱：中心白、兩側金、往下流動，外圍柔光每邊 SOFT px。
# 實心部分＝判定框（不多不少），柔光不超過 SOFT。

const FxKit := preload("res://world/fx/fx_kit.gd")
const Pillar := preload("res://core/boss/pillar.gd")

const SOFT := 6.0  # 外圍柔光每邊寬（規格 ≤ 8）
const FLOW_SPEED := 900.0  # 往下流動的光紋速度（px/秒）
const STREAKS := 4

var pillar: Node2D


static func attach(pl: Node2D) -> Node2D:
	var fx = new()
	fx.name = "PillarFx"
	fx.pillar = pl
	fx.material = FxKit.add_material()
	pl.add_child(fx)
	pl.fx_drawn = true
	return fx


## 實心部分（pillar 本地座標，原點在地面）＝判定框
func core_rect() -> Rect2:
	return Rect2(-Pillar.SIZE.x / 2.0, -Pillar.SIZE.y, Pillar.SIZE.x, Pillar.SIZE.y)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := core_rect()
	var t: float = pillar.t
	var warn: float = pillar.tn.pillar_warn
	if t < warn:  # 落點：光斑漸亮＋虛線標出光柱範圍
		var k := clampf(t / warn, 0.0, 1.0)
		draw_texture_rect(FxKit.glow_texture(64), Rect2(c.position.x, -24.0, c.size.x, 36.0), false, Color(1, 1, 1, 0.5 + 0.5 * k))
		draw_dashed_line(Vector2(0, c.position.y), Vector2.ZERO, Color(FxKit.CORE, 0.25 + 0.2 * k), 3.0, 18.0)
		return
	draw_rect(c.grow_individual(SOFT, 0, SOFT, 0), Color(FxKit.GOLD, 0.2))  # 柔光
	draw_rect(c, Color(FxKit.GOLD, 0.55))
	draw_rect(Rect2(-c.size.x * 0.25, c.position.y, c.size.x * 0.5, c.size.y), Color(FxKit.CORE, 0.7))
	for i in STREAKS:  # 往下流動的光紋
		var y := fposmod((t - warn) * FLOW_SPEED + i * c.size.y / STREAKS, c.size.y) + c.position.y
		draw_rect(Rect2(-c.size.x * 0.15, y, c.size.x * 0.3, minf(80.0, -y)), Color(FxKit.CORE, 0.35))
