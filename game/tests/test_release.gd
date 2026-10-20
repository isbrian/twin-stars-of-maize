extends "res://tests/base_test.gd"
# MV-RELEASE-001 公開試玩版：正式標題「雙子星玉米人」、App 名稱、版號。

const TitleMenu := preload("res://ui/title_menu.gd")
const Ending := preload("res://world/ending.gd")


func test_title_is_final() -> void:
	check(TitleMenu.GAME_TITLE == "雙子星玉米人", "正式標題（%s）" % TitleMenu.GAME_TITLE)
	var app: String = ProjectSettings.get_setting("application/config/name")
	check(app == "雙子星玉米人", "App 名稱（%s）" % app)


func test_no_sacred_name_in_title() -> void:
	var names := [TitleMenu.GAME_TITLE, ProjectSettings.get_setting("application/config/name"), TitleMenu.display_title()]
	for n in names:
		for w in ["Popol", "波波爾", "烏"]:
			check(not w in n, "「%s」不含聖典名「%s」" % [n, w])


func test_display_title_has_version() -> void:
	check(TitleMenu.display_title() == "雙子星玉米人 v0.1.0", "製作說明標題帶版號（%s）" % TitleMenu.display_title())


func test_credits_show_version() -> void:
	var e = Ending.new()
	e.tn = fresh_tuning()
	e.tn.card_min_time = 0.0
	add_child(e)
	await frames(2)
	e.card.confirm()
	await frames(2)
	check(e.credits != null and e.credits.title == TitleMenu.display_title(), "片尾的製作說明標題帶版號")
	e.queue_free()
	await frames(2)


# ---- 匯出版的中文顯示（MV-RELEASE-001 Task 4 實測發現）----

const UI_FONT_PATH := "res://art/fonts/NotoSerifTC_ui.ttf"


## 網頁版沒有系統字型可借：預設字型要以內附的思源宋體精簡版為後備，不然 HUD、文字卡的中文變方框
func test_default_font_has_cjk_fallback() -> void:
	var paths := ThemeDB.fallback_font.fallbacks.map(func(f): return f.resource_path)
	check(UI_FONT_PATH in paths, "預設字型的後備含介面字型（%s）" % [paths])


## 遊戲裡所有 .gd 字串常值（tests 以外）用到的字都要在介面字型裡
func test_ui_font_covers_game_strings() -> void:
	var f: Font = load(UI_FONT_PATH)
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	var missing := ""
	for path in _gd_files("res://"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			for c in m.get_string(1):
				if c.unicode_at(0) >= 0x2E80 and not f.has_char(c.unicode_at(0)) and not c in missing:
					missing += c
	check(missing == "", "介面字型缺遊戲字串的字：%s" % missing)


## 匯出版要內含 ICU 斷行資料，中文才不會把「，」「。」排在行首
func test_text_server_data_included() -> void:
	check(ProjectSettings.get_setting("internationalization/locale/include_text_server_data", false), "include_text_server_data 要開")


func _gd_files(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		if d != "tests" and not d.begins_with("."):
			out += _gd_files(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


## 網頁版的「結束遊戲」只會讓畫面停住：不可選（quit_enabled 預設＝不是網頁版）
func test_quit_disabled_on_web() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var t = TitleMenu.new()
	t.save_path = "user://test_release_none.json"
	t.book_asked_path = "user://test_release_asked_none.json"
	layer.add_child(t)
	await frames(2)
	check(t.quit_enabled == not OS.has_feature("web"), "預設：非網頁版才可結束")
	t.quit_enabled = false
	check(not t.can_choose("結束遊戲"), "quit_enabled 關掉時不可選")
	var quits := [0]
	t.quit_requested.connect(func(): quits[0] += 1)
	t.choose_item("結束遊戲")
	t.choose_item("結束遊戲")
	check(quits[0] == 0, "選了也不離開")
	layer.queue_free()
	await frames(2)
