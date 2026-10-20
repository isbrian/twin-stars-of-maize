extends Node
# --self-test：每個 test_ 開頭的方法是一項測試，依名稱排序執行。
# 執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，驗證時要另外 grep。

const Style := preload("res://book_style.gd")
const BookPage := preload("res://book_page.gd")
const BookReader := preload("res://book_reader.gd")
const StartMenu := preload("res://start_menu.gd")

var pass_count := 0
var fail_count := 0
var _name := ""
var _failed := false


func run() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m.name).begins_with("test_"):
			names.append(m.name)
	names.sort()
	for n in names:
		_name = n
		_failed = false
		TranslationServer.set_locale("zh_TW")
		await call(n)
		if _failed:
			fail_count += 1
		else:
			pass_count += 1
		print("SELFTEST %s %s" % ["FAIL" if _failed else "PASS", n])
	print("SELFTEST SUMMARY pass=%d fail=%d" % [pass_count, fail_count])


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("SELFTEST   x %s：%s" % [_name, msg])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _page(volume: String, num: int, art: Texture2D = null, art_path := "") -> Control:
	var p: Control = BookPage.new()
	add_child(p)
	p.setup(volume, num, art, art_path)
	return p


func test_a_translations_cover_every_page() -> void:
	for locale in ["zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		for volume in Style.TOTAL:
			for n in range(1, Style.TOTAL[volume] + 1):
				for field in ["TITLE", "BODY"]:
					var key := "BOOK_%s_%02d_%s" % [volume.to_upper(), n, field]
					check(tr(key) != key, "%s 缺 %s" % [locale, key])
		for key in ["UI_MENU_FRONT", "UI_MENU_BACK", "UI_MENU_LANG", "UI_MENU_QUIT", "UI_NOTE_LABEL", "UI_FOLIO_FRONT", "UI_FOLIO_BACK", "UI_MISSING_ART"]:
			check(tr(key) != key, "%s 缺 %s" % [locale, key])
	TranslationServer.set_locale("zh_TW")
	check(tr("UI_MENU_FRONT") == "前篇", "繁中選單字串：%s" % tr("UI_MENU_FRONT"))
	TranslationServer.set_locale("en")
	check(tr("UI_MENU_FRONT") == "Part One", "英文選單字串：%s" % tr("UI_MENU_FRONT"))
	var notes := 0
	for n in range(1, 21):
		var key := "BOOK_BACK_%02d_NOTE" % n
		if tr(key) != key:
			notes += 1
	check(notes == 18, "後篇「遊戲裡」應有 18 段，實際 %d" % notes)


func test_b_fonts_use_spec_weights() -> void:
	var ts := TextServerManager.get_primary_interface()
	var zh: FontVariation = Style.font("zh", "body")
	var en: FontVariation = Style.font("en", "title")
	# 可變字型的名稱帶預設字重（例如 Noto Serif TC ExtraLight），實際字重由 variation_opentype 決定
	check(zh.base_font != null and zh.base_font.get_font_name().begins_with("Noto Serif TC"), "繁中字型：%s" % (zh.base_font.get_font_name() if zh.base_font else "null"))
	check(en.base_font != null and en.base_font.get_font_name().begins_with("Noto Serif") and not en.base_font.get_font_name().contains("TC"), "英文字型：%s" % (en.base_font.get_font_name() if en.base_font else "null"))
	check(is_equal_approx(zh.variation_opentype.get(ts.name_to_tag("wght"), 0.0), 500.0), "繁中正文字重應 500")
	check(is_equal_approx(en.variation_opentype.get(ts.name_to_tag("wght"), 0.0), 700.0), "英文標題字重應 700")
	check(is_equal_approx(en.variation_opentype.get(ts.name_to_tag("wdth"), 0.0), Style.EN_WIDTH), "英文字寬軸應 87.5")


func test_c_every_page_fits_in_both_languages() -> void:
	var worst := [0.0, ""]
	for locale in ["zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		for volume in Style.TOTAL:
			for n in range(1, Style.TOTAL[volume] + 1):
				var p := _page(volume, n)
				await frames(2)
				var b: float = p.text_bottom()
				check(b <= Style.TEXT_LIMIT, "%s %s %d 排到 %.0f（上限 %d）" % [locale, volume, n, b, Style.TEXT_LIMIT])
				if b > worst[0]:
					worst = [b, "%s %s %d" % [locale, volume, n]]
				p.queue_free()
	print("SELFTEST   文字底部最低：%s ＝ %.0f px" % [worst[1], worst[0]])


func test_d_navigation_limits() -> void:
	var r: Control = BookReader.new()
	add_child(r)
	var closed := [false]
	r.closed.connect(func(): closed[0] = true)
	r.open("front")
	r.prev_page()
	check(r.index == 1, "第一頁不能再往前")
	for i in 7:
		r.next_page()
	check(r.index == 8, "前篇翻到第 8 頁，實際 %d" % r.index)
	check(not closed[0], "第 8 頁之前不該回選單")
	r.next_page()
	check(closed[0], "最後一頁再往下翻要回選單")
	r.queue_free()
	await frames(1)


func test_e_paging_during_fade_finishes_it() -> void:
	var r: Control = BookReader.new()
	add_child(r)
	r.open("back", 3)
	r.next_page()
	check(r.is_fading(), "翻頁後應在轉場中")
	r.next_page()
	check(r.index == 5, "轉場中再翻頁應立即到第 5 頁，實際 %d" % r.index)
	await get_tree().create_timer(Style.FADE_TIME + 0.15).timeout
	await frames(2)
	var pages := r.get_children().filter(func(c): return c is Control and not c.is_queued_for_deletion())
	check(pages.size() == 1, "轉場結束後只留一頁，實際 %d" % pages.size())
	check(is_equal_approx(r.page.modulate.a, 1.0), "目前頁應完全不透明")
	r.queue_free()
	await frames(1)


func test_f_language_toggle_refreshes_page() -> void:
	var r: Control = BookReader.new()
	add_child(r)
	r.open("front", 1)
	await frames(1)
	var zh: String = r.page.title_text()
	r.toggle_language()
	await frames(1)
	var en: String = r.page.title_text()
	check(zh == "世界還沒有真正的太陽", "繁中標題：%s" % zh)
	check(en == "The World Before the True Sun", "英文標題：%s" % en)
	check(TranslationServer.get_locale() == "en", "切換後語言應為 en")
	r.toggle_language()
	check(Style.lang_of(TranslationServer.get_locale()) == "zh", "再切一次回繁中")
	r.queue_free()
	await frames(1)


func test_g_missing_art_uses_placeholder() -> void:
	var p := _page("back", 8, null, "res://art/__none__.png")
	check(p.art_missing, "找不到插圖時 art_missing 應為 true")
	check(p.get_child(0) is ColorRect, "缺圖時第一層應是素色底")
	check((p.get_child(0) as ColorRect).color == Style.PLACEHOLDER["back"][7], "素色底應用第 8 張的區域色")
	var marker: Label = p.get_children().filter(func(c): return c is Label and c.visible and c.text.contains("book_back_08")).front()
	check(marker != null, "應顯示缺圖標記")
	p.queue_free()
	var img := Image.create(16, 9, false, Image.FORMAT_RGB8)
	var q := _page("front", 2, ImageTexture.create_from_image(img))
	check(not q.art_missing and q.get_child(0) is TextureRect, "有插圖時第一層應是插圖")
	q.queue_free()
	await frames(1)


func test_h_menu_language_item() -> void:
	var m: Control = StartMenu.new()
	add_child(m)
	await frames(1)
	check(m.item_text("front").contains("前篇"), "選單前篇：%s" % m.item_text("front"))
	var got := [""]
	m.chosen.connect(func(item): got[0] = item)
	m.choose(StartMenu.ITEMS.find("lang"))
	check(TranslationServer.get_locale() == "en", "選單切換語言後應為 en")
	check(m.item_text("front").contains("Part One"), "切換後選單改成英文：%s" % m.item_text("front"))
	m.choose(StartMenu.ITEMS.find("back"))
	check(got[0] == "back", "選後篇應發出 back")
	m.queue_free()
	await frames(1)


func test_j_fonts_cover_every_character() -> void:
	# 精簡字型（MV-BOOK-007）只留用到的字：翻譯表每個字與選單游標都要有字形，否則畫面會出現缺字方塊
	var f := FileAccess.open("res://text/book_text.csv", FileAccess.READ)
	check(f != null, "讀不到 res://text/book_text.csv")
	if f == null:
		return
	var header := f.get_csv_line()
	var zh: Font = Style.font("zh", "body").base_font
	var en: Font = Style.font("en", "body").base_font
	var missing := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		for col in range(1, mini(row.size(), header.size())):
			for ch in row[col]:
				var c := ch.unicode_at(0)
				if c < 0x20:
					continue
				var ok := zh.has_char(c) if header[col] == "zh_TW" else en.has_char(c)
				if not ok:
					missing[ch] = true
	check(zh.has_char("▶".unicode_at(0)), "繁中字型缺選單游標 ▶")
	check(missing.is_empty(), "缺字：%s" % "".join(missing.keys()))


func test_i_input_actions_exist() -> void:
	for action in ["page_next", "page_prev", "book_back", "lang_toggle"]:
		check(InputMap.has_action(action), "缺少動作 %s" % action)
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	check(right.is_action_pressed("page_next"), "→ 應是下一頁")
	var lb := InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	check(lb.is_action_pressed("page_prev"), "LB 應是上一頁")
