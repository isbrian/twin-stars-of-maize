extends "res://tests/base_test.gd"
# MV-SLICE-001a 最終審查的修正：選單走真正的輸入事件、關選單的鍵不穿透、壞存檔不能繼續、工具照 SLICE-a6 分給兩兄弟、選單蓋在文字卡上。

const GameStateScr := preload("res://state/game_state.gd")
const GameWorld := preload("res://world/game_world.gd")
const TitleMenu := preload("res://ui/title_menu.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const Save := preload("res://state/save.gd")
const TEST_SAVE := "user://test_review_fixes_slot.json"


func stick_y(v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = v
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # headless 不會自己 flush


func key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # headless 不會自己 flush


func mouse_left(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # headless 不會自己 flush


func make_game_world() -> Node:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	return w


func free_world(w) -> void:
	var gs = w.gs
	w.queue_free()
	await frames(2)
	gs.free()
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_stick_moves_menu_cursor_once() -> void:
	var m = PauseMenu.new()
	add_child(m)
	m.open()
	await frames(1)
	for v in [0.6, 0.8, 1.0]:  # 推一次搖桿會送好幾個位移事件
		stick_y(v)
	await frames(2)
	check(m.cursor == 1, "暫停選單：搖桿往下推一次只移一格（是 %d）" % m.cursor)
	stick_y(0.0)
	await frames(1)
	for v in [0.7, 1.0]:
		stick_y(v)
	await frames(2)
	check(m.cursor == 2, "放開再推：再移一格（是 %d）" % m.cursor)
	stick_y(0.0)
	m.close()
	m.queue_free()
	var t = TitleMenu.new()
	t.save_path = TEST_SAVE
	add_child(t)
	await frames(1)
	for v in [0.6, 0.8, 1.0]:
		stick_y(v)
	for i in 3:  # 主選單在處理幀讀輸入（MV-SLICE-001d2a 起背景較重，物理幀不夠）
		await get_tree().process_frame
	# 沒有存檔時「繼續」不可選，往下一格是「繪本」（MV-SLICE-001d2b 起可選）
	check(t.cursor == TitleMenu.ITEMS.find("繪本"), "主選單：搖桿往下推一次只移一格（是 %d）" % t.cursor)
	stick_y(0.0)
	t.queue_free()
	await frames(1)


func test_menu_close_key_does_not_leak() -> void:
	var w = make_game_world()
	w.new_game()
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var p = w.flow.current.player
	p.position = Vector2(1150, 900)  # 祖母旁邊
	await frames(3)
	w._on_interacted("npc")
	await frames(2)
	key(KEY_E, true)
	await frames(3)
	key(KEY_E, false)
	await frames(2)
	check(not w.shop.visible and not get_tree().paused, "用互動鍵離開兌換：兌換關掉，不會馬上又打開")
	var swings := [0]
	p.swung.connect(func(): swings[0] += 1)
	w.pause_menu.open()
	w.pause_menu.cursor = 2  # 回到遊戲
	await frames(1)
	mouse_left(true)
	await frames(3)
	mouse_left(false)
	await frames(2)
	check(not w.pause_menu.visible and swings[0] == 0, "用攻擊鍵選「回到遊戲」：角色不揮武器（揮了 %d 次）" % swings[0])
	await free_world(w)


func test_bad_saves_cannot_continue() -> void:
	var good = GameStateScr.new()
	good.tn = fresh_tuning()
	good.reset_new_game()
	var bad := {
		"缺欄位": {"cacao": 3},
		"equip 長度不對": {"equip": []},
		"equip 有不存在的武器": {"equip": [7, -1]},
		"skill_slots 長度不對": {"skill_slots": ["rat"]},
		"last_rest 不是休息點": {"last_rest": "nowhere"},
	}
	for name in bad:
		var d: Dictionary = good.to_dict()
		if name == "缺欄位":
			d = bad[name]
		else:
			d.merge(bad[name], true)
		Save.write(d, TEST_SAVE)
		check(not Save.exists(TEST_SAVE), "%s：當成沒有存檔" % name)
		var w = make_game_world()
		check(not w.continue_game(), "%s：繼續回傳 false" % name)
		await free_world(w)
	FileAccess.open(TEST_SAVE, FileAccess.WRITE).store_string('{"version": null, "state": {}}')
	check(not Save.exists(TEST_SAVE), "version 是 null：當成沒有存檔")
	FileAccess.open(TEST_SAVE, FileAccess.WRITE).store_string('{"version": [1], "state": {}}')
	check(not Save.exists(TEST_SAVE), "version 是陣列：當成沒有存檔")
	var d2: Dictionary = good.to_dict()
	d2.last_rest = "palace_camp"
	Save.write(d2, TEST_SAVE)
	check(Save.exists(TEST_SAVE), "Boss 段落的篝火是合法的休息點")
	good.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## SLICE-a6：胡納普拿斧頭、希巴拉克拿掘棒，不管先撿哪一把（從祖母家進田地會先碰到掘棒）
func test_tools_go_to_their_twin_in_any_order() -> void:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.give_weapon(Weapons.Weapon.STICK)
	check(gs.equip == [-1, Weapons.Weapon.STICK], "先撿掘棒：給希巴拉克（是 %s）" % [gs.equip])
	gs.give_weapon(Weapons.Weapon.AXE)
	check(gs.equip == [Weapons.Weapon.AXE, Weapons.Weapon.STICK], "再撿斧頭：給胡納普")
	gs.give_weapon(Weapons.Weapon.BALLGEAR)
	check(gs.equip == [Weapons.Weapon.AXE, Weapons.Weapon.STICK] and gs.weapons_owned.has(Weapons.Weapon.BALLGEAR), "球具：兩人都有武器時只放進持有")
	gs.free()


## 文字卡（40）與換房淡出（50）不能蓋住暫停選單、兌換、裝備頁
func test_menus_draw_above_cards_and_fade() -> void:
	var w = make_game_world()
	await frames(1)
	var menu_layer: int = w.pause_menu.get_parent().layer
	check(w.shop.get_parent().layer == menu_layer, "兌換和暫停選單同一層")
	check(menu_layer > w.runner.card.get_parent().layer and menu_layer > w.flow._fade.get_parent().layer, "選單在文字卡與淡出之上（%d）" % menu_layer)
	check(w.hud.get_parent().layer < w.runner.card.get_parent().layer, "HUD 仍在文字卡之下")
	await free_world(w)
