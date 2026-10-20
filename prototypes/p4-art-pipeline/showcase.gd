extends Node2D
# 展示畫面（PROTO4-3）：MV-PROTO-001 戰鬥房配色、每位角色三個 180 px 小人（待機／跑／斧頭側攻）、
# 假光造物灰盒與前搖訊號、右側每位角色一個 450 px 放大預覽；一致性對照畫面：每位角色的基準圖、組好的站姿、兩者疊合。
# MV-ASSET-010 起支援兩兄弟（Rig.CHARS）；對照表或場景還沒產生的角色跳過。
# 操作：1／2／3 預覽切換動作、T 平滑內插、G 灰階、Tab 切換畫面、F12 截圖到 user://shots

const Rig := preload("res://rig/rig.gd")
const Anims := preload("res://rig/anims.gd")
const SCENE_PATH := "res://hunahpu.tscn"
const TARGET_HEIGHT := 180.0
const PREVIEW_HEIGHT := 450.0
const COMPARE_HEIGHT := 520.0
const GROUND_Y := 900.0
const GROUND := Color(0.22, 0.27, 0.25)
const GOLD := Color(0.95, 0.8, 0.35)
const SAW := Color(0.35, 0.1, 0.45)
const CAPTURE_SIZE := Vector2i(1920, 1080)  # 畫面基準；預設視窗 1280×720 時角色只有約 120 px
const AXE_REPLAY := 1.0  # 斧頭側攻不循環，每秒重播一次
const GRAY_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(vec3(dot(c, vec3(0.299, 0.587, 0.114))), 1.0);
}
"""

var rig  # 第一位角色的對照表（相容舊測試）
var rigs := {}  # 角色 → 對照表
var scenes := {}  # 角色 → PackedScene
var heroes: Array = []
var preview: Node2D  # 第一位角色的放大預覽（相容舊測試）
var previews: Array = []
var showcase_view := Node2D.new()
var consistency_view := Node2D.new()
var gray: ColorRect
var smooth := false
var _axe_time := 0.0


func _ready() -> void:
	for c in Rig.CHARS:
		var r := Rig.new()
		if r.load_file(Rig.path_for(c)) != OK or not ResourceLoader.exists("res://%s.tscn" % c):
			continue
		rigs[c] = r
		scenes[c] = load("res://%s.tscn" % c)
	rig = rigs.values()[0]
	add_child(showcase_view)
	add_child(consistency_view)
	consistency_view.visible = false
	_build_showcase()
	_build_consistency()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	gray = ColorRect.new()
	gray.set_anchors_preset(Control.PRESET_FULL_RECT)
	gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	mat.shader = sh
	gray.material = mat
	gray.visible = false
	layer.add_child(gray)


func _build_showcase() -> void:
	var ground := ColorRect.new()
	ground.color = GROUND
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(1920, 1080 - GROUND_Y)
	showcase_view.add_child(ground)
	var names := ["idle", "run", "axe_side"]
	var ci := 0
	for c in rigs:
		var r = rigs[c]
		var k: float = TARGET_HEIGHT / r.body_height()
		for i in 3:
			var h: Node2D = scenes[c].instantiate()
			h.scale = Vector2(k, k)
			h.position = Vector2(170 + ci * 540 + i * 170, GROUND_Y)
			showcase_view.add_child(h)
			h.get_node("Anim").play(names[i])
			heroes.append(h)
		var p: Node2D = scenes[c].instantiate()
		var kp: float = PREVIEW_HEIGHT / r.body_height()
		p.scale = Vector2(kp, kp)
		p.position = Vector2(1500 + ci * 260, GROUND_Y)
		showcase_view.add_child(p)
		p.get_node("Anim").play("idle")
		previews.append(p)
		ci += 1
	preview = previews[0]
	# 假光造物灰盒：爬行型（白色圓形＝可招架）、飛行型（暗紫鋸齒＝不可招架）
	_box(Vector2(1110, GROUND_Y - 70), Vector2(110, 70))
	_circle(Vector2(1165, GROUND_Y - 120), 24.0)
	_box(Vector2(1260, GROUND_Y - 330), Vector2(90, 60))
	_saw(Vector2(1305, GROUND_Y - 380))


func _build_consistency() -> void:
	var base_y := 900.0
	var ci := 0
	for c in rigs:
		var r = rigs[c]
		var k: float = COMPARE_HEIGHT / r.body_height()
		var g: Vector2 = r.ground()
		var ref_tex: Texture2D = load("res://art/chr_%s_reference.png" % c)
		for i in 3:
			var x := 200.0 + ci * 900.0 + i * 280.0
			if i != 1:  # 左：基準圖；右：基準圖半透明＋組好的角色疊合
				var ref := Sprite2D.new()
				ref.texture = ref_tex
				ref.centered = false
				ref.scale = Vector2(k, k)
				ref.position = Vector2(x, base_y) - g * k
				ref.modulate.a = 1.0 if i == 0 else 0.45
				consistency_view.add_child(ref)
			if i != 0:  # 中：組好的站姿（不播動作）
				var h: Node2D = scenes[c].instantiate()
				h.scale = Vector2(k, k)
				h.position = Vector2(x, base_y)
				consistency_view.add_child(h)
		ci += 1


func _box(at: Vector2, size: Vector2) -> void:
	var r := ColorRect.new()
	r.color = GOLD
	r.position = at
	r.size = size
	showcase_view.add_child(r)


func _circle(at: Vector2, radius: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(at + Vector2.from_angle(TAU * i / 24.0) * radius)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = Color(1, 1, 1, 0.95)
	showcase_view.add_child(p)


func _saw(at: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(at + Vector2.from_angle(TAU * i / 12.0) * (32.0 if i % 2 == 0 else 14.0))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = SAW
	showcase_view.add_child(p)


func _process(delta: float) -> void:
	_axe_time += delta
	if _axe_time >= AXE_REPLAY:
		_axe_time = 0.0
		for h in heroes + previews:
			var ap: AnimationPlayer = h.get_node("Anim")
			if ap.current_animation == "axe_side" or (ap.assigned_animation == "axe_side" and not ap.is_playing()):
				ap.stop()
				ap.play("axe_side")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1:
			preview_play("idle")
		KEY_2:
			preview_play("run")
		KEY_3:
			preview_play("axe_side")
		KEY_T:
			toggle_smooth()
		KEY_G:
			toggle_gray()
		KEY_TAB:
			set_view("consistency" if showcase_view.visible else "showcase")
		KEY_F12:
			var stamp := Time.get_datetime_string_from_system().replace(":", "")
			await capture_image("user://shots/%s.png" % stamp)


func preview_play(name: String) -> void:
	for p in previews:
		var ap: AnimationPlayer = p.get_node("Anim")
		ap.stop()
		ap.play(name)


func toggle_gray() -> void:
	gray.visible = not gray.visible


func toggle_smooth() -> void:
	smooth = not smooth
	for i in range(0, heroes.size(), 3):  # 同一角色的實例共用同一份動作資源；每位角色切一次
		Anims.set_smooth(heroes[i].get_node("Anim"), smooth)


func set_view(name: String) -> void:
	showcase_view.visible = name == "showcase"
	consistency_view.visible = name == "consistency"


## 截圖用：視窗設成 1920×1080（角色才是 180 px），動作停在有代表性的影格（跑步跨步、斧頭揮到判定）
func freeze_for_capture() -> void:
	get_window().size = CAPTURE_SIZE
	set_process(false)
	var times := {"idle": 0.25, "run": 1.0 / 12.0, "axe_side": 0.07}
	for h in heroes + previews:
		var ap: AnimationPlayer = h.get_node("Anim")
		var name := ap.assigned_animation
		ap.seek(times[name], true)
		ap.pause()


func capture_image(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s err=%d" % [path, err])
