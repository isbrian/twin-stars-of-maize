extends Node2D
# PROTO-001 探路用原型，可丟棄。
# 要回答的問題：玩家能不能只靠聲音＋聲紋，分辨五類聲音語彙（活物、真實、虛假、危險、殘響）？
# 使用者參數（放在 -- 之後）：
#   --demo-listen      強制聆聽，供截圖驗證
#   --export-wav DIR   把五類佔位音效存成 WAV 後結束
#   --self-test        用程式模擬作答，驗證答題與計分邏輯後結束

const SoundBank := preload("res://sound_bank.gd")
const SourceScript := preload("res://source.gd")
const PlayerScript := preload("res://player.gd")

const KINDS := ["alive", "real", "fake", "danger", "echo"]
const LABELS := {"alive": "活物", "real": "真實", "fake": "虛假", "danger": "危險", "echo": "殘響"}
const SOURCE_XS := [420.0, 720.0, 1020.0, 1320.0, 1620.0]
const FLOOR_Y := 600.0
const ANSWER_RANGE := 110.0
const FOCUS_RANGE := 120.0  # 站在方塊前的判定距離
const FOCUS_OTHERS := 0.2  # 專注時其他方塊的音量（約 -14 dB）
const FOCUS_NONE := 0.5  # 沒站在任何方塊前時，全部的音量

var bank := {}
var player: CharacterBody2D
var cam: Camera2D
var sources: Array = []
var overlay_mat: ShaderMaterial
var hud: Label
var muted := false
var round_no := 0
var stats := {false: [0, 0], true: [0, 0]}  # muted -> [答對, 作答]
var last_result := ""
var desat := 0.0  # 聆聽時的去色程度 0～1

