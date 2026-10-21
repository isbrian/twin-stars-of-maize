extends "res://tests/base_test.gd"
# MV-SLICE-001d2a 標題畫面、主選單與製作說明：製作說明（manual／auto）、片尾、五項主選單、介面字型。

const Credits := preload("res://ui/credits.gd")
const CreditsText := preload("res://ui/credits_text.gd")
const Ending := preload("res://world/ending.gd")


func press(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func make_credits(mode: String) -> Node:
	var c = Credits.new()
	c.mode = mode
	c.title = "測試標題"
	add_child(c)
	await frames(2)
	return c


# ---- Task 1：製作說明與片尾 ----

func test_credits_text_discloses() -> void:
	var all := ""
	for l in CreditsText.LINES:
		all += l[1] + "\n"
	for w in ["Brian", "AI", "ChatGPT", "Codex", "Christenson", "Tedlock", "Godot", "Open Font License", "協作"]:
		check(w in all, "製作說明要寫到「%s」" % w)


func test_credits_adaptations_registered() -> void:  # MV-SLICE-001d2d
	var all := ""
	for l in CreditsText.LINES:
		all += l[1] + "\n"
	var cp := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../CULTURAL_PRINCIPLES.md"))
	check(cp != "", "讀得到 CULTURAL_PRINCIPLES.md")
	# 製作說明的改編例子 → 改編清單裡對應那一列的關鍵字
	var pairs := {"燒了尾巴": "老鼠是先被雙胞胎捕捉、燒尾", "祖母正在睡覺": "咬繩時祖母睡著", "牙痛發狂": "七金剛鸚鵡）牙痛發狂"}
	for k in pairs:
		check(k in all, "製作說明有「%s」" % k)
		check(pairs[k] in cp, "改編清單有登記「%s」" % pairs[k])
	check(not "影子" in all, "製作說明只舉切片看得到的改編（不提影子）")


func test_credits_manual_scroll_and_close() -> void:
	var c = await make_credits("manual")
	var got := [0]
	c.closed.connect(func(): got[0] += 1)
	Input.action_press(&"look_down")
	await frames(20)
	Input.action_release(&"look_down")
	check(c.scroll > 0.0, "按住下：往下捲（%s）" % c.scroll)
	await press(&"roll")
	check(got[0] == 1, "返回鍵關閉")
	c.queue_free()


func test_credits_auto_finishes() -> void:
	var c = await make_credits("auto")
	var got := [0]
	c.closed.connect(func(): got[0] += 1)
	c.scroll = c.content_height()
	await get_tree().create_timer(Credits.AUTO_HOLD + 0.3, true, false, true).timeout
	check(got[0] == 1, "捲完停 %s 秒後關閉" % Credits.AUTO_HOLD)
	c.queue_free()


func test_auto_skip_closes_once() -> void:
	var c = await make_credits("auto")
	var got := [0]
	c.closed.connect(func(): got[0] += 1)
	await press(&"attack")
	await press(&"attack")
	await frames(3)
	check(got[0] == 1, "連按兩次跳過只關一次（%d）" % got[0])
	c.queue_free()


func test_ending_runs_credits() -> void:
	var e = Ending.new()
	e.tn = fresh_tuning()
	e.tn.card_min_time = 0.0
	var done := [0]
	e.done.connect(func(): done[0] += 1)
	add_child(e)
	await frames(2)
	check(not "製作" in e.card.text, "結尾卡不再放製作資訊（%s）" % e.card.text)
	e.card.confirm()
	await frames(2)
	var cr = e.credits
	check(cr != null and cr.mode == "auto", "結尾卡之後是自動捲動的製作說明")
	await press(&"attack")
	await frames(3)
	check(done[0] == 1, "跳過片尾 → done 一次")
	e.queue_free()


# ---- Task 2：標題畫面與五項主選單 ----

const TitleMenu := preload("res://ui/title_menu.gd")
const SceneryView := preload("res://world/scenery_view.gd")
const Actor := preload("res://world/cutscene/actor.gd")
const TEST_SAVE := "user://test_d2a_none.json"


## 等處理幀（開頁時 MenuInput.swallow() 吞掉「那一個處理幀」的按鍵；headless 一個處理幀裡可能跑好幾個物理幀，frames() 不夠）
func process_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func make_title() -> Node:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var layer := CanvasLayer.new()
	add_child(layer)
	var t = TitleMenu.new()
	t.save_path = TEST_SAVE
	layer.add_child(t)
	await frames(3)
	return t


func free_title(t) -> void:
	t.get_parent().queue_free()
	await frames(2)


func test_menu_items() -> void:
	var t = await make_title()
	check(TitleMenu.ITEMS == ["新遊戲", "繼續", "繪本", "製作說明", "結束遊戲"], "五個項目（%s）" % [TitleMenu.ITEMS])
	check(t.can_choose("繪本"), "繪本可選（MV-SLICE-001d2b）")
	await free_title(t)


func test_cursor_skips_disabled() -> void:
	var t = await make_title()
	check(TitleMenu.ITEMS[t.cursor] == "新遊戲", "沒有存檔：游標在新遊戲（%s）" % TitleMenu.ITEMS[t.cursor])
	t.move_cursor(1)
	check(TitleMenu.ITEMS[t.cursor] == "繪本", "往下跳過繼續（%s）" % TitleMenu.ITEMS[t.cursor])
	t.move_cursor(-1)
	check(TitleMenu.ITEMS[t.cursor] == "新遊戲", "往上回到新遊戲（%s）" % TitleMenu.ITEMS[t.cursor])
	t.move_cursor(-1)
	check(TitleMenu.ITEMS[t.cursor] == "結束遊戲", "從頂端往上繞到結束遊戲（%s）" % TitleMenu.ITEMS[t.cursor])
	await free_title(t)


func test_credits_from_menu() -> void:
	var t = await make_title()
	t.choose_item("製作說明")
	await process_frames(3)
	var c = t.credits
	check(c != null and c.mode == "manual" and c.title == TitleMenu.display_title(), "開出手動的製作說明、標題帶版號（MV-RELEASE-001）")
	await press(&"roll")
	await frames(2)
	check(t.credits == null, "關閉後移除")
	await free_title(t)


func test_credits_close_does_not_choose() -> void:
	var t = await make_title()
	var got := [""]
	t.chosen.connect(func(m): got[0] = m)
	t.choose_item("製作說明")
	await process_frames(3)
	await press(&"roll")
	await frames(3)
	check(got[0] == "" and not t.confirming_quit and not t.confirming, "關製作說明那一下不觸發選單")
	await free_title(t)


func test_quit_confirm_cancels() -> void:
	var t = await make_title()
	var quits := [0]
	t.quit_requested.connect(func(): quits[0] += 1)
	t.choose_item("結束遊戲")
	check(t.confirming_quit and quits[0] == 0, "第一次：要確認")
	await press(&"look_down")
	check(not t.confirming_quit, "上下移動取消確認")
	t.choose_item("結束遊戲")
	t.choose_item("結束遊戲")
	check(quits[0] == 1, "再按兩次：離開一次")
	await free_title(t)


func test_title_ambience() -> void:
	Audio.set_ambience(&"")
	var t = await make_title()
	check(Audio.ambience == &"amb_01", "主選單：森林環境音（%s）" % Audio.ambience)
	await free_title(t)
	Audio.set_ambience(&"")


func test_title_background_built() -> void:
	var t = await make_title()
	var views := t.find_children("*", "", true, false).filter(func(n): return n.get_script() == SceneryView)
	check(views.size() == 1 and views[0].night, "背景：夜裡的場景")
	var macaws := t.find_children("*", "", true, false).filter(func(n): return n.get_script() == Actor and n.cid == "sevenmacaw")
	check(macaws.size() == 1 and macaws[0].modulate == Color.BLACK, "樹冠上 Seven Macaw 的剪影")
	await free_title(t)


# ---- Task 3：介面字型 ----

const UI_FONT_PATH := "res://art/fonts/NotoSerifTC_ui.ttf"


func test_ui_font_covers_all_text() -> void:
	check(ResourceLoader.exists(UI_FONT_PATH), "介面字型存在")
	if not ResourceLoader.exists(UI_FONT_PATH):
		return
	var f: Font = load(UI_FONT_PATH)
	var text: String = TitleMenu.GAME_TITLE + TitleMenu.SUBTITLE + TitleMenu.CONFIRM_NEW + TitleMenu.CONFIRM_QUIT + "▶"
	text += TitleMenu.ASK_TEXT + "".join(TitleMenu.ASK_ITEMS)  # MV-SLICE-001d2b 新遊戲詢問
	for item in TitleMenu.ITEMS:
		text += item
	for l in CreditsText.LINES:
		text += l[1]
	for page in load("res://ui/book_text.gd").FRONT:  # 繪本前篇（MV-SLICE-001d2b）
		text += page[0] + page[1].replace("\n", "")
	text += load("res://ui/book_style.gd").FOLIO
	var missing := ""
	for c in text:
		if c != " " and c != "　" and not f.has_char(c.unicode_at(0)) and not c in missing:
			missing += c
	check(missing == "", "介面字型缺字：%s" % missing)


func test_title_and_credits_use_ui_font() -> void:
	var t = await make_title()
	check(t.font.resource_path == UI_FONT_PATH, "主選單用介面字型（%s）" % t.font.resource_path)
	var c = await make_credits("manual")
	check(c.font.resource_path == UI_FONT_PATH, "製作說明用介面字型")
	c.queue_free()
	await free_title(t)


## 最終審查 Important：回主選單時，主程式先 queue_free 遊戲世界、馬上顯示標題；
## 幀尾遊戲世界的 _exit_tree 呼叫 Audio.stop_all()，把標題剛設的 AMB-01 關掉 → 之後的標題都是靜音
func test_title_ambience_after_quit() -> void:
	var m = load("res://main.gd").new()
	m.auto_start = false
	add_child(m)
	var w = m._open_world()
	w.gs = make_gs_for_quit()
	w.save_path = "user://test_d2a_quit.json"
	w.dev_start("home")
	await process_frames(5)
	w._to_title()
	await process_frames(10)
	check(m.title != null and is_instance_valid(m.title), "回到主選單")
	check(Audio.ambience == &"amb_01", "回主選單後標題仍有森林環境音（%s）" % Audio.ambience)
	m.queue_free()
	await process_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_d2a_quit.json"))


func make_gs_for_quit():
	var gs = load("res://state/game_state.gd").new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs
