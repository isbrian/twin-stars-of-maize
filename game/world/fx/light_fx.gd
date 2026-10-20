extends Node2D
# 光源的特效外觀（MV-SLICE-001c1 SLICE-c1-5「A 柔光暈」）：跟著 light_source.state，掛在光源底下（跟著頭骨上的光點）。
# 熄滅＝暗色小點（一般混合，位置看得到、沒有光）；微亮＝小光暈 0.5 秒週期呼吸；最亮＝大光暈＋柔和擴散光環。
# 光暈畫在加亮混合的子節點 Glow 上（加亮畫不出暗色，熄滅的小點留在本節點）。

const FxKit := preload("res://world/fx/fx_kit.gd")
const Light := preload("res://core/boss/light_source.gd")

const TEX := 128  # 光暈貼圖尺寸（縮放畫）
const GLOW_D := 46.0  # 微亮光暈直徑
const BRIGHT_D := 190.0  # 最亮光暈直徑
const RING_TIME := 0.9  # 擴散光環一圈的秒數
const OFF_COLOR := Color(0.35, 0.45, 0.4)

var light: Node2D
var glow: Node2D
var _t := 0.0


static func attach(l: Node2D) -> Node2D:
	var fx = new()
	fx.name = "LightFx"
	fx.light = l
	fx.glow = Node2D.new()
	fx.glow.name = "Glow"
	fx.glow.material = FxKit.add_material()
	fx.glow.draw.connect(fx._draw_glow)
	fx.add_child(fx.glow)
	l.add_child(fx)
	l.fx_drawn = true
	return fx


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	if light.state == Light.State.OFF:
		draw_circle(Vector2.ZERO, 6.0, OFF_COLOR)


func _draw_glow() -> void:
	var tex := FxKit.glow_texture(TEX)
	match light.state:
		Light.State.GLOW:
			var k := 0.5 + 0.5 * sin(_t * TAU * 2.0)  # 0.5 秒一週期
			var d := GLOW_D * (0.85 + 0.3 * k)
			glow.draw_texture_rect(tex, Rect2(-d / 2.0, -d / 2.0, d, d), false, Color(1, 1, 1, 0.6 + 0.4 * k))
		Light.State.BRIGHT:
			glow.draw_texture_rect(tex, Rect2(-BRIGHT_D / 2.0, -BRIGHT_D / 2.0, BRIGHT_D, BRIGHT_D), false)
			var k := fmod(_t / RING_TIME, 1.0)
			var r := 50.0 + 100.0 * k
			var a := 0.6 * (1.0 - k)
			glow.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(FxKit.GOLD, a * 0.4), 18.0)  # 外圈淡、內圈亮：柔邊
			glow.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(FxKit.CORE, a), 6.0)
