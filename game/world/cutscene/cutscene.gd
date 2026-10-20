extends Node2D
# 過場執行器（MV-SLICE-001c2a，SLICE-c2-3～7、17）：Boss 戰遊戲模式的子節點。
# run(演出腳本們)：黑邊滑入、HUD 淡出、凍結戰場（場景照常處理：視差、NPC）、換成自己的鏡頭 → 依序 play → 每段 end_state → 反向還原。
# 演出腳本（duck typing）：play(cs) 依序 await 下面的指令；end_state(host) 設定演出後的遊戲狀態，看完與跳過都會呼叫。
# 跳過：按住暫停鍵 1 秒（右下角的圈填滿）→ skipped，之後每個指令立刻 return；演出中暫停選單不開（看群組 GROUP）。
# 演出腳本宣告 skip_stop := true 時，跳過停在它的開頭（放開暫停鍵後才能再跳過；c2c）；前面被跳過的段落若有 settle(cs)，先把替身與場景擺到它的最後樣子。
# 計時用自己的 _process 累加，測試可用 Engine.time_scale 加速。

const MenuInput := preload("res://ui/menu_input.gd")
const Actor := preload("res://world/cutscene/actor.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")

const BAR_FRAC := 0.11  # 上下黑邊各佔畫面高
const BAR_TIME := 0.4
const SKIP_HOLD := 1.0
const MIN_LINE := 0.3  # 攻擊鍵提前換句前，每句至少顯示
const GROUP := &"cutscene"
const NAME_COLOR := "#ffd98a"
const FONT_SIZE := 38
const RING_R := 22.0
const SIL_TOP := Color("#faaa5a")  # 逆光剪影的漸層底（SLICE-c2-4）
const SIL_BOTTOM := Color("#f0e6aa")
const WALK_SPEED := 300.0

var host  # 舞台（duck typing：player、boss、world、scenery、camera、hud；boss／scenery／hud 可為 null）：BossFight 或地面的 GroundStage（MV-SLICE-001c3a）；null＝只有 UI（測試）
var skipped := false
var running := false
var subtitle: RichTextLabel
var title_label: Label
var epithet_label: Label
var camera: Camera2D

var _t := 0.0
var _bar_k := 0.0  # 黑邊 0～1
var _bar_target := 0.0
var _hold := 0.0
var _line_t0 := -1.0  # 目前這句開始的時間；< 0＝沒有字幕
var _advance := false  # 這句顯示滿 MIN_LINE 後按了攻擊鍵
var _ui: CanvasLayer
var _bars: Array = []
var _ring: Control
var _fade: ColorRect
var _cast: Node2D  # 替身們（結束時釋放）
var _backdrop: CanvasLayer
var _sil := false
var _concealed := {}  # conceal 過的節點 → 原本的透明度
var _need_release := false  # 跳過停在 skip_stop 段之後：放開暫停鍵前不累計長按
var _gone := false  # 已離開場景樹：等待中的指令立刻結束（c2a Minor 4）
var _layers: Array = []  # show_layer 加的圖層（交還時釋放）
var _shown := {}  # 演出前真正的玩家與 Boss 是否可見（交還時恢復；end_state 不要改它們的 visible）


static func line_time(text: String) -> float:
	return maxf(1.5, 0.12 * text.length())


func _ready() -> void:
	camera = Camera2D.new()
	add_child(camera)
	_cast = Node2D.new()
	_cast.name = "Cast"
	add_child(_cast)
	_backdrop = CanvasLayer.new()
	_backdrop.layer = -1  # 畫在場景（第 0 層）後面
	_backdrop.visible = false
	add_child(_backdrop)
	var g := Gradient.new()
	g.colors = PackedColorArray([SIL_TOP, SIL_BOTTOM])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(bg)
	_ui = CanvasLayer.new()
	_ui.layer = 5  # 在 Boss 戰的 UI（HUD、白茫、文字卡）之上
	add_child(_ui)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_fade)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(b)
		_bars.append(b)
	subtitle = RichTextLabel.new()
	subtitle.bbcode_enabled = true
	subtitle.fit_content = true
	subtitle.scroll_active = false
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	subtitle.add_theme_color_override("default_color", Color.WHITE)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_constant_override("outline_size", 10)
	_ui.add_child(subtitle)
	title_label = _label(120)
	epithet_label = _label(44)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_ui.add_child(_ring)
	_layout()


func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 14)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(l)
	return l


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func bar_height() -> float:
	return _screen().y * BAR_FRAC * _bar_k


