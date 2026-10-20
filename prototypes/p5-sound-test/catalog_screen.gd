extends Control
# 主持人試聽（PROTO5-11）：按 1～8 播放 8 種聲音，同一鍵連按輪流 01→02→03。不記錄任何資料。

const Quiz := preload("res://quiz.gd")
const AudioBank := preload("res://audio_bank.gd")
const FONT_SIZE := 32

var state := "ready"  # ready／error
var now_playing := ""
var status_text := ""

var _audio_dir := AudioBank.DIR
var _next_variant := {}  # 聲音 → 下一次要播的變體
var _player: AudioStreamPlayer
var _status: Label


func setup(audio_dir := AudioBank.DIR) -> void:
	_audio_dir = audio_dir


func _ready() -> void:
	size = Vector2(1920, 1080)
	var box := VBoxContainer.new()
	box.position = Vector2(240, 90)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(_label("主持人試聽：按 1～8 播放，連按同一鍵輪流播三個變體", FONT_SIZE + 8))
	var keys := Quiz.SOUNDS.keys()
	for i in keys.size():
		box.add_child(_label("%d　%s" % [i + 1, Quiz.SOUND_LABELS[keys[i]]], FONT_SIZE))
	_status = _label("", FONT_SIZE)
	box.add_child(_status)
	var miss := AudioBank.missing(_audio_dir)
	if not miss.is_empty():
		state = "error"
		status_text = "缺少 %d 個音檔（%s …）\n先執行 ./sync_audio.sh" % [miss.size(), miss[0]]
	else:
		_player = AudioStreamPlayer.new()
		add_child(_player)
	_status.text = status_text


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		press(event.physical_keycode, event.echo)


func press(keycode: Key, echo := false) -> void:
	if echo or state != "ready":
		return
	if keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	var keys := Quiz.SOUNDS.keys()
	var i := int(keycode) - int(KEY_1)
	if i < 0 or i >= keys.size():
		return
	var sound: String = keys[i]
	var v: int = _next_variant.get(sound, 1)
	_next_variant[sound] = v % Quiz.VARIANTS + 1
	now_playing = Quiz.file_name(sound, v)
	status_text = "正在播：%s %s" % [Quiz.SOUND_LABELS[sound], now_playing.trim_prefix("sfx_voc_").get_basename()]
	_status.text = status_text
	_player.stream = AudioBank.load_stream(now_playing, _audio_dir)
	_player.play()
