extends Node2D
# 假光閃耀前搖的特效外觀（MV-SLICE-001c1「光點匯聚」）：掛在 Boss 底下。
# flash_telegraph 期間周圍 10 個細小光點往他身上聚、身上光暈越來越強；不畫圓形或鋸齒（那是招架訊號）。

const FxKit := preload("res://world/fx/fx_kit.gd")
const FalseFlash := preload("res://core/boss/moves/false_flash.gd")

const MOTES := 10
const MOTE_D := 14.0  # 光點直徑
const FAR := 320.0  # 光點起始半徑（強度 0）
const NEAR := 30.0  # 強度 1 時的半徑
const BODY_D := Vector2(140.0, 420.0)  # 身上光暈直徑：強度 0～1
const MARGIN := NEAR + 50.0  # 聚光中心離畫面上緣至少這麼遠（樹冠上的身體中段在畫面外，MV-SLICE-001c1 最終審查）

var boss: Node2D
var _angles := PackedFloat32Array()
var _reach := PackedFloat32Array()


static func attach(b: Node2D) -> Node2D:
	var fx = new()
	fx.name = "FlashFx"
	fx.boss = b
	fx.material = FxKit.add_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # 位置固定：每次閃耀看起來一樣
	for i in MOTES:
		fx._angles.append(TAU * i / MOTES + rng.randf_range(-0.25, 0.25))
		fx._reach.append(rng.randf_range(0.75, 1.0))
	b.add_child(fx)
	return fx


## 目前的聚光強度 0～1：假光閃耀的前搖進度，其餘時候 0
func strength() -> float:
	var m = boss.move
	if m is FalseFlash and m.step == FalseFlash.Step.TELEGRAPH:
		return clampf(m.t / boss.tn.flash_telegraph, 0.0, 1.0)
	return 0.0


## 聚光中心（Boss 本地座標）：身體中段；在畫面上緣附近或以外（停在樹冠）時往下移，收攏的光點留在畫面內
func center() -> Vector2:
	var body: Rect2 = boss.faced_body()
	var c := Vector2(body.get_center().x, body.end.y - body.size.y * 0.55)
	var xf := get_global_transform_with_canvas()
	var on_screen := xf * c
	if on_screen.y < MARGIN:
		c = xf.affine_inverse() * Vector2(on_screen.x, MARGIN)
	return c


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var k := strength()
	if k <= 0.0:
		return
	var tex := FxKit.glow_texture(64)
	var c := center()
	var d := lerpf(BODY_D.x, BODY_D.y, k)
	draw_texture_rect(tex, Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d)), false, Color(1, 1, 1, 0.2 + 0.6 * k))
	for i in MOTES:
		var r := lerpf(FAR * _reach[i], NEAR, k)
		var p := c + Vector2.from_angle(_angles[i]) * r
		draw_texture_rect(tex, Rect2(p - Vector2(MOTE_D, MOTE_D) / 2.0, Vector2(MOTE_D, MOTE_D)), false, Color(1, 1, 1, 0.5 + 0.5 * k))
