extends Node2D
# 動作展示畫面（MV-SLICE-001b2a，開發版 --rig-view）：兩兄弟並排，依 playlist() 播每個動作，畫面下方顯示角色與動作名；
# MV-SLICE-001b2b1：雙胞胎播完接爬行型、飛行型（遊戲大小與放大 2 倍並排）、Seven Macaw（四種頭依序各播一輪全部動作，
# 黃點＝該頭對應的光源光點：完整頭→下顎、下顎受傷→玉牙、白玉米牙→眼睛、失明→無）。
# MV-SLICE-001b2b2：飛行型之後、Seven Macaw 之前加 NPC（祖母、老伯、老婆婆、老鼠、Chimalmat）每個動作。
# MV-SLICE-001c4c2：飛行型之後加反光型（每個動作＋擋下一震 thud）。
# 彩色一輪播完切灰階再一輪，然後結束程式。按鍵：G 灰階、空白鍵暫停、→ 暫停時前進一格（1/12 秒）。
# 畫在 1920×1080 的 SubViewport：視窗被專案設定（1280×720）與螢幕大小夾住，Movie Writer 只錄得到視窗大小。
# 錄驗收影片：godot --path game -- --rig-view --frames <資料夾> → 以固定 FRAMES_FPS 逐格存 JPG（不看實際時間），
# 再用 ffmpeg 合成（指令見 game/README.md）。

const RigView := preload("res://world/rig_view.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")
const MacawAnimator := preload("res://world/macaw_animator.gd")
const EnemyAnimator := preload("res://world/enemy_animator.gd")
const Macaw := preload("res://core/boss/seven_macaw.gd")
const Player := preload("res://core/player/player.gd")
const Weapons := preload("res://core/player/weapons.gd")
const Scenery := preload("res://world/scenery.gd")
const SIZE := Vector2(1920, 1080)
const FLOOR := 880.0
const ROUNDS := 2
const MACAW_ROUNDS := 1  # Seven Macaw 四種頭各播一輪，已經重複四次
const CHARS := ["twins", "crawler", "flyer", "reflector", "xmucane", "healer_man", "healer_woman", "rat", "chimalmat", "sevenmacaw"]  # 播放順序；twins＝兩兄弟並排
## 角色 → [[x, 腳底（飛行型：整隻的下緣）y, 放大倍數], …]
const PLACES := {
	"crawler": [[760.0, FLOOR, 1.0], [1160.0, FLOOR, 2.0]],
	"flyer": [[760.0, FLOOR - 260.0, 1.0], [1160.0, FLOOR - 260.0, 2.0]],
	"reflector": [[560.0, FLOOR, 1.0], [1200.0, FLOOR, 2.0]],
	"sevenmacaw": [[1160.0, FLOOR, 1.0]],  # 腳底偏右：尾羽往左長
	# MV-SLICE-001b2b2 的 NPC：遊戲大小與放大並排（老鼠只有 40 px，放大 3 倍）
	"xmucane": [[760.0, FLOOR, 1.0], [1160.0, FLOOR, 2.0]],
	"healer_man": [[760.0, FLOOR, 1.0], [1160.0, FLOOR, 2.0]],
	"healer_woman": [[760.0, FLOOR, 1.0], [1160.0, FLOOR, 2.0]],
	"rat": [[760.0, FLOOR, 1.0], [1160.0, FLOOR, 3.0]],
	"chimalmat": [[960.0, FLOOR, 1.0]],
}
const MARK_RADIUS := 6.0
const GAP := 0.4  # 兩個動作之間停在最後一格的時間
const DART_SHOW := 0.3  # 展示一輪只舉 0.3 秒（遊戲裡最後一發後舉 TwinAnimator.DART_TIME）
const FRAMES_FPS := 30
const THUD_SHOW := 0.3  # 反光型擋下一震的展示一輪：前 0.15 秒反光面偏 THUD_DEG（同 enemy_animator），後 0.15 秒回原位
const ORDER := [
	"idle", "run", "jump_up", "fall", "land", "double_jump", "roll", "hurt", "heal", "interact", "swap_in", "tool_cast", "dart",
	"attack_axe_side", "attack_axe_up", "attack_axe_down", "attack_stick_side", "attack_stick_up", "attack_stick_down",
	"parry_side", "parry_up", "parry_success", "ballgear_down",
	"crouch", "walk", "lunge", "knocked_down",  # 過場用（MV-SLICE-001c2a）
	"plant", "grab",  # 地面過場用（MV-SLICE-001c3b）
]
const GRAY_SHADER := """
shader_type canvas_item;
void fragment() {
	COLOR = vec4(vec3(dot(texture(TEXTURE, UV).rgb, vec3(0.299, 0.587, 0.114))), 1.0);
}
"""
const BG_Z := -10  # 同場景遠景：骨架整副在 −9～0（rig_view.gd）

