extends Control
# 祖母的兌換（MV-SLICE-001a 規格「可可豆與祖母兌換」）：熱湯一碗 15 顆、最多帶 2 碗；不足或已滿時不可選。
# 攻擊鍵買、返回鍵離開。開啟時遊戲暫停（由 game_world 處理）。

const MenuInput := preload("res://ui/menu_input.gd")

signal closed

var gs


func open(p_gs) -> void:
	gs = p_gs
	visible = true
	MenuInput.swallow()  # 打開兌換的那一下互動鍵不能在同一幀又把它關掉
	queue_redraw()


func item_label() -> String:
	return "熱湯（%d 顆）" % gs.tn.soup_price


func can_confirm() -> bool:
	return gs.can_buy_soup()


func confirm() -> bool:
	var ok: bool = gs.buy_soup()
	if ok:
		Audio.play(&"npc_exchange")  # 與祖母交換（MV-SLICE-001d1b）
	queue_redraw()
	return ok


func _process(_delta: float) -> void:
	if not visible or gs == null:
		return
	if MenuInput.just(&"attack"):
		confirm()
	elif MenuInput.just(&"pause") or MenuInput.just(&"roll") or MenuInput.just(&"interact"):
		Audio.play(&"ui_back")
		visible = false
		MenuInput.swallow()
		closed.emit()


func _draw() -> void:
	if gs == null:
		return
	draw_rect(Rect2(Vector2(560, 300), Vector2(800, 360)), Color(0.12, 0.1, 0.08, 0.92))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(620, 380), "祖母", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 0.92, 0.75))
	draw_string(f, Vector2(620, 460), "▶ " + item_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1, 1.0 if can_confirm() else 0.35))
	draw_string(f, Vector2(620, 520), "可可豆 %d　熱湯 %d／%d" % [gs.cacao, gs.soup, gs.tn.soup_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.8))
	draw_string(f, Vector2(620, 610), "攻擊 買　Esc／Start 離開", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
