extends Control
# 覺醒的閃回布景（MV-SLICE-001c2c，SLICE-c2c-5～7）：開墾田地的一角（遠景、田地中景、地面、2 叢灌木、2 個土塊），
# 斧頭自己砍倒灌木、掘棒自己翻開土塊（原典 p.134）。整個布景暖褐單色（根節點的 shader，子節點共用）＋四周暈邊。
# 由覺醒演出用 cs.show_layer() 蓋在畫面上，畫面座標 1920×1080。

const BG := "res://art/bg/%s.png"
const PROP := "res://art/prop/%s.png"
const SCREEN := Vector2(1920, 1080)
const GROUND_Y := 900.0  # 地面線（同遊戲裡的地面）
const BUSH_X := [760.0, 1180.0]
const CLOD_X := [960.0, 1380.0]
const DARK := Color(0.20, 0.13, 0.07)  # 暖褐單色：最暗
const LIGHT := Color(1.0, 0.89, 0.68)  # 最亮（米白）
const VIGNETTE := 0.5  # 暈邊最外圈的黑
const PROP_SCALE := 2.0  # 灌木、土塊（田地裡是近景，閃回拉近）
const TOOL_SCALE := 3.0  # 斧頭、掘棒
const SEPIA := """
shader_type canvas_item;
uniform vec4 dark : source_color;
uniform vec4 light : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(dark.rgb, light.rgb, smoothstep(0.0, 0.6, g)), c.a);
}
"""

var bushes: Array = []
var clods: Array = []
var axe: TextureRect
var stick: TextureRect


static func make() -> Control:
	var fb = new()
	fb.set_anchors_preset(Control.PRESET_FULL_RECT)
	fb.size = SCREEN
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SEPIA
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("dark", DARK)
	m.set_shader_parameter("light", LIGHT)
	fb.material = m
	var sky := ColorRect.new()  # 遠景透明處的底色
	sky.color = Color(0.75, 0.82, 0.9)
	sky.size = SCREEN
	fb._add(sky)
	for k in ["bg_forest_far_01", "bg_field_mid_01"]:
		var t := fb._tex(load(BG % k))
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.size = SCREEN
	var ground := fb._tex(load(BG % "bg_forest_ground_tile"))
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(SCREEN.x, SCREEN.y - GROUND_Y)
	for x in BUSH_X:
		fb.bushes.append(fb._on_ground(load(PROP % "prop_field_bush"), x))
	for x in CLOD_X:
		fb.clods.append(fb._on_ground(load(PROP % "prop_field_clod"), x))
	fb.axe = fb._tex(load(PROP % "wpn_axe"), TOOL_SCALE)
	fb.axe.pivot_offset = Vector2(10, 40) * TOOL_SCALE  # 握柄末端
	fb.stick = fb._tex(load(PROP % "wpn_digging_stick"), TOOL_SCALE)
	fb.stick.pivot_offset = fb.stick.size / 2.0
	fb.stick.rotation = PI / 2.0  # 直立往下戳
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, VIGNETTE)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	var vig := TextureRect.new()
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.size = SCREEN
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.add_child(vig)
	return fb


func _add(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.use_parent_material = true
	add_child(c)


func _tex(t: Texture2D, k := 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = t.get_size() * k
	_add(r)
	return r


## 底部中央站在地面線上
func _on_ground(t: Texture2D, x: float) -> TextureRect:
	var r := _tex(t, PROP_SCALE)
	r.position = Vector2(x - r.size.x / 2.0, GROUND_Y - r.size.y + 8.0 * PROP_SCALE)
	r.pivot_offset = Vector2(r.size.x / 2.0, r.size.y)
	return r


## 斧頭與掘棒同時工作（約 2.2 秒）
func play(cs) -> void:
	await cs.together([_chop.bind(cs), _dig.bind(cs)])


## 斧頭飛到灌木上方，自己砍三下，灌木傾倒淡出
func _chop(cs) -> void:
	var bush: TextureRect = bushes[0]
	var to := bush.position + Vector2(bush.size.x * 0.55, -20.0)
	var from := Vector2(to.x - 500.0, -100.0)
	await cs.animate(0.5, func(k: float) -> void: axe.position = from.lerp(to, k))
	for i in 3:
		await cs.animate(0.35, func(k: float) -> void:
			axe.rotation = lerpf(-0.9, 0.5, sin(k * PI))
			bush.rotation = 0.06 * sin(k * PI))
	await cs.animate(0.6, func(k: float) -> void:
		bush.rotation = 1.2 * k
		bush.modulate.a = 1.0 - k)


## 掘棒飛到土塊上方，自己戳三下，土塊縮小散開
func _dig(cs) -> void:
	var clod: TextureRect = clods[0]
	var to := clod.position + Vector2(clod.size.x / 2.0 - stick.size.x / 2.0, -stick.size.x / 2.0 + 10.0)  # 直立後下端碰到土塊
	var from := Vector2(to.x + 500.0, -100.0)
	await cs.animate(0.5, func(k: float) -> void: stick.position = from.lerp(to, k))
	for i in 3:
		await cs.animate(0.35, func(k: float) -> void: stick.position.y = to.y - 60.0 * sin(k * PI))
	await cs.animate(0.6, func(k: float) -> void:
		clod.scale = Vector2.ONE * lerpf(1.0, 0.3, k)
		clod.modulate.a = 1.0 - k)