const DESAT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g) * 0.55, amount), 1.0);  // 聲紋在更上層，不受影響
}
"""


func _ready() -> void:
	bank = SoundBank.build_all()
	var args := OS.get_cmdline_user_args()
	var export_idx := args.find("--export-wav")
	if export_idx != -1 and export_idx + 1 < args.size():
		_export_wavs(args[export_idx + 1])
		get_tree().quit()
		return
	_setup_input()
	_build_level()
	_build_ui()
	_new_round()
	if "--self-test" in args:
		_self_test()
		get_tree().quit()
		return
	if "--demo-listen" in args:
		player.force_listen = true
		player.position.x = SOURCE_XS[2]  # 站在中間，五個方塊都在畫面內
		for i in sources.size():  # 截圖用固定順序：活物、真實、虛假、危險、殘響
			sources[i].set_kind(KINDS[i], bank[KINDS[i]])


func _export_wavs(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for kind in bank:
		var path := dir.path_join("p1_%s.wav" % kind)
		var err: Error = bank[kind].save_to_wav(path)
		print("EXPORT %s %s" % [path, "ok" if err == OK else "error %d" % err])


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE])
	_add_action("listen", [KEY_F])
	_add_action("toggle_mute", [KEY_M])
	_add_action("new_round", [KEY_R])
	for i in 5:
		_add_action("guess_%d" % (i + 1), [KEY_1 + i])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _build_level() -> void:
	RenderingServer.set_default_clear_color(Color(0.12, 0.14, 0.18))
	_add_block(Vector2(1020, FLOOR_Y + 20), Vector2(2400, 40))  # 地板
	_add_block(Vector2(-160, 400), Vector2(40, 480))  # 左牆
	_add_block(Vector2(2200, 400), Vector2(40, 480))  # 右牆
	for x in SOURCE_XS:
		var s: Node2D = SourceScript.new()
		s.position = Vector2(x, FLOOR_Y)
		add_child(s)
		sources.append(s)
	player = PlayerScript.new()
	player.position = Vector2(100, FLOOR_Y - 1)
	add_child(player)
	cam = Camera2D.new()
	player.add_child(cam)
	cam.make_current()


func _add_block(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.color = Color(0.3, 0.3, 0.33)
	vis.size = size
	vis.position = -size / 2.0
	body.add_child(vis)
	add_child(body)


func _build_ui() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 1
	add_child(overlay_layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = DESAT_SHADER
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = shader
	overlay.material = overlay_mat
	overlay_layer.add_child(overlay)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 3
	add_child(hud_layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang TC", "Noto Sans CJK TC", "Heiti TC"])
	hud.add_theme_font_override("font", font)
	hud.add_theme_font_size_override("font_size", 18)
	hud_layer.add_child(hud)


func _new_round() -> void:
	round_no += 1
	var kinds := KINDS.duplicate()
	kinds.shuffle()
	for i in sources.size():
		sources[i].set_kind(kinds[i], bank[kinds[i]])
	last_result = ""


func _process(delta: float) -> void:
	var listening: bool = player.listening
	for s in sources:
		s.listening = listening
		s.muted = muted
		s.proximity = 1.0 - clampf(absf(s.position.x - player.position.x) / 600.0, 0.0, 1.0)
	_update_focus()
	var target_zoom := 0.8 if listening else 1.0
	cam.zoom = cam.zoom.lerp(Vector2(target_zoom, target_zoom), clampf(delta * 5.0, 0.0, 1.0))
	desat = move_toward(desat, 1.0 if listening else 0.0, delta * 4.0)
	overlay_mat.set_shader_parameter("amount", desat)

	if Input.is_action_just_pressed("toggle_mute"):
		muted = not muted
	if Input.is_action_just_pressed("new_round"):
		_new_round()
	for i in 5:
		if Input.is_action_just_pressed("guess_%d" % (i + 1)):
			_guess(KINDS[i])
	_update_hud()


func _update_focus() -> void:
	var nearest: Node2D = null
	var best := FOCUS_RANGE
	for s in sources:
		var d := absf(s.position.x - player.position.x)
		if d <= best:
			best = d
			nearest = s
	for s in sources:
		if nearest == null:
			s.focus = FOCUS_NONE
		else:
			s.focus = 1.0 if s == nearest else FOCUS_OTHERS


func _guess(guess: String) -> void:
	var target: Node2D = null
	for s in sources:
		if not s.answered and absf(s.position.x - player.position.x) <= ANSWER_RANGE:
			target = s
	if target == null:
		return
	target.answered = true
	var ok: bool = target.kind == guess
	stats[muted][1] += 1
	if ok:
		stats[muted][0] += 1
	print("ANSWER round=%d muted=%s actual=%s guess=%s correct=%s" % [round_no, muted, target.kind, guess, ok])
	if sources.all(func(s): return s.answered):
		var lines := PackedStringArray()
		for s in sources:
			lines.append(LABELS[s.kind])
		last_result = "本輪正解（左到右）：" + " / ".join(lines) + "　按 R 開新一輪"


func _update_hud() -> void:
	var done := sources.filter(func(s): return s.answered).size()
	hud.text = "A/D 移動　Space 跳躍　按住 F 聆聽　M 靜音模式（只看聲紋）　R 新一輪\n" \
		+ "站到方塊前按 1 活物／2 真實／3 虛假／4 危險／5 殘響 作答\n" \
		+ "第 %d 輪　已作答 %d/5　靜音模式：%s\n" % [round_no, done, "開" if muted else "關"] \
		+ "有聲音：%s　只看聲紋：%s\n" % [_rate(stats[false]), _rate(stats[true])] \
		+ last_result


func _rate(pair: Array) -> String:
	if pair[1] == 0:
		return "—"
	return "%d/%d（%d%%）" % [pair[0], pair[1], roundi(100.0 * pair[0] / pair[1])]


func _self_test() -> void:
	# 第 1 輪（有聲音）：全部答對；第 2 輪（靜音）：全部答成「活物」
	for s in sources:
		player.position.x = s.position.x
		_guess(s.kind)
	print("SELFTEST round1 done=%s result=%s" % [sources.all(func(x): return x.answered), last_result])
	for probe_x in [SOURCE_XS[2], (SOURCE_XS[1] + SOURCE_XS[2]) / 2.0]:
		player.position.x = probe_x
		_update_focus()
		print("SELFTEST focus at x=%d: %s" % [probe_x, ", ".join(sources.map(func(x): return "%.1f" % x.focus))])
	_new_round()
	muted = true
	for s in sources:
		player.position.x = s.position.x
		_guess("alive")
	player.position.x = -100.0  # 範圍外作答應被忽略
	_guess("real")
	print("SELFTEST sound=%s muted=%s" % [_rate(stats[false]), _rate(stats[true])])