var frames_dir := ""  # 非空＝逐格輸出模式
var viewport: SubViewport
var rigs := {}  # 角色 → 骨架們（twins：兩兄弟）
var marker: Node2D  # Seven Macaw 的光點
var label: Label
var screen: TextureRect
var gray := false
var _gray_mat: ShaderMaterial
var item := 0
var t := 0.0
var pass_no := 0  # 0＝彩色、1＝灰階
var paused := false
var _list: Array


## [{char, anim, secs, head}, …]：雙胞胎每個動作播 ROUNDS 輪（攻擊與招架一輪＝數值表的出招＋判定＋收招，招架＝窗口＋收招）；
## 接著爬行型、飛行型動作檔的每個動作各 ROUNDS 輪；Seven Macaw 依序換四種頭，每種頭播動作檔每個動作 MACAW_ROUNDS 輪。
## Seven Macaw 的分段動作（前搖 0～1、出招 1～2、收招 2～3）在展示畫面每段 1 秒
static func playlist() -> Array:
	var out := []
	for n in ORDER:
		out.append({"char": "twins", "anim": n, "secs": round_length(n) * ROUNDS, "head": ""})
	for c in ["crawler", "flyer", "reflector", "xmucane", "healer_man", "healer_woman", "rat", "chimalmat"]:
		for n in RigView.anims_at(anims_file(c)).anims:
			out.append({"char": c, "anim": n, "secs": anim_length(c, n) * ROUNDS, "head": ""})
		if c == "reflector":
			out.append({"char": c, "anim": "thud", "secs": THUD_SHOW * ROUNDS, "head": ""})
	for h in MacawAnimator.HEADS:
		for n in RigView.anims_at(anims_file("sevenmacaw")).anims:
			out.append({"char": "sevenmacaw", "anim": n, "secs": anim_length("sevenmacaw", n) * MACAW_ROUNDS, "head": h})
	return out


static func anims_file(c: String) -> String:
	return "res://rig/%s_anims.json" % c


## 動作檔裡一個動作一輪的長度：循環動作的 length，否則最後一格再停一格
static func anim_length(c: String, n: String) -> float:
	var data := RigView.anims_at(anims_file(c))
	var a: Dictionary = data.anims[n]
	return a.get("length", a.frames[-1].t + 1.0 / data.fps)


static func round_length(n: String) -> float:
	var tn = Tune.data
	if n.begins_with("parry_side") or n.begins_with("parry_up"):
		return tn.parry_window + tn.parry_recovery
	if n.begins_with("attack_") or n == "ballgear_down":
		var w: Vector3 = Weapons.timing(weapon_for(n), tn)
		return w.x + w.y + w.z
	if n == "dart":
		return DART_SHOW * 2.0
	var a: Dictionary = RigView.anims().anims[n]
	return a.get("length", a.frames[-1].t + 1.0 / RigView.anims().fps)


static func weapon_for(n: String) -> int:
	if n == "grab":  # 握著抓下的尾巴（MV-SLICE-001c3b）：空手
		return -1
	if "stick" in n:
		return Weapons.Weapon.STICK
	if n.begins_with("parry") or n.begins_with("ballgear"):
		return Weapons.Weapon.BALLGEAR
	return Weapons.Weapon.AXE


func _ready() -> void:
	_list = playlist()
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := Node2D.new()
	viewport.add_child(stage)
	screen = TextureRect.new()  # 視窗裡顯示（根視口是 1920×1080 的邏輯座標，由專案的 stretch 縮到視窗）
	screen.texture = viewport.get_texture()
	screen.size = SIZE
	add_child(screen)
	var far := Sprite2D.new()
	far.texture = load(Scenery.BG % Scenery.BOSS.far)
	far.centered = false
	far.scale = Vector2.ONE * maxf(SIZE.x / far.texture.get_width(), SIZE.y / far.texture.get_height())
	far.z_index = BG_Z
	stage.add_child(far)
	var ground := Sprite2D.new()
	ground.texture = load(Scenery.BG % "bg_forest_ground_tile")
	ground.centered = false
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, SIZE.x, ground.texture.get_height())
	ground.position = Vector2(0, FLOOR - Scenery.GROUND_TOP_ROW)
	ground.z_index = BG_Z
	stage.add_child(ground)
	var earth := ColorRect.new()
	earth.color = Scenery.EARTH
	earth.position = Vector2(0, ground.position.y + Scenery.GROUND_BOTTOM_ROW)
	earth.size = SIZE
	earth.z_index = BG_Z
	stage.add_child(earth)
	rigs.twins = []
	for i in TwinAnimator.CHARS.size():
		var r := RigView.new()
		stage.add_child(r)
		r.build(TwinAnimator.CHARS[i])
		r.position = Vector2(SIZE.x / 2.0 + (i * 2 - 1) * 220.0, FLOOR)
		rigs.twins.append(r)
	for c in PLACES:
		rigs[c] = []
		for p in PLACES[c]:
			var r := RigView.new()
			stage.add_child(r)
			r.build(c)
			r.position = Vector2(p[0], p[1])
			r.scale = Vector2(p[2] * r.faces, p[2])  # 面向右（R5：faces −1＝基準圖面向左）
			rigs[c].append(r)
	marker = Node2D.new()
	marker.z_index = 1  # 骨架整副在 −9～0
	marker.draw.connect(func() -> void:
		marker.draw_circle(Vector2.ZERO, MARK_RADIUS + 2.0, Color.BLACK)
		marker.draw_circle(Vector2.ZERO, MARK_RADIUS, Color(1.0, 0.9, 0.2)))
	stage.add_child(marker)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 44)
	label.position = Vector2(80, FLOOR + 90)
	stage.add_child(label)
	_gray_mat = ShaderMaterial.new()
	_gray_mat.shader = Shader.new()
	_gray_mat.shader.code = GRAY_SHADER
	_show()
	if frames_dir != "":
		_dump_frames()


