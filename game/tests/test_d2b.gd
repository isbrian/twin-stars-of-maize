extends "res://tests/base_test.gd"
# MV-SLICE-001d2b 繪本前篇：文字、插圖、版面、翻頁、按鍵、音效、字型；主選單「繪本」與新遊戲詢問。

const BookText := preload("res://ui/book_text.gd")
const Style := preload("res://ui/book_style.gd")
const BookPage := preload("res://ui/book_page.gd")
const BookReader := preload("res://ui/book_reader.gd")


func press(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


## 等處理幀（同 test_d2a：開頁時 MenuInput.swallow() 吞掉那一個處理幀的按鍵）
func process_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func make_reader(at := 1) -> Node:
	var r = BookReader.new()
	add_child(r)
	r.open(at)
	await process_frames(2)
	return r


func page_count(r) -> int:
	return r.get_children().filter(func(c): return c.get_script() == BookPage and not c.is_queued_for_deletion()).size()


# ---- Task 2：閱讀器與插圖 ----

func test_book_text_eight_pages() -> void:
	check(BookText.FRONT.size() == 8, "前篇 8 頁（%d）" % BookText.FRONT.size())
	for p in BookText.FRONT:
		check(p[0] != "" and p[1] != "", "標題與正文非空（%s）" % p[0])


func test_book_art_present() -> void:
	for n in range(1, 9):
		var path: String = Style.art_path(n)
		check(ResourceLoader.exists(path), "插圖存在：%s" % path)
		if ResourceLoader.exists(path):
			var t: Texture2D = load(path)
			check(t.get_size() == Vector2(1920, 1080), "%s 是 1920×1080（%s）" % [path, t.get_size()])


func test_every_page_fits() -> void:
	for n in range(1, 9):
		var p = BookPage.new()
		p.setup(n)
		add_child(p)
		await frames(2)
		check(p.text_bottom() <= Style.TEXT_LIMIT, "第 %d 頁文字排到 %.0f（上限 %d）" % [n, p.text_bottom(), Style.TEXT_LIMIT])
		p.queue_free()


func test_page_shows_title_and_folio() -> void:
	var p = BookPage.new()
	p.setup(3)
	add_child(p)
	await frames(2)
	check(p.title_text() == BookText.FRONT[2][0], "第 3 頁標題（%s）" % p.title_text())
	check(p.folio_text() == "前篇 3／8", "頁碼（%s）" % p.folio_text())
	p.queue_free()


func test_navigation() -> void:
	var r = await make_reader()
	r.prev_page()
	check(r.index == 1, "第一頁不能再往前")
	r.next_page()
	check(r.index == 2, "下一頁")
	r.prev_page()
	check(r.index == 1, "上一頁")
	r.queue_free()


func test_turn_during_fade() -> void:
	var r = await make_reader()
	r.next_page()
	r.next_page()
	check(r.index == 3 and r.is_fading(), "轉場中再翻頁：直接到第 3 頁")
	check(page_count(r) <= 2, "轉場中最多兩頁（%d）" % page_count(r))
	await get_tree().create_timer(Style.FADE_TIME + 0.2, true, false, true).timeout
	check(page_count(r) == 1, "轉場完只剩一頁（%d）" % page_count(r))
	r.queue_free()


func test_last_page_closes_once() -> void:
	var r = await make_reader(8)
	var got := [0]
	r.closed.connect(func(): got[0] += 1)
	r.next_page()
	r.next_page()
	check(got[0] == 1, "最後一頁再往下：closed 一次（%d）" % got[0])
	r.queue_free()


func test_back_key_closes_once() -> void:
	var r = await make_reader()
	var got := [0]
	r.closed.connect(func(): got[0] += 1)
	await press(&"roll")
	await press(&"roll")
	check(got[0] == 1, "返回鍵：closed 一次（%d）" % got[0])
	r.queue_free()


func test_keys_turn_pages() -> void:
	var r = await make_reader()
	await press(&"move_right")
	check(r.index == 2, "右鍵下一頁（%d）" % r.index)
	await press(&"attack")
	check(r.index == 3, "攻擊鍵下一頁（%d）" % r.index)
	await press(&"move_left")
	check(r.index == 2, "左鍵上一頁（%d）" % r.index)
	r.queue_free()


func test_book_sounds() -> void:
	var open0: int = Audio.play_count.get(&"ui_page_open", 0)
	var close0: int = Audio.play_count.get(&"ui_page_close", 0)
	var r = await make_reader()
	check(Audio.play_count.get(&"ui_page_open", 0) == open0 + 1, "開啟：ui_page_open")
	r.prev_page()
	check(Audio.play_count.get(&"ui_page_open", 0) == open0 + 1, "第一頁往前：不出聲")
	r.next_page()
	check(Audio.play_count.get(&"ui_page_open", 0) == open0 + 2, "翻頁：ui_page_open")
	await press(&"roll")
	check(Audio.play_count.get(&"ui_page_close", 0) == close0 + 1, "離開：ui_page_close")
	r.queue_free()


func test_book_font_weights() -> void:
	var ts := TextServerManager.get_primary_interface()
	var title: FontVariation = Style.font("title")
	var body: FontVariation = Style.font("body")
	check(title.base_font.resource_path == Style.FONT_PATH, "繪本用介面字型（%s）" % title.base_font.resource_path)
	check(is_equal_approx(title.variation_opentype.get(ts.name_to_tag("wght"), 0.0), 700.0), "標題字重 700")
	check(is_equal_approx(body.variation_opentype.get(ts.name_to_tag("wght"), 0.0), 500.0), "正文字重 500")


# ---- Task 4：主選單「繪本」與新遊戲詢問 ----

const TitleMenu := preload("res://ui/title_menu.gd")
const Save := preload("res://state/save.gd")
const TEST_SAVE := "user://test_d2b_save.json"
const TEST_ASKED := "user://test_d2b_asked.json"


func make_title(with_save := false, asked := false) -> Node:
	for p in [TEST_SAVE, TEST_ASKED]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if with_save:
		var gs = load("res://state/game_state.gd").new()
		gs.tn = fresh_tuning()
		gs.reset_new_game()
		Save.write(gs.to_dict(), TEST_SAVE)
		gs.free()
	if asked:
		FileAccess.open(TEST_ASKED, FileAccess.WRITE).store_string("{\"asked\": true}")
	var layer := CanvasLayer.new()
	add_child(layer)
	var t = TitleMenu.new()
	t.save_path = TEST_SAVE
	t.book_asked_path = TEST_ASKED
	layer.add_child(t)
	await process_frames(3)
	return t


func free_title(t) -> void:
	t.get_parent().queue_free()
	await process_frames(2)
	for p in [TEST_SAVE, TEST_ASKED]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func chosen_log(t) -> Array:
	var got := []
	t.chosen.connect(func(m): got.append(m))
	return got


func test_book_item_opens_reader() -> void:
	var t = await make_title()
	var got := chosen_log(t)
	check(t.can_choose("繪本"), "繪本可選")
	t.choose_item("繪本")
	check(t.book != null, "開出閱讀器")
	await process_frames(3)
	await press(&"roll")
	await process_frames(2)
	check(t.book == null and got.is_empty(), "返回：關閉、回選單（%s）" % [got])
	await free_title(t)


func test_book_close_does_not_choose() -> void:
	var t = await make_title()
	var got := chosen_log(t)
	check(TitleMenu.ITEMS[t.cursor] == "新遊戲", "游標在新遊戲")
	t.choose_item("繪本")
	await process_frames(3)
	t.book.open(8)
	await process_frames(3)
	await press(&"attack")  # 讀完
	await process_frames(3)
	check(t.book == null, "讀完關閉")
	check(got.is_empty() and not t.asking and not t.confirming, "讀完那一下不觸發選單（%s）" % [got])
	await free_title(t)


func test_first_new_game_asks() -> void:
	var t = await make_title()
	var got := chosen_log(t)
	t.choose_item("新遊戲")
	check(t.asking and got.is_empty(), "第一次新遊戲：先詢問")
	await free_title(t)


func test_ask_skip_starts_and_records() -> void:
	var t = await make_title()
	var got := chosen_log(t)
	t.choose_item("新遊戲")
	t.answer_ask(false)
	check(got == ["new"], "直接開始（%s）" % [got])
	check(FileAccess.file_exists(TEST_ASKED), "寫入記錄檔")
	await free_title(t)


func test_ask_read_starts_once() -> void:
	var t = await make_title()
	var got := chosen_log(t)
	t.choose_item("新遊戲")
	t.answer_ask(true)
	check(t.book != null and FileAccess.file_exists(TEST_ASKED), "讀繪本：開閱讀器、寫入記錄檔")
	await process_frames(3)
	t.book.open(8)
	await process_frames(3)
	for i in 3:
		await press(&"attack")
	check(got == ["new"], "讀完只開一次新遊戲（%s）" % [got])
	await free_title(t)


func test_ask_roll_starts() -> void:
	var t = await make_title()
	var got := chosen_log(t)
	t.choose_item("新遊戲")
	await process_frames(2)
	await press(&"roll")
	check(got == ["new"], "詢問中按翻滾＝直接開始（%s）" % [got])
	await free_title(t)


func test_no_ask_when_recorded() -> void:
	var t = await make_title(false, true)
	var got := chosen_log(t)
	t.choose_item("新遊戲")
	check(got == ["new"] and not t.asking, "問過了：直接開始（%s）" % [got])
	await free_title(t)


func test_ask_after_overwrite_confirm() -> void:
	var t = await make_title(true)
	var got := chosen_log(t)
	t.choose_item("新遊戲")
	check(t.confirming and not t.asking, "有存檔：先確認覆蓋")
	t.choose_item("新遊戲")
	check(t.asking and got.is_empty(), "確認後才詢問")
	await free_title(t)


func test_book_keeps_ambience() -> void:
	var t = await make_title()
	t.choose_item("繪本")
	await process_frames(2)
	check(Audio.ambience == &"amb_01", "繪本開著：森林環境音（%s）" % Audio.ambience)
	await free_title(t)
