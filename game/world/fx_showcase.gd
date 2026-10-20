extends Node2D
# Boss 特效展示畫面（MV-SLICE-001c1，開發版 --fx-view）：宮殿與 nance 場景圖層＋Seven Macaw 骨架＋world/fx/ 的各特效，
# 依 playlist() 直接設定狀態播放（Boss 不跑 AI：物理處理關掉，招式步驟與時間由這裡設），畫面下方顯示項目名。
# 彩色一輪播完切灰階再一輪，然後結束程式。按鍵：G 灰階、空白鍵暫停。
# 畫在 1920×1080 的 SubViewport（同 rig_showcase.gd）。
# 錄驗收影片：godot --path game --fixed-fps 30 -- --fx-view --frames <資料夾> → 每格存 JPG；
# --fixed-fps 讓每格固定前進 1/30 秒，特效自己的動畫（呼吸、閃爍、淡出、熄滅）在影片裡也是實際速度。

const RigShowcase := preload("res://world/rig_showcase.gd")
const SceneryView := preload("res://world/scenery_view.gd")
const MacawAnimator := preload("res://world/macaw_animator.gd")
const Macaw := preload("res://core/boss/seven_macaw.gd")
const Light := preload("res://core/boss/light_source.gd")
const Pillar := preload("res://core/boss/pillar.gd")
const FalseFlash := preload("res://core/boss/moves/false_flash.gd")
const Beam := preload("res://core/boss/moves/beam.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const Whiteout := preload("res://ui/whiteout.gd")
const LightFx := preload("res://world/fx/light_fx.gd")
const PillarFx := preload("res://world/fx/pillar_fx.gd")
const BeamFx := preload("res://world/fx/beam_fx.gd")
const FlashFx := preload("res://world/fx/flash_fx.gd")
const WhiteoutFx := preload("res://world/fx/whiteout_fx.gd")
const MacawGlints := preload("res://world/fx/macaw_glints.gd")

const SIZE := Vector2(1920, 1080)
const LEVEL_SECS := 1.2  # 場地變暗：每一階停留
const CLOSE_ZOOM := 1.6  # 身上光點與熄滅：拉近
const EXTINGUISH_SECS := 1.5

var frames_dir := ""  # 非空＝逐格輸出模式
var viewport: SubViewport
var screen: TextureRect
var camera: Camera2D
var scenery: Node2D
var boss: Node2D
var glints: Node2D
var whiteout: Control
var label: Label
var gray := false
var paused := false
var item := 0
var t := 0.0
var pass_no := 0  # 0＝彩色、1＝灰階
var _gray_mat: ShaderMaterial
var _list: Array
var _pillars: Array = []
var _level := -1


## [{name, secs}, …]：光源三種狀態、假光閃耀（前搖＋白茫）、反光柱兩輪、光束、場地三次變暗、身上光點、熄滅
static func playlist() -> Array:
	var tn = Tune.data
	return [
		{"name": "light_off", "secs": 2.0},
		{"name": "light_glow", "secs": 2.5},
		{"name": "light_bright", "secs": 2.5},
		{"name": "flash", "secs": tn.flash_telegraph + tn.whiteout_in + tn.whiteout_hold + tn.whiteout_out + 0.5},
		{"name": "pillars", "secs": (tn.pillar_warn + tn.pillar_active) * 2.0 + 0.4},
		{"name": "beam", "secs": tn.beam_charge + tn.beam_active + 0.8},
		{"name": "palace_dark", "secs": LEVEL_SECS * 4.0 + 0.4},
		{"name": "glints", "secs": 3.0},
		{"name": "extinguish", "secs": EXTINGUISH_SECS + 1.0},
	]


func _ready() -> void:
	_list = playlist()
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	screen = TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.size = SIZE
	add_child(screen)
	scenery = SceneryView.new()
	viewport.add_child(scenery)
	scenery.build_boss()
	boss = Macaw.new()
	viewport.add_child(boss)
	boss.set_physics_process(false)  # 不跑 AI：狀態由 _show 設
	MacawAnimator.attach(boss)  # 掛法同 boss_fight 的遊戲模式
	glints = MacawGlints.attach(boss)
	LightFx.attach(boss.light)
	BeamFx.attach(boss)
	FlashFx.attach(boss)
	boss.fx_drawn = true
	camera = Camera2D.new()
	viewport.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	viewport.add_child(ui)
	whiteout = Whiteout.new()
	whiteout.set_process(false)  # 時間由 _show 設
	whiteout.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(whiteout)
	WhiteoutFx.attach(whiteout, boss)
	var top := CanvasLayer.new()
	top.layer = 2
	viewport.add_child(top)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = Vector2(80, SIZE.y - 100)
	top.add_child(label)
	_gray_mat = ShaderMaterial.new()
	_gray_mat.shader = Shader.new()
	_gray_mat.shader.code = RigShowcase.GRAY_SHADER
	_enter()
	if frames_dir != "":
		_dump_frames()


## 逐格輸出：每畫完一格存 JPG，播完（彩色＋灰階）結束程式
func _dump_frames() -> void:
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var i := 0
	while pass_no < 2:
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		if gray:
			img.convert(Image.FORMAT_L8)  # 同 shots.gd 的灰階截圖
		img.save_jpg(frames_dir.path_join("%05d.jpg" % i), 0.92)
		i += 1
	print("FXVIEW frames=%d" % i)


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


func _advance(delta: float) -> void:
	t += delta
	if t >= _list[item].secs:
		t = 0.0
		item += 1
		if item >= _list.size():
			item = 0
			pass_no += 1
			if pass_no >= 2:
				get_tree().quit()
				return
			_set_gray(true)
		_enter()
	_show()


func _set_gray(on: bool) -> void:
	gray = on
	screen.material = _gray_mat if on else null


## 進入一個項目：清掉上一項留下的東西，擺好場景與 Boss
func _enter() -> void:
	var it: Dictionary = _list[item]
	for pl in _pillars:
		pl.queue_free()
	_pillars.clear()
	whiteout.t = -1.0
	_level = -1
	scenery.set_darkness(0)
	boss.set_appearance(0)
	_stop_move()
	if it.name == "light_off":  # 每一輪重新點亮身上光點（上一輪最後熄掉了）
		glints.free()
		glints = MacawGlints.attach(boss)
	var phase: int = {"flash": 1, "beam": 3, "glints": 3, "extinguish": 3}.get(it.name, 2)
	boss.park(phase)
	boss.facing = -1
	camera.zoom = Vector2.ONE
	camera.position = (Nance.VIEW if phase == 1 else Palace.VIEW).get_center()
	match it.name:
		"light_glow":
			boss.light.set_state(Light.State.GLOW)
		"light_bright":
			boss.light.set_state(Light.State.BRIGHT)
		"flash":  # 停在樹冠（遊戲裡的位置）：身體大半在畫面上緣外，聚光中心由 FlashFx 移進畫面
			_set_move("false_flash", FalseFlash.Step.TELEGRAPH)
		"pillars":
			for x in Palace.pillar_xs(boss.tn.pillar_count, Palace.LEFT + 400.0):
				var pl := Pillar.new()
				pl.tn = boss.tn
				pl.position = Vector2(x, Palace.GROUND_Y)
				viewport.add_child(pl)
				pl.set_physics_process(false)  # 時間由 _show 設
				PillarFx.attach(pl)
				_pillars.append(pl)
		"beam":
			_set_move("beam", Beam.Step.CHARGE)
			boss.move.begin()
		"glints", "extinguish":
			camera.zoom = Vector2.ONE * CLOSE_ZOOM
			camera.position = boss.position + boss.faced_body().get_center()
			if it.name == "extinguish":
				glints.extinguish(EXTINGUISH_SECS)
	camera.force_update_scroll()
	scenery.update(camera.position.x * camera.zoom.x - SIZE.x / 2.0)  # 場景圖層這一格就跟上鏡頭（不等它自己的 _process）
	label.text = "%s%s" % [it.name, "  (gray)" if gray else ""]


## 目前項目的時間 t → 招式步驟、白茫、光柱、場地暗度
func _show() -> void:
	var tn = boss.tn
	match _list[item].name:
		"flash":
			if t < tn.flash_telegraph:
				boss.move.t = t
			else:
				_stop_move()
				whiteout.t = t - tn.flash_telegraph
		"pillars":
			for pl in _pillars:
				pl.t = fmod(t, tn.pillar_warn + tn.pillar_active)
		"beam":
			if t < tn.beam_charge:
				boss.move.t = t
			elif t < tn.beam_charge + tn.beam_active:
				if boss.move.step != Beam.Step.FIRE:
					boss.light.set_state(Light.State.OFF)
					boss.move.go(Beam.Step.FIRE)
				boss.move.t = t - tn.beam_charge
			else:
				_stop_move()
		"palace_dark":
			var lv := mini(int(t / LEVEL_SECS), 3)
			if lv != _level:
				scenery.set_darkness(lv, _level >= 0)  # 段落進行中拔掉光源：假光淡出
				boss.set_appearance(lv)
				_level = lv


func _set_move(mv: String, step: int) -> void:
	var m = Macaw.MOVES[mv].new()
	m.boss = boss
	m.step = step
	boss.move = m
	boss.move_name = mv
	boss.state = Macaw.State.MOVE


func _stop_move() -> void:
	boss.move = null
	boss.move_name = ""
	boss.state = Macaw.State.DOWN
	boss.light.set_state(Light.State.OFF)