func _layout() -> void:
	var sz := _screen()
	var h := bar_height()
	_bars[0].position = Vector2(0, h - sz.y * BAR_FRAC)
	_bars[0].size = Vector2(sz.x, sz.y * BAR_FRAC)
	_bars[1].position = Vector2(0, sz.y - h)
	_bars[1].size = Vector2(sz.x, sz.y * BAR_FRAC)
	subtitle.position = Vector2(sz.x * 0.08, sz.y - h + 8.0)  # 在下方黑邊裡（角色站在畫面下緣，放在黑邊上面會蓋住他們）
	subtitle.size = Vector2(sz.x * 0.84, sz.y * BAR_FRAC - 12.0)
	title_label.position = Vector2(0, sz.y * 0.36)
	title_label.size = Vector2(sz.x, 140)
	epithet_label.position = Vector2(0, sz.y * 0.36 + 150.0)
	epithet_label.size = Vector2(sz.x, 60)
	_ring.position = sz - Vector2(80, 80)
	_ring.size = Vector2(60, 60)


func _process(delta: float) -> void:
	_t += delta
	if _line_t0 >= 0.0 and _t - _line_t0 >= MIN_LINE and MenuInput.just(&"attack"):
		_advance = true
	_bar_k = move_toward(_bar_k, _bar_target, delta / BAR_TIME)
	if running and host != null and host.hud != null:  # 只在演出期間寫（c2b）
		host.hud.modulate.a = 1.0 - _bar_k
	if not Input.is_action_pressed(&"pause"):
		_need_release = false
	if running and not skipped and not _need_release and Input.is_action_pressed(&"pause"):
		_hold += delta
		if _hold >= SKIP_HOLD:
			skipped = true
	else:
		_hold = 0.0
	_layout()
	_ring.queue_redraw()


func _draw_ring() -> void:
	if _hold <= 0.0:
		return
	var c := Vector2(30, 30)
	_ring.draw_arc(c, RING_R, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 4.0)
	_ring.draw_arc(c, RING_R, -PI / 2.0, -PI / 2.0 + TAU * minf(_hold / SKIP_HOLD, 1.0), 32, Color.WHITE, 4.0)


# ---- 生命週期 ----

func run(scenes: Array) -> void:
	if running:  # MV-SLICE-001c2b：不重跑（第二個 _begin／_handover 會打亂第一段的凍結與顯示）
		push_error("cutscene 已在執行")
		return
	running = true
	skipped = false
	_hold = 0.0
	add_to_group(GROUP)
	_begin()
	_bar_target = 1.0
	for i in scenes.size():
		var s = scenes[i]
		if skipped and s.get("skip_stop") == true:
			for p in scenes.slice(0, i):  # 被跳過的段落把舞台擺到最後的樣子，再從這段開頭播（c2c 最終審查）
				if p.has_method("settle"):
					p.settle(self)
			skipped = false
			_need_release = true
		if not skipped:
			await s.play(self)
	subtitle.text = ""
	title_label.modulate.a = 0.0
	epithet_label.modulate.a = 0.0
	# 有段落宣告 keep_black（結尾，c2c）：黑畫面保持到換房；否則收掉
	_fade.color = Color.BLACK if scenes.any(func(s): return s.get("keep_black") == true) else Color(0, 0, 0, 0)
	_handover(scenes)
	_bar_target = 0.0
	await _until(func() -> bool: return _bar_k <= 0.0, true)
	remove_from_group(GROUP)
	running = false


## 藏起真正的玩家與 Boss（演出由替身演），凍結戰場，換成自己的鏡頭
func _begin() -> void:
	if host == null:
		return
	_shown = {}
	for n in [host.player, host.boss]:
		if n != null:
			_shown[n] = n.visible
			n.visible = false
	host.world.process_mode = Node.PROCESS_MODE_DISABLED
	if host.scenery != null:
		host.scenery.process_mode = Node.PROCESS_MODE_ALWAYS  # 場景照常：視差、Chimalmat
	camera.position = host.camera.get_screen_center_position()
	camera.make_current()


