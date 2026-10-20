extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 12：主選單、繼續、從新遊戲自動走到結尾。

const GameStateScr := preload("res://state/game_state.gd")
const GameWorld := preload("res://world/game_world.gd")
const TitleMenu := preload("res://ui/title_menu.gd")
const Save := preload("res://state/save.gd")
const TEST_SAVE := "user://test_walkthrough_slot.json"
const TEST_ASKED := "user://test_walkthrough_asked.json"


func make_world_node(gs = null) -> Node:
	if gs == null:
		gs = GameStateScr.new()
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


func settle(w) -> bool:
	return await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)


func p_of(w):
	return w.flow.current.player


## 站進門裡，等換到下一個房間
func through(w, door_id: String) -> bool:
	var door: Dictionary = {}
	for d in w.flow.current.data.doors:
		if d.id == door_id:
			door = d
	var p = p_of(w)
	p.scripted = true
	p.velocity = Vector2.ZERO
	p.position = door.rect.get_center() + Vector2(0, door.rect.size.y / 2.0)
	var ok: bool = await wait_until(func(): return w.flow.current_id == door.to_room and not w.flow.is_busy(), 60)
	if ok:
		p_of(w).scripted = true
		await frames(2)
	return ok


func press_interact_at(w, at: Vector2) -> void:
	var p = p_of(w)
	p.scripted = true
	p.position = at
	p.velocity = Vector2.ZERO
	await frames(2)
	p.intent.interact_pressed = true
	await frames(3)


## 地面過場（MV-SLICE-001c3a）：等它開始，再同 Boss 段落長按暫停鍵跳過
func skip_ground(w, limit := 120) -> bool:
	if not await wait_until(func(): return w.runner.cutscene_running(), limit):
		return false
	return await skip_cutscene(w.runner)


## 演出（MV-SLICE-001c2a）：等它開始，按住暫停鍵直到跳過（上限 3 秒）再放開；遇到 skip_stop 段（覺醒，c2c）就再按一次，最多 4 次
func skip_cutscene(f) -> bool:
	if not await wait_until(func(): return f.cutscene.running, 120):
		return false
	for i in 4:
		Input.action_press(&"pause")
		await wait_until(func(): return f.cutscene.skipped or not f.cutscene.running, 180)
		Input.action_release(&"pause")
		await frames(3)
		if not f.cutscene.running or f.cutscene.skipped:
			break
	return await wait_until(func(): return not f.cutscene.running, 120)


func pass_card(card) -> String:
	await wait_until(func(): return card.visible, 300)
	var t: String = card.text
	card.confirm()
	await frames(2)
	return t


func test_title_continue_disabled_without_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var t = TitleMenu.new()
	t.save_path = TEST_SAVE
	t.book_asked_path = TEST_ASKED  # 繪本已問過（MV-SLICE-001d2b 的詢問另見 test_d2b）
	FileAccess.open(TEST_ASKED, FileAccess.WRITE).store_string("{\"asked\": true}")
	add_child(t)
	await frames(1)
	check(not t.can_choose("繼續"), "沒有存檔時「繼續」不可選")
	var got := [""]
	t.chosen.connect(func(m): got[0] = m)
	t.choose_item("繼續")
	check(got[0] == "", "選了也沒反應")
	t.choose_item("新遊戲")
	check(got[0] == "new", "沒有存檔時新遊戲直接開始")
	FileAccess.open(TEST_SAVE, FileAccess.WRITE).store_string("{壞掉")
	t.refresh()
	check(not t.can_choose("繼續"), "存檔壞掉時當成沒有存檔")
	var ok_gs = GameStateScr.new()
	ok_gs.tn = fresh_tuning()
	ok_gs.reset_new_game()
	Save.write(ok_gs.to_dict(), TEST_SAVE)  # 完整、合法的存檔（只有部分欄位的存檔不算，見 test_review_fixes）
	ok_gs.free()
	t.refresh()
	got[0] = ""
	check(t.can_choose("繼續"), "有存檔時可以繼續")
	t.choose_item("新遊戲")
	check(got[0] == "" and t.confirming, "有存檔時新遊戲要再確認一次")
	t.choose_item("新遊戲")
	check(got[0] == "new", "確認後開始新遊戲")
	t.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ASKED))


