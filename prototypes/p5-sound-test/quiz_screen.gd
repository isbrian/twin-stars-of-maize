extends Control
# 測驗畫面（PROTO5-2、4、5、9）：說明 → 24 題（自動播一次、Space 重播、1～7 選擇、Enter 確認）→ 結束。
# 答題中不顯示對錯；每確認一題立即寫一列 CSV，寫入失敗就停止。Esc 離開。

const Quiz := preload("res://quiz.gd")
const Results := preload("res://results.gd")
const AudioBank := preload("res://audio_bank.gd")
const AUTO_PLAY_DELAY := 0.5
const NEXT_DELAY := 0.6
const FONT_SIZE := 32
const HIGHLIGHT := Color(0.85, 0.7, 0.3)
const ROW_BG := Color(0.16, 0.19, 0.22)

var auto_play_delay := AUTO_PLAY_DELAY
var next_delay := NEXT_DELAY
var state := "intro"  # intro／wait（等自動播放）／trial／gap／done／error
var trials: Array = []
var trial_index := 0
var selected := ""
var play_count := 0
var csv_path := ""
var error_text := ""
var rows: Array = []

var _tester := ""
var _session := ""
var _seed := -1
var _only: Array = []  # 空＝全部 24 題
var _results_dir := Results.DIR
var _audio_dir := AudioBank.DIR
var _token := 0  # 每題遞增，讓過期的計時器失效
var _first_play_ms := -1
var _player: AudioStreamPlayer
var _header: Label
var _footer: Label
var _corner: Label
var _rows_box: VBoxContainer
var _cat_panels := {}  # 類別 id → PanelContainer


func setup(tester: String, results_dir := Results.DIR, seed := -1, audio_dir := AudioBank.DIR, only: Array = []) -> void:
	_session = Results.session_stamp()
	_tester = Results.sanitize_tester(tester)
	if _tester.is_empty():
		_tester = _session
	_results_dir = results_dir
	_seed = seed if seed != -1 else Time.get_ticks_usec()
	_audio_dir = audio_dir
	_only = only
	csv_path = Results.session_path(_results_dir, _tester, _session)


func _ready() -> void:
	if _tester.is_empty():
		setup("")
	size = Vector2(1920, 1080)
	_build_ui()
	var miss := AudioBank.missing(_audio_dir)
	if not miss.is_empty():
		state = "error"
		error_text = "缺少 %d 個音檔（%s …）\n先執行 ./sync_audio.sh" % [miss.size(), miss[0]]
	else:
		trials = Quiz.make_trials(_seed, _only)
		_player = AudioStreamPlayer.new()
		add_child(_player)
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		press(event.physical_keycode, event.echo)


func press(keycode: Key, echo := false) -> void:
	if echo:
		return
	if keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	match state:
		"intro":
			if keycode == KEY_ENTER:
				_start_trial()
		"wait", "trial":
			if keycode == KEY_SPACE:
				_play()
			elif keycode >= KEY_1 and keycode <= KEY_7:
				selected = Quiz.category_for_key(keycode - KEY_0)
				_render()
			elif keycode == KEY_ENTER and state == "trial" and selected != "":
				_confirm()


func _start_trial() -> void:
	_token += 1
	selected = ""
	play_count = 0
	_first_play_ms = -1
	state = "wait"
	_render()
	var token := _token
	get_tree().create_timer(auto_play_delay).timeout.connect(func():
		if token == _token and state == "wait":
			_play())


func _play() -> void:
	state = "trial"
	play_count += 1
	if _first_play_ms < 0:
		_first_play_ms = Time.get_ticks_msec()
	_player.stream = AudioBank.load_stream(trials[trial_index], _audio_dir)
	_player.play()
	_render()


func _confirm() -> void:
	var secs := (Time.get_ticks_msec() - _first_play_ms) / 1000.0
	var row := Quiz.make_row(_tester, _session, trial_index + 1, trials[trial_index], selected, play_count - 1, secs)
	var err := Results.append_row(csv_path, row)
	_player.stop()
	if err != OK:
		state = "error"
		error_text = "無法寫入 %s（錯誤 %d），測驗已停止" % [csv_path, err]
		_render()
		return
	rows.append(row)
	print("ANSWER tester=%s trial=%d sound=%s actual=%s guess=%s correct=%s" % [_tester, row.trial, row.sound, row.actual, row.guess, row.correct])
	trial_index += 1
	_token += 1
	if trial_index >= trials.size():
		state = "done"
		_render()
		return
	state = "gap"
	_render()
	var token := _token
	get_tree().create_timer(next_delay).timeout.connect(func():
		if token == _token and state == "gap":
			_start_trial())


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(240, 90)
	box.size = Vector2(1440, 900)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	_header = _label(FONT_SIZE + 8)
	box.add_child(_header)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 10)
	box.add_child(_rows_box)
	for c in Quiz.CATEGORIES:
		var panel := PanelContainer.new()
		var l := _label(FONT_SIZE)
		l.text = "  %d　%s：%s" % [c.key, c.label, c.hint]
		panel.add_child(l)
		_rows_box.add_child(panel)
		_cat_panels[c.id] = panel
	_footer = _label(FONT_SIZE)
	box.add_child(_footer)
	_corner = _label(22)
	_corner.autowrap_mode = TextServer.AUTOWRAP_OFF  # 寬度為 0 時自動換行會變成一字一行
	_corner.position = Vector2(240, 30)
	add_child(_corner)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _render() -> void:
	if _header == null:
		return
	_corner.text = "受測者：%s" % _tester
	_rows_box.visible = state in ["intro", "wait", "trial", "gap"]
	for id in _cat_panels:
		var sb := StyleBoxFlat.new()
		sb.bg_color = HIGHLIGHT if (id == selected and state in ["wait", "trial"]) else ROW_BG
		sb.set_content_margin_all(8)
		_cat_panels[id].add_theme_stylebox_override("panel", sb)
	match state:
		"intro":
			_header.text = "聲音盲測：每題會播一個聲音，請選出它屬於哪一類"
			_footer.text = "戴上耳機。按 Enter 開始"
		"wait", "trial":
			_header.text = "第 %d／%d 題" % [trial_index + 1, trials.size()]
			_footer.text = "Space 重播　1～7 選擇　Enter 確認"
		"gap":
			_header.text = "第 %d／%d 題" % [trial_index + 1, trials.size()]
			_footer.text = "下一題…"
		"done":
			_header.text = "完成，謝謝！"
			_footer.text = _result_text()
		"error":
			_header.text = "無法進行測驗"
			_footer.text = error_text


## 結束畫面給主持人看的本場結果（直接由本場作答列計算，不受底線代號略過規則影響）
func _result_text() -> String:
	var lines := PackedStringArray()
	for s in Quiz.SOUNDS:
		var ok := 0
		var n := 0
		for r in rows:
			if r.sound == s:
				n += 1
				ok += 1 if r.correct else 0
		lines.append("%s：%d/%d" % [Quiz.SOUND_LABELS[s], ok, n])
	return "　".join(lines.slice(0, 4)) + "\n" + "　".join(lines.slice(4)) + "\n紀錄：" + ProjectSettings.globalize_path(csv_path)
