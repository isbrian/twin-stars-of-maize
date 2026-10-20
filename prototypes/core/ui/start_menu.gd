extends Control
# 開頭選單（MV-PROTO-003 規格書第 7 節、PROTO3-4）：練習房／Boss 戰＋「Boss 段落保留」開關。
# 上下鍵或搖桿選、攻擊鍵確認；不提任何設局線索。

signal chosen(mode: String, keep_phase: bool)

var index := 0
var keep_phase := false


func labels() -> PackedStringArray:
	return PackedStringArray(["練習房", "Boss 戰", "Boss 段落保留：%s" % ("開" if keep_phase else "關")])


func move(dir: int) -> void:
	index = clampi(index + dir, 0, 2)
	queue_redraw()


func confirm() -> void:
	match index:
		0:
			chosen.emit("room", keep_phase)
		1:
			chosen.emit("boss", keep_phase)
		2:
			keep_phase = not keep_phase
			queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("look_up"):
		move(-1)
	elif Input.is_action_just_pressed("look_down"):
		move(1)
	elif Input.is_action_just_pressed("attack"):
		confirm()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.1))
	draw_string(font, Vector2(0, 300), "核心原型", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color(0.95, 0.9, 0.8))
	var items := labels()
	for i in items.size():
		var sel := i == index
		draw_string(font, Vector2(0, 480 + i * 80), ("▶ " if sel else "") + items[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(1, 1, 1, 1.0 if sel else 0.45))
	draw_string(font, Vector2(0, size.y - 80), "上下選擇　攻擊鍵確認", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(1, 1, 1, 0.5))