## 交還操作（同一幀，之後才收黑邊；MV-SLICE-001c2a 最終審查、c2b）：移除替身 → 恢復真角色的顯示與 conceal 過的節點 →
## 解凍戰場 → 依序呼叫各段的 end_state（它對顯示的設定，例如藏起 Boss，不會被蓋掉）→ 換回戰鬥鏡頭（end_state 搬過角色，鏡頭直接到位）。
## 兩組角色不會同時在畫面上；這一幀按下的鍵不穿透到角色。
func _handover(scenes: Array) -> void:
	if _sil:
		silhouette(false)
	for a in _cast.get_children():
		a.queue_free()
	for n in _layers:
		if is_instance_valid(n):
			n.queue_free()
	_layers.clear()
	for n in _concealed:
		if is_instance_valid(n):
			n.modulate.a = _concealed[n]
	_concealed.clear()
	if host != null:
		for n in _shown:
			if is_instance_valid(n):
				n.visible = _shown[n]
		host.world.process_mode = Node.PROCESS_MODE_INHERIT
		if host.scenery != null:
			host.scenery.process_mode = Node.PROCESS_MODE_INHERIT
	MenuInput.swallow()
	for s in scenes:
		s.end_state(host)
	if host != null:
		host.camera.make_current()
		host.camera.reset_smoothing()


## 演出期間藏起真正的節點（透明度 0，交還時恢復）。用透明度而不是 visible：有些節點的 visible 每幀由別處設定（老夫婦）
func conceal(node: CanvasItem) -> void:
	if not _concealed.has(node):
		_concealed[node] = node.modulate.a
	node.modulate.a = 0.0


## 同時開始幾個指令（每個 Callable 是一個指令協程），全部做完才 return；跳過時立刻 return
func together(calls: Array) -> void:
	if skipped:
		return
	var left := [calls.size()]
	for c in calls:
		_run_one(c, left)
	await _until(func() -> bool: return left[0] <= 0)


func _run_one(c: Callable, left: Array) -> void:
	await c.call()
	left[0] -= 1


## 每幀檢查 cond，成立（或跳過、ignore_skip 為 false 時）就結束
func _until(cond: Callable, ignore_skip := false) -> void:
	while not _gone and not cond.call() and (ignore_skip or not skipped):
		await Engine.get_main_loop().process_frame


func _exit_tree() -> void:
	_gone = true


func _enter_tree() -> void:
	_gone = false


# ---- 指令 ----

## 過場的動作音效（MV-SLICE-001d1b）：被跳過就不放，跳過時不會一口氣把剩下的音效全放出來
func sfx(id: StringName) -> void:
	if not skipped:
		Audio.play(id)


func wait(secs: float) -> void:
	var end := _t + secs
	await _until(func() -> bool: return _t >= end)


func narrate(text: String) -> void:
	await _line(text)


func say(who: String, text: String) -> void:
	await _line(text, who)


func _line(text: String, who := "") -> void:
	if skipped:
		return
	subtitle.text = ("[center][color=%s]%s：[/color]%s[/center]" % [NAME_COLOR, who, text]) if who != "" else "[center]%s[/center]" % text
	_line_t0 = _t
	_advance = false
	var dur := line_time(text)
	await _until(func() -> bool: return _t - _line_t0 >= dur or _advance)
	_line_t0 = -1.0
	subtitle.text = ""


func title(who: String, epithet: String, secs := 1.5) -> void:
	if skipped:
		return
	title_label.text = who
	epithet_label.text = epithet
	var t0 := _t
	await _until(func() -> bool:
		var k := _t - t0
		var a := clampf(minf(k / 0.3, (secs - k) / 0.3), 0.0, 1.0)
		title_label.modulate.a = a
		epithet_label.modulate.a = a
		return k >= secs)
	title_label.modulate.a = 0.0
	epithet_label.modulate.a = 0.0


## 鏡頭硬切到 rect 的中心
func view(rect: Rect2) -> void:
	camera.position = rect.get_center()
	camera.reset_smoothing()


func fade_to_black(secs := 0.5) -> void:
	_fade.color = Color(0, 0, 0, _fade.color.a)
	await _fade_to(1.0, secs)


## 白光淡入（閃回的前後；c2c）
func fade_to_white(secs := 0.4) -> void:
	_fade.color = Color(1, 1, 1, _fade.color.a)
	await _fade_to(1.0, secs)


func fade_in(secs := 0.5) -> void:
	await _fade_to(0.0, secs)


func _fade_to(a: float, secs: float) -> void:
	if skipped:
		return
	var from := _fade.color.a
	var t0 := _t
	await _until(func() -> bool:
		var k := clampf((_t - t0) / secs, 0.0, 1.0)
		_fade.color.a = lerpf(from, a, k)
		return k >= 1.0)


# ---- 替身與剪影 ----

## 蓋在畫面上的圖層（閃回布景；c2c）：在白幕、黑邊、字幕之下，交還時釋放
func show_layer(node: CanvasItem) -> void:
	_ui.add_child(node)
	_ui.move_child(node, 0)
	_layers.append(node)


