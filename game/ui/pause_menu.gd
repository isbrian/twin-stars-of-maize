extends Control
# 暫停選單（MV-SLICE-001a）：Esc／Start 開關；「裝備」「回主選單」「回到遊戲」。開啟時整個遊戲暫停。
# 本身與裝備頁在暫停中仍要收輸入（process_mode＝ALWAYS）。

const EquipPage := preload("res://ui/equip_page.gd")
const MenuInput := preload("res://ui/menu_input.gd")
const ITEMS := ["裝備", "回主選單", "回到遊戲"]

signal quit_to_title
signal equip_opened  # 按鍵提示「裝備」的完成條件（Task 9）

var gs
var cursor := 0
var equip: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 已在樹裡：offsets 也要跟著設，否則大小是 0
	visible = false
	equip = EquipPage.new()
	equip.set_anchors_preset(Control.PRESET_FULL_RECT)
	equip.visible = false
	equip.closed.connect(func(): queue_redraw())
	add_child(equip)


func items() -> Array:
	return ITEMS.duplicate()


func open() -> void:
	cursor = 0
	visible = true
	get_tree().paused = true
	MenuInput.swallow()
	queue_redraw()


func close() -> void:
	visible = false
	if is_instance_valid(equip):
		equip.visible = false
	get_tree().paused = false
	MenuInput.swallow()


func choose_item(item: String) -> void:
	match item:
		"裝備":
			if gs != null:
				equip.open(gs)
				equip_opened.emit()
		"回主選單":
			close()
			quit_to_title.emit()
		"回到遊戲":
			close()


## 遊戲已被別的東西暫停（祖母的兌換）時不開；本節點排在兌換之前處理，兌換用暫停鍵關掉的那一幀不會反過來打開這裡
func _process(_delta: float) -> void:
	if not visible:
		if MenuInput.just(&"pause") and not get_tree().paused and get_tree().get_first_node_in_group(&"cutscene") == null:  # 演出中暫停鍵用來跳過（MV-SLICE-001c2a）
			open()
		return
	if equip.visible:
		return
	if MenuInput.just(&"pause") or MenuInput.just(&"roll"):
		Audio.play(&"ui_back")  # MV-SLICE-001d1b
		close()
	elif MenuInput.just(&"look_up"):
		cursor = (cursor - 1 + ITEMS.size()) % ITEMS.size()
		Audio.play(&"ui_move")
	elif MenuInput.just(&"look_down"):
		cursor = (cursor + 1) % ITEMS.size()
		Audio.play(&"ui_move")
	elif MenuInput.just(&"attack"):
		Audio.play(&"ui_confirm")
		choose_item(ITEMS[cursor])
	else:
		return
	queue_redraw()


func _draw() -> void:
	if equip.visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	for i in ITEMS.size():
		var mark := "▶ " if i == cursor else "　"
		draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 120, 420 + i * 60), mark + ITEMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