## 主選單掛在 CanvasLayer 下（main.gd 的做法）要佔滿畫面（Task 13 截圖發現大小是 0、文字被切掉）
func test_title_fills_screen_under_canvas_layer() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var t = TitleMenu.new()
	t.save_path = TEST_SAVE
	layer.add_child(t)
	await frames(2)
	check(t.size == t.get_viewport_rect().size, "主選單大小＝畫面（是 %s）" % [t.size])
	layer.queue_free()


func test_continue_restores_room_and_state() -> void:
	var w = make_world_node()
	w.new_game()
	await settle(w)
	await through(w, "to_yard")
	w.gs.add_cacao(7)
	w.flow.rest_here()  # 院子沒有休息點：直接呼叫流程的休息 → last_rest＝yard
	await settle(w)
	var gs2 = GameStateScr.new()
	gs2.tn = w.gs.tn
	var w2 = make_world_node(gs2)
	check(w2.continue_game(), "讀得到存檔")
	await settle(w2)
	check(w2.flow.current_id == "yard" and gs2.cacao == 7, "從最後休息的地方繼續、可可豆還在")
	w2.queue_free()
	await free_world(w)
	gs2.free()


## 覺醒後存的檔：「繼續」回到宮殿篝火、已覺醒（MV-SLICE-001c2c）
func test_continue_after_awakening() -> void:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.awakened = true
	gs.rest("palace_camp")
	Save.write(gs.to_dict(), TEST_SAVE)
	gs.free()
	var w = make_world_node()
	check(w.continue_game(), "讀得到存檔")
	await settle(w)
	var f = w.flow.current
	check(w.flow.current_id == "boss" and f.awakened and not f.boss.visible and f.stage == f.Stage.APPROACH, "宮殿篝火、已覺醒、Boss 不在")
	await free_world(w)