## 逐幀動畫：secs 秒內每幀呼叫 step.call(k)，k 由 0 到 1；跳過時直接 step.call(1.0)
func animate(secs: float, step: Callable) -> void:
	if not skipped:
		var t0 := _t
		await _until(func() -> bool:
			var k := clampf((_t - t0) / maxf(secs, 0.001), 0.0, 1.0)
			step.call(k)
			return k >= 1.0)
		if not skipped:
			return
	step.call(1.0)


## 演出裡 cid 相同的第一個替身（後面的段落接著用前面段落留下的替身）；沒有回傳 null
func cast_of(cid: String) -> Node2D:
	for a in _cast.get_children():
		if not a.is_queued_for_deletion() and a.get("cid") == cid:
			return a
	return null


## 放一個替身（演出結束時釋放）；剪影中的新替身直接塗黑；胡納普依真正角色的狀態斷臂
func spawn(cid: String, at: Vector2) -> Node2D:
	var a = Actor.make(cid)
	a.position = at
	_cast.add_child(a)
	a.set_black(_sil)
	if host != null and cid == TwinAnimator.CHARS[0] and host.player.get("twins") != null:
		a.rig.set_arm_visible(not host.player.twins[0].arm_broken)
	return a


## 放一個不是骨架的道具（剪影、食物、落下中的球具；MV-SLICE-001c3a）：跟替身放在一起，交還時一起釋放
func place(node: Node2D) -> Node2D:
	_cast.add_child(node)
	return node


## 走到 x（預設播 walk、面向目的地），到了換回待機；跳過時直接到位
func walk(actor: Node2D, x: float, speed := WALK_SPEED, anim := "walk") -> void:
	if not skipped:
		actor.facing = 1 if x > actor.position.x else -1
		actor.play(anim)
		var t0 := _t
		var from := actor.position.x
		var dur := absf(x - from) / speed
		await _until(func() -> bool:
			var k := clampf((_t - t0) / maxf(dur, 0.001), 0.0, 1.0)
			actor.position.x = lerpf(from, x, k)
			return k >= 1.0)
	actor.position.x = x
	actor.play(actor.idle_anim())


## 飛到 to（預設播 fly），secs 秒；face＝false 時保持原本面向（展翅往後退）；跳過時直接到位
func fly(actor: Node2D, to: Vector2, secs: float, anim := "fly", face := true) -> void:
	if not skipped:
		if face and to.x != actor.position.x:
			actor.facing = 1 if to.x > actor.position.x else -1
		actor.play(anim)
		var t0 := _t
		var from := actor.position
		await _until(func() -> bool:
			var k := clampf((_t - t0) / maxf(secs, 0.001), 0.0, 1.0)
			actor.position = from.lerp(to, k)
			return k >= 1.0)
	actor.position = to


## 倒著播 anim 的前 from 秒（secs 秒內回到第 0 格），再換回待機；跳過時直接待機（展翅 → 收翅；c2b）
func rewind(actor: Node2D, anim: String, from: float, secs: float) -> void:
	if not skipped:
		actor.play(anim)
		actor.t = from
		actor.rate = -from / secs
		await wait(secs)
	actor.play(actor.idle_anim())


## 播動作：單次動作等播完（停在最後一格），循環動作不等
func play(actor: Node2D, anim: String) -> void:
	actor.play(anim)
	if not actor.is_loop(anim):
		await wait(actor.anim_length(anim))


## 逆光剪影（SLICE-c2-4）：world 塗黑、場景圖層依角色的透明度、暖色漸層底、替身純黑
func silhouette(on: bool) -> void:
	_sil = on
	_backdrop.visible = on
	if host != null:
		host.world.modulate = Color.BLACK if on else Color.WHITE
		if host.scenery != null:
			host.scenery.set_silhouette(on)
	for a in _cast.get_children():
		if a.has_method("set_black"):  # place() 放的道具沒有
			a.set_black(on)


func backdrop_visible() -> bool:
	return _backdrop.visible


## 把節點的 modulate 在 secs 秒內漸變到 to（奇瑪瑪特變黑、淡出；c2b）；跳過時直接到位
func tint(node: CanvasItem, to: Color, secs: float) -> void:
	if not skipped:
		var from := node.modulate
		var t0 := _t
		await _until(func() -> bool:
			var k := clampf((_t - t0) / maxf(secs, 0.001), 0.0, 1.0)
			node.modulate = from.lerp(to, k)
			return k >= 1.0)
	node.modulate = to
