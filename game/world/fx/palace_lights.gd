extends Node2D
# 宮殿的假光（MV-SLICE-001c1「宮殿假光分 3 組熄」）：牆上金飾、寶座各有加亮光暈，各自輕微閃爍。
# lights_removed 每加 1 熄掉一組：段落進行中拔掉光源＝0.8 秒淡出；開打、重試、讀檔直接對應。
# 掛在 scenery_view 底下（跟著場景暗度）；篝火在 world、不受影響。

const FxKit := preload("res://world/fx/fx_kit.gd")

## 3 組光暈位置（世界座標）：量自 bg_palace_back_01.png（錨在 x 14000、y −61）的金色像素與 prop_palace_throne.png 的寶石
const GROUPS := [
	[Vector2(14188, 291), Vector2(14188, 479), Vector2(14660, 119)],  # 左柱金箍、左樑金飾
	[Vector2(15064, 291), Vector2(15064, 479), Vector2(15240, 119)],  # 中柱金箍、中樑金飾
	[Vector2(15784, 291), Vector2(15660, 510), Vector2(15568, 545)],  # 右柱金箍、寶座寶石
]
const FADE := 0.8
const SIZE := 70.0  # 光暈直徑

var alpha := PackedFloat32Array([1.0, 1.0, 1.0])  # 每組目前的亮度
var _removed := 0
var _t := 0.0


func _ready() -> void:
	material = FxKit.add_material()


## 拔掉 removed 個光源：前 removed 組熄；animate 時淡出，否則直接設定
func set_level(removed: int, animate: bool) -> void:
	_removed = clampi(removed, 0, GROUPS.size())
	for g in GROUPS.size():
		if g >= _removed:
			alpha[g] = 1.0
		elif not animate:
			alpha[g] = 0.0
	queue_redraw()


## 亮著的組數（淡出中的算熄了）
func lit_groups() -> int:
	return GROUPS.size() - _removed


func _process(delta: float) -> void:
	_t += delta
	for g in _removed:
		alpha[g] = maxf(0.0, alpha[g] - delta / FADE)
	queue_redraw()


func _draw() -> void:
	var tex := FxKit.glow_texture(64)
	for g in GROUPS.size():
		if alpha[g] <= 0.0:
			continue
		for i in GROUPS[g].size():
			var k := 0.8 + 0.2 * sin(_t * TAU * (0.6 + 0.17 * (g * 3 + i)) + i * 1.7)  # 各自週期的輕微閃爍
			var d := SIZE * (0.9 + 0.1 * k)
			draw_texture_rect(tex, Rect2(GROUPS[g][i] - Vector2(d, d) / 2.0, Vector2(d, d)), false, Color(1, 1, 1, alpha[g] * k))
