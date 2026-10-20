extends Control
# 裝備頁（MV-SLICE-001a 規格 SLICE-a5）：替兩兄弟各選一把持有的近戰武器；選到對方的那把時兩人互換。
# 下方顯示動物技能槽（切片只開第 1 槽）。灰盒：文字。左右換欄、上下選武器、攻擊鍵裝上、返回鍵離開。

const Weapons := preload("res://core/player/weapons.gd")
const MenuInput := preload("res://ui/menu_input.gd")
const TWINS := ["胡納普", "希巴拉克"]  # MV-NAME-001 H01、H02
const SKILL_NAMES := {"rat": "老鼠"}

signal closed

var gs
var col := 0  # 目前選的是哪一兄弟
var row := 0  # 武器選項的索引


func open(p_gs) -> void:
	gs = p_gs
	col = 0
	row = 0
	visible = true
	Audio.play(&"ui_page_open")  # MV-SLICE-001d1b
	MenuInput.swallow()
	queue_redraw()


func options() -> Array:
	return gs.weapons_owned.duplicate()


func label_for(twin: int) -> String:
	var w: int = gs.equip[twin]
	return "—" if w == -1 else Weapons.NAMES[w]


func choose(twin: int, w: int) -> void:
	gs.equip_weapon(twin, w)
	queue_redraw()


func slot_labels() -> Array:
	var out: Array = []
	for i in 2:
		if i == 1 and not gs.slot2_unlocked:
			out.append("（鎖住）")
		else:
			out.append(SKILL_NAMES.get(gs.skill_slots[i], "（空）"))
	return out


func _process(_delta: float) -> void:
	if not visible or gs == null:
		return
	var opts := options()
	if MenuInput.just(&"move_left") or MenuInput.just(&"move_right"):
		col = 1 - col
		Audio.play(&"ui_move")
	elif MenuInput.just(&"look_up") and not opts.is_empty():
		row = (row - 1 + opts.size()) % opts.size()
		Audio.play(&"ui_move")
	elif MenuInput.just(&"look_down") and not opts.is_empty():
		row = (row + 1) % opts.size()
		Audio.play(&"ui_move")
	elif MenuInput.just(&"attack") and not opts.is_empty():
		Audio.play(&"ui_skill_switch")  # 換裝備（遊戲裡沒有另外切換技能槽，換裝備就用這個聲音）
		choose(col, opts[row])
	elif MenuInput.just(&"pause") or MenuInput.just(&"roll"):
		Audio.play(&"ui_page_close")
		visible = false
		MenuInput.swallow()
		closed.emit()
	else:
		return
	queue_redraw()


func _draw() -> void:
	if gs == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(160, 160), "裝備", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	var opts := options()
	for t in 2:
		var x := 160.0 + t * 520.0
		draw_string(f, Vector2(x, 240), "%s：%s" % [TWINS[t], label_for(t)], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 1.0 if t == col else 0.5))
		for i in opts.size():
			var mark := "▶ " if t == col and i == row else "　"
			draw_string(f, Vector2(x, 300 + i * 44), mark + Weapons.NAMES[opts[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.9))
	var slots := slot_labels()
	draw_string(f, Vector2(160, 560), "動物技能　槽 1：%s　槽 2：%s" % [slots[0], slots[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.92, 0.75))
	draw_string(f, Vector2(160, 640), "左右 換人　上下 選武器　攻擊 裝上　Esc／Start 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
