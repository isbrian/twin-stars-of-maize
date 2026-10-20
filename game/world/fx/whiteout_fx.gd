extends Control
# 白茫的特效外觀（MV-SLICE-001c1「從他身上擴散的白茫」）：加在 whiteout 同一層，讀 whiteout.t。
# 先畫全畫面 Whiteout.alpha_at(s) 的暖白，淡入段再以 Boss 的畫面位置為中心加一層擴散的光暈；
# 任何一點都不比原本的白茫淡（alpha_at_point ≥ alpha_at），維持段全畫面 0.9、淡出照原曲線。

const FxKit := preload("res://world/fx/fx_kit.gd")
const Whiteout := preload("res://ui/whiteout.gd")

const REACH := Vector2(300.0, 2600.0)  # 擴散光暈半徑：淡入開始～結束（結束時蓋過 1920×1080 的對角）

static var _bloom_tex: GradientTexture2D

var whiteout
var boss: Node2D


static func attach(w: Control, b: Node2D) -> Control:
	var fx = new()
	fx.name = "WhiteoutFx"
	fx.whiteout = w
	fx.boss = b
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := w.get_parent()
	layer.add_child(fx)
	layer.move_child(fx, w.get_index() + 1)
	w.fx_drawn = true
	return fx


## 某一點的白度：原本的白茫曲線與擴散光暈取大
static func alpha_at_point(s: float, p: Vector2, src: Vector2, tn) -> float:
	return maxf(Whiteout.alpha_at(s, tn), bloom(s, p, src, tn))


## 擴散光暈：只在淡入段；中心 0.9、到半徑線性降到 0
static func bloom(s: float, p: Vector2, src: Vector2, tn) -> float:
	if s < 0.0 or s >= tn.whiteout_in:
		return 0.0
	var r := lerpf(REACH.x, REACH.y, s / tn.whiteout_in)
	return Whiteout.MAX_ALPHA * clampf(1.0 - p.distance_to(src) / r, 0.0, 1.0)


## 中心不透明、到邊緣線性透明的放射貼圖（對應 bloom 的曲線）
static func bloom_texture() -> Texture2D:
	if _bloom_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_bloom_tex = GradientTexture2D.new()
		_bloom_tex.gradient = g
		_bloom_tex.width = 256
		_bloom_tex.height = 256
		_bloom_tex.fill = GradientTexture2D.FILL_RADIAL
		_bloom_tex.fill_from = Vector2(0.5, 0.5)
		_bloom_tex.fill_to = Vector2(0.5, 0.0)
	return _bloom_tex


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s: float = whiteout.t
	var tn = whiteout.tn
	var a := Whiteout.alpha_at(s, tn)
	if a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(FxKit.CORE, a))
	if s >= 0.0 and s < tn.whiteout_in:
		var src := boss.get_global_transform_with_canvas().origin
		var r := lerpf(REACH.x, REACH.y, s / tn.whiteout_in)
		draw_texture_rect(bloom_texture(), Rect2(src - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(FxKit.CORE, Whiteout.MAX_ALPHA))