func test_walkthrough_new_game_to_exit() -> void:
	var w = make_world_node()
	var gs = w.gs
	var to_title := [false]
	w.quit_to_title.connect(func(): to_title[0] = true)
	w.new_game()
	check(await settle(w) and w.flow.current_id == "home", "新遊戲從祖母家開始")
	check(w.hints.current == "move", "開場提示：移動")
	check((await pass_card(w.runner.card)).contains("田地"), "開場旁白：去田地拿工具")
	check(await through(w, "to_field"), "祖母家 → 田地")
	await press_interact_at(w, Vector2(900, 900))
	await press_interact_at(w, Vector2(1250, 900))
	check(gs.has_flag("tools_obtained"), "撿到斧頭與掘棒")
	var p = p_of(w)
	for c in w.flow.current.get_children():
		if (c.get("kind") == "bush" or c.get("kind") == "clod") and c.hurtbox != null:  # 演出用的灌木打不到（c3a）
			p.attack_weapon = Weapons.Weapon.AXE if c.kind == "bush" else Weapons.Weapon.STICK
			c.hurtbox.receive(4, p, &"melee")
			await frames(1)
	check(await skip_ground(w), "清完田地：收工與動物復原的過場（長按跳過）")
	check(gs.has_flag("field_cleared") and gs.has_flag("night_seen"), "田地清完、入夜")
	var rat
	for c in w.flow.current.get_children():
		if c.get("kind") == "rat":
			rat = c
	p.position = Vector2(rat.position.x + 200, 900)
	p.intent.move_x = -1.0
	check(await skip_ground(w, 600) and gs.has_flag("rat_caught"), "把老鼠逼到牆角：交換的過場（球具的祕密）")
	p.intent.move_x = 0.0
	check(await through(w, "to_home"), "田地 → 祖母家")
	check(await skip_ground(w), "咬繩的過場")
	await wait_until(func(): return w.flow.current.pickups.size() == 1, 120)
	await press_interact_at(w, w.flow.current.pickups[0].position)
	check(await skip_ground(w), "天亮的過場（第二天早上）")
	check(gs.has_flag("gear_obtained") and gs.skill_slots[0] == "rat", "球具與老鼠技能")
	check(await through(w, "to_yard"), "祖母家 → 院子")
	check(await through(w, "to_forest"), "院子 → 森林 1（荊棘已不擋路）")
	for room in ["forest_1", "forest_2", "forest_3", "forest_4", "forest_5", "forest_6"]:  # 主路（MV-SLICE-001c4a）
		for e in get_tree().get_nodes_in_group("enemy"):
			if w.flow.current.is_ancestor_of(e):
				e.hurtbox.receive(999, p_of(w), &"melee")
		await frames(2)
		var next: String = ""
		for d in w.flow.current.data.doors:
			if d.spawn.x > 1000.0 and not d.get("branch", false):  # 右邊的主路門（支路門在高處）
				next = d.id
		check(await through(w, next), "%s → 下一個房間" % room)
	check(w.flow.current_id == "boss", "進 Boss 段落")
	var f = w.flow.current
	f.boss.cycle_enabled = false
	f.player.scripted = true
	f.player.position = Vector2(Nance.ENTRY_X + 100.0, Nance.GROUND_Y)
	check(await skip_cutscene(f), "開場演出（跳過）")
	await wait_until(func(): return f.stage == f.Stage.FIGHT, 600)
	f.boss.cycle_enabled = false
	await setup_now(f)
	check(await skip_cutscene(f), "斷臂與轉場演出（跳過）")
	f.player.position = Vector2(Palace.ENTRY_X + 100.0, Palace.GROUND_Y)
	check(await skip_cutscene(f), "牙痛開場演出（跳過）")
	await wait_until(func(): return f.stage == f.Stage.FIGHT, 60)
	f.boss.cycle_enabled = false
	await setup_now(f)
	check(await skip_cutscene(f), "換牙演出（跳過）")
	await wait_until(func(): return f.stage == f.Stage.FIGHT, 60)
	await setup_now(f)
	check(await skip_cutscene(f), "死亡與覺醒演出（跳過）")
	check(gs.awakened, "覺醒")
	f.player.velocity = Vector2.ZERO
	f.player.position = Vector2(Palace.EXIT_LEDGE.position.x + 200.0, Palace.EXIT_LEDGE.position.y)
	check(await wait_until(func(): return f.cutscene.running, 60), "走上高台：結尾演出")
	Input.action_press(&"pause")  # 跳過結尾演出；演出結束就換房、Boss 段落釋放（MV-SLICE-001c2c）
	var ended: bool = await wait_until(func(): return w.flow.current_id == "exit" and not w.flow.is_busy(), 300)
	Input.action_release(&"pause")
	check(ended, "打完 → 出口")
	check((await pass_card(w.flow.current.card)).contains("垂直切片到此結束，謝謝試玩。"), "結束畫面")
	check(await wait_until(func(): return w.flow.current.credits != null, 30), "接著是片尾的製作說明（MV-SLICE-001d2a）")
	w.flow.current.credits.scroll = w.flow.current.credits.content_height()  # 捲到底，等它停一下自己關
	check(await wait_until(func(): return to_title[0], 300), "製作說明捲完 → 回主選單")
	await free_world(w)


## 除錯鍵（F10、F11、1～3）只在 debug_keys 開時有效；F9 會寫 .tres，不在自測裡按
func test_debug_keys_only_in_debug_build() -> void:
	var w = make_world_node()
	w.dev_start("boss")
	await settle(w)
	var f = w.flow.current
	f.boss.cycle_enabled = false
	f.player.scripted = true
	f.start_at(1)
	await frames(2)
	w.debug_keys = false
	w.debug_action(&"debug_gauge")
	check(f.boss.gauge.value == 0, "發行版：F11 無效")
	w.debug_keys = true
	w.debug_action(&"debug_gauge")
	check(f.boss.gauge.value == w.gs.tn.gauge_max, "開發版：F11 破綻加滿")
	w.debug_action(&"debug_weapon_3")
	check(f.player.twins[f.player.twin_index].weapon == Weapons.Weapon.BALLGEAR, "數字鍵 3 換成球具")
	await free_world(w)
	remove_test_logs()
