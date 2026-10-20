extends Node2D
# Seven Macaw 身上的假光（MV-SLICE-001c1「金飾光點一顆顆熄」）：金飾、寶石上約 10 個閃爍小光點（各自週期、錯開），
# 全身一層淡淡的假光光暈。光點是骨架資料的 glint_*（翅膀、軀幹、尾羽，不在頭上：換頭不受影響），每幀跟著骨頭。
# extinguish(seconds)：依離胸口（torso 骨頭起點）的距離由遠到近逐一熄、光暈線性淡到 0、身體變暗到約 ×0.5；c2 決定何時呼叫。

signal extinguished

const FxKit := preload("res://world/fx/fx_kit.gd")
const Tint := preload("res://world/tint.gd")

const NAMES := ["glint_1", "glint_2", "glint_3", "glint_4", "glint_5", "glint_6", "glint_7", "glint_8", "glint_9", "glint_10"]
const GLINT_D := 30.0  # 光點光暈直徑（比光源的微亮光暈 46 小：光源才是弱點）
const SPARK := 7.0  # 十字星芒半長
const AURA_ALPHA := 0.15  # 全身假光的透明度
const DIM := 0.5  # 熄滅後身體的亮度倍率

var boss: Node2D
var rig: Node2D
var _pos := {}  # 光點名 → Boss 本地座標
var _lit := {}  # 光點名 → 是否亮著
var _aura := 1.0
var _dim := 1.0
var _order: Array = []  # 熄滅順序（由遠到近）
var _ext_t := -1.0  # < 0＝沒有在熄
var _ext_len := 1.0
var _t := 0.0


static func attach(b: Node2D) -> Node2D:
	var g = new()
	g.name = "MacawGlints"
	g.boss = b
	g.rig = b.get_node("Rig")
	g.material = FxKit.add_material()
	g.process_physics_priority = 1  # 排在 MacawAnimator 之後：用它這一幀擺好的姿勢與顏色
	for n in NAMES:
		g._lit[n] = true
	b.add_child(g)
	g.place()
	return g


## 光點放到骨架目前的光點位置
func place() -> void:
	for n in NAMES:
		_pos[n] = rig.transform * rig.point(n)


func glint_pos(n: String) -> Vector2:
	return _pos[n]


func is_lit(n: String) -> bool:
	return _lit[n]


func lit_count() -> int:
	return NAMES.filter(func(n): return _lit[n]).size()


## 全身假光的強度 0～1
func aura() -> float:
	return _aura


## 在 seconds 秒內由遠到近逐一熄滅（平均分配），結束時發出 extinguished
func extinguish(seconds: float) -> void:
	var chest: Vector2 = rig.to_local(rig.joint_global("hip"))
	_order = NAMES.duplicate()
	_order.sort_custom(func(a, b): return rig.point(a).distance_to(chest) > rig.point(b).distance_to(chest))
	_ext_len = maxf(seconds, 0.001)
	_ext_t = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	place()
	if _ext_t >= 0.0:
		_ext_t += delta
		var k := clampf(_ext_t / _ext_len, 0.0, 1.0)
		for i in _order.size():
			_lit[_order[i]] = (i + 1) > k * _order.size() + 0.0001
		_aura = 1.0 - k
		_dim = lerpf(1.0, DIM, k)
		if k >= 1.0:
			_ext_t = -1.0
			extinguished.emit()
	if _dim < 1.0:  # MacawAnimator 每幀設 rig.modulate：在它之後乘上變暗（同它的顏色規則）
		rig.modulate = Tint.of(boss) * Color(_dim, _dim, _dim)
	queue_redraw()


func _draw() -> void:
	var tex := FxKit.glow_texture(64)
	if _aura > 0.0:
		var body: Rect2 = boss.faced_body().grow(30.0)
		draw_texture_rect(tex, body, false, Color(1, 1, 1, AURA_ALPHA * _aura))
	for i in NAMES.size():
		var n: String = NAMES[i]
		if not _lit[n]:
			continue
		var k := 0.6 + 0.4 * sin(_t * TAU * (0.7 + 0.13 * i) + i * 2.1)  # 各自週期、錯開
		var d := GLINT_D * (0.8 + 0.3 * k)
		var p: Vector2 = _pos[n]
		draw_texture_rect(tex, Rect2(p - Vector2(d, d) / 2.0, Vector2(d, d)), false, Color(1, 1, 1, k))
		var c := Color(FxKit.CORE, k)  # 實心亮點＋十字星芒：疊在金飾上也看得出是光
		draw_circle(p, 2.5, c)
		draw_line(p - Vector2(SPARK * k, 0), p + Vector2(SPARK * k, 0), c, 1.5)
		draw_line(p - Vector2(0, SPARK * k), p + Vector2(0, SPARK * k), c, 1.5)