## 逐格輸出：每格固定前進 1/FRAMES_FPS 秒，畫完存 JPG；播完（彩色＋灰階）結束程式
func _dump_frames() -> void:
	set_process(false)
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var i := 0
	while pass_no < 2:
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		if gray:
			img.convert(Image.FORMAT_L8)  # 同 shots.gd 的灰階截圖
		img.save_jpg(frames_dir.path_join("%05d.jpg" % i), 0.92)
		i += 1
		_advance(1.0 / FRAMES_FPS)
	print("RIGVIEW frames=%d fps=%d" % [i, FRAMES_FPS])


func _process(delta: float) -> void:
	if not paused:
		_advance(delta)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_G:
			_set_gray(not gray)
		KEY_SPACE:
			paused = not paused
		KEY_RIGHT:
			if paused:
				_advance(1.0 / RigView.anims().fps)


func _advance(delta: float) -> void:
	t += delta
	if t >= _list[item].secs + GAP:
		t = 0.0
		item += 1
		if item >= _list.size():
			item = 0
			pass_no += 1
			if pass_no >= 2:
				get_tree().quit()
				return
			_set_gray(true)
	_show()


func _set_gray(on: bool) -> void:
	gray = on
	screen.material = _gray_mat if on else null


## 目前的角色、動作與輪內時間 → 骨架的姿勢（只顯示這個角色）
func _show() -> void:
	var it: Dictionary = _list[item]
	for c in rigs:
		for r in rigs[c]:
			r.visible = c == it.char
	marker.visible = false
	label.text = "%s  %s%s%s" % [it.char, it.anim, "  [%s]" % it.head if it.head != "" else "", "  (gray)" if gray else ""]
	if it.char == "twins":
		_show_twins(it.anim, it.secs)
		return
	if it.anim == "thud":  # 反光型擋下一震：待機姿勢＋反光面偏轉
		for r in rigs[it.char]:
			r.pose("idle", 0.0)
			if fmod(t, THUD_SHOW) < THUD_SHOW / 2.0:
				r.bone("mirror").rotation += deg_to_rad(EnemyAnimator.THUD_DEG)
				r._sync()
		return
	var rl := anim_length(it.char, it.anim)
	var s := fmod(t, rl) if t < it.secs else rl - 0.0001  # 停頓時停在最後一格
	for r in rigs[it.char]:
		r.pose(it.anim, s)
	if it.char == "sevenmacaw":
		var r: Node2D = rigs.sevenmacaw[0]
		var k := MacawAnimator.HEADS.find(it.head)
		for h in MacawAnimator.HEADS:
			r.sprite(h).visible = h == it.head
		if k < Macaw.LIGHT_NAMES.size():  # 失明的頭：三個光源都拿掉了
			marker.position = r.transform * r.point(Macaw.LIGHT_NAMES[k])
			marker.visible = true


func _show_twins(n: String, secs: float) -> void:
	var rl := round_length(n)
	var s := fmod(t, rl) if t < secs else rl - 0.0001  # 停頓時停在最後一格
	var anim := "idle" if n == "dart" else n
	var at := s
	if n.begins_with("attack_") or n == "ballgear_down" or n.begins_with("parry_side") or n.begins_with("parry_up"):
		var state := Player.State.PARRY if n.begins_with("parry") else Player.State.ATTACK
		at = TwinAnimator.attack_time({"state": state, "state_time": s, "tn": Tune.data, "attack_weapon": weapon_for(n)})
	for r in rigs.twins:
		r.set_weapon(weapon_for(n))
		r.pose(anim, at)
		r.show_attachment("prop_soup_bowl", n == "heal")
		r.show_attachment("wpn_blowgun", false)
		if n == "dart" and s < DART_SHOW:
			r.overlay_dart(Vector2.RIGHT)
