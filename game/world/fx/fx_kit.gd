extends RefCounted
# Boss 特效的共用材料（MV-SLICE-001c1 SLICE-c1-1）：預先產生的放射狀光暈貼圖、加亮混合材質、光的顏色。
# 不用 shader；光暈一律畫這張貼圖（draw_texture_rect 縮放），材質共用一份。

const CORE := Color("#fffef4")  # 光暈中心：暖白
const GOLD := Color("#ffe2a0")  # 光暈外圍：金

static var _glows := {}
static var _add: CanvasItemMaterial


## 放射狀光暈：中心 CORE、30% 半透明 GOLD、70% 起透明；依 size 快取
## ponytail: native: GradientTexture2D 放射填色，建立時就轉成 ImageTexture | upgrade if: 要非圓形或雜訊光暈，改用自產 Image
## （GradientTexture2D 若先被畫、再 get_image，headless 會拿到 null：先畫時建的是佔位貼圖）
static func glow_texture(size: int) -> Texture2D:
	if not _glows.has(size):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.7])
		g.colors = PackedColorArray([CORE, Color(GOLD, 0.5), Color(GOLD, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = size
		t.height = size
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		_glows[size] = ImageTexture.create_from_image(t.get_image())
	return _glows[size]


## 加亮混合（共用一份）
static func add_material() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add
