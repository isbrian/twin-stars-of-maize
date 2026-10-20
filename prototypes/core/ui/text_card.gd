extends Control
# 全螢幕文字卡（MV-PROTO-003 規格書第 5 節）：暗底、置中文字、下方「攻擊鍵繼續」。
# 至少顯示 min_time 秒才接受攻擊鍵（計畫 D3：設局常在狂按攻擊時發生）。暫停戰場由 boss_fight 負責。

signal closed

var min_time := 0.5
var shown_time := 0.0
var text := ""


func _ready() -> void:
	visible = false


func show_card(s: String) -> void:
	text = s
	shown_time = 0.0
	visible = true
	queue_redraw()


func confirm() -> void:
	if not visible or shown_time < min_time:
		return
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	shown_time += delta
	if Input.is_action_just_pressed("attack"):
		confirm()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05, 0.92))
	var width := 1200.0
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, 34).y
	draw_multiline_string(font, Vector2((size.x - width) / 2.0, (size.y - h) / 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, 34, -1, Color(0.95, 0.92, 0.85))
	draw_string(font, Vector2(0, size.y - 80), "攻擊鍵繼續", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 1, 1, 0.6 if shown_time >= min_time else 0.25))
