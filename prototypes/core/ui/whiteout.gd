extends Control
# 白茫（MV-PROTO-003 規格書第 3 節）：只罩住畫面、不扣血；淡入、維持、淡出，不閃爍。

const MAX_ALPHA := 0.9

var tn = Tune.data
var t := -1.0  # < 0＝沒有白茫


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start() -> void:
	t = 0.0
	queue_redraw()


func stop() -> void:
	t = -1.0
	queue_redraw()


func is_active() -> bool:
	return t >= 0.0


static func alpha_at(s: float, p_tn) -> float:
	if s < 0.0:
		return 0.0
	if s < p_tn.whiteout_in:
		return MAX_ALPHA * s / p_tn.whiteout_in
	var hold_end: float = p_tn.whiteout_in + p_tn.whiteout_hold
	if s <= hold_end:
		return MAX_ALPHA
	var end: float = hold_end + p_tn.whiteout_out
	if s >= end:
		return 0.0
	return MAX_ALPHA * (end - s) / p_tn.whiteout_out


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if t >= tn.whiteout_in + tn.whiteout_hold + tn.whiteout_out:
		t = -1.0
	queue_redraw()


func _draw() -> void:
	var a := alpha_at(t, tn)
	if a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, a))
