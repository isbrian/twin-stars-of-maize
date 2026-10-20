extends Control
# 製作說明畫面（MV-SLICE-001d2a）：manual（主選單：上下捲、返回關閉）／auto（片尾：自動往上捲，捲完停一下再關；攻擊或返回跳過）。
# 內容在 credits_text.gd；closed 只發一次。

const MenuInput := preload("res://ui/menu_input.gd")
const CreditsText := preload("res://ui/credits_text.gd")
const AUTO_SPEED := 60.0  # px／秒
const AUTO_HOLD := 2.0  # 捲完停幾秒
const MANUAL_SPEED := 600.0
const SIZES := {"title": 72, "heading": 34, "body": 30, "gap": 30}
const LINE_GAP := 1.6  # 行高＝字級 × 這個倍數
const TOP_PAD := 160.0

signal closed

var mode := "manual"
var title := ""
var scroll := 0.0
var font: Font = preload("res://art/fonts/NotoSerifTC_ui.ttf")  # 思源宋體精簡版（SLICE-d2a-7；tools/font_subset.py 產生）
var _hold := 0.0
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 內容的總高度（捲到這裡＝最後一行已經離開畫面上緣）
func content_height() -> float:
	var h := TOP_PAD
	for l in CreditsText.LINES:
		h += SIZES[l[0]] * LINE_GAP
	return h


func _close() -> void:
	if _closed:
		return
	_closed = true
	MenuInput.swallow()
	closed.emit()


func _process(delta: float) -> void:
	if _closed:
		return
	if mode == "auto":
		if MenuInput.just(&"attack") or MenuInput.just(&"roll") or MenuInput.just(&"pause"):
			_close()
			return
		if scroll < content_height():
			scroll = minf(scroll + AUTO_SPEED * delta, content_height())
		else:
			_hold += delta
			if _hold >= AUTO_HOLD:
				_close()
				return
	else:
		if MenuInput.just(&"roll") or MenuInput.just(&"pause"):
			Audio.play(&"ui_back")
			_close()
			return
		var dir := Input.get_axis(&"look_up", &"look_down")
		scroll = clampf(scroll + dir * MANUAL_SPEED * delta, 0.0, maxf(content_height() - size.y * 0.5, 0.0))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05, 0.94))
	var start := size.y if mode == "auto" else TOP_PAD  # 片尾從畫面下緣捲進來
	var y := start - scroll
	for l in CreditsText.LINES:
		var fs: int = SIZES[l[0]]
		y += fs * LINE_GAP
		var text: String = title if l[0] == "title" else l[1]
		if text == "" or y < -fs or y > size.y + fs:
			continue
		var color := Color(1, 0.92, 0.75) if l[0] != "body" else Color(0.92, 0.9, 0.85)
		draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color)
