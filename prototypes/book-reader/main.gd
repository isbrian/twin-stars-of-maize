extends Node
# MV-BOOK-006 繪本閱讀器。啟動參數（放在 -- 之後）：
#   --self-test                 執行自動測試後結束（結束碼 0＝全部通過）
#   --screenshot <資料夾>       輸出選單與幾頁的 1920×1080 截圖後結束（需要視窗，不能 --headless）
#   --open <front|back> <頁> [zh_TW|en]   略過選單，直接開到某一頁

const Style := preload("res://book_style.gd")
const StartMenu := preload("res://start_menu.gd")
const BookReader := preload("res://book_reader.gd")
const SelfTest := preload("res://tests/self_test.gd")

var menu: Control
var reader: Control
var ui: CanvasLayer


func _ready() -> void:
	setup_input()
	TranslationServer.set_locale("zh_TW")
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t: Node = SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	build()
	var shot := args.find("--screenshot")
	if shot >= 0 and shot + 1 < args.size():
		await screenshots(args[shot + 1])
		get_tree().quit()
		return
	var o := args.find("--open")
	if o >= 0 and o + 2 < args.size():
		if o + 3 < args.size():
			TranslationServer.set_locale(args[o + 3])
		open_book(args[o + 1], int(args[o + 2]))


func build() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	menu = StartMenu.new()
	ui.add_child(menu)
	menu.chosen.connect(_on_menu)
	reader = BookReader.new()
	reader.visible = false
	ui.add_child(reader)
	reader.closed.connect(close_book)


func open_book(volume: String, index := 1) -> void:
	menu.visible = false
	reader.visible = true
	reader.open(volume, index)


func close_book() -> void:
	reader.visible = false
	menu.visible = true
	menu.refresh()


func _on_menu(item: String) -> void:
	match item:
		"front", "back":
			open_book(item)
		"quit":
			get_tree().quit()


static func setup_input() -> void:
	# 動作：[鍵盤鍵, ...], [手把鈕, ...]
	var map := {
		"page_next": [[KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X]],
		"page_prev": [[KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER]],
		"book_back": [[KEY_ESCAPE], [JOY_BUTTON_B]],
		"lang_toggle": [[KEY_L], []],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in map[action][0]:
			var k := InputEventKey.new()
			k.physical_keycode = code
			InputMap.action_add_event(action, k)
		for code in map[action][1]:
			var j := InputEventJoypadButton.new()
			j.button_index = code
			InputMap.action_add_event(action, j)


func screenshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_size(Vector2i(Style.W, Style.H))  # 截圖要 1920×1080，不是預設的 1280×720 視窗
	await get_tree().process_frame
	var shots := [["menu", "", 0, "zh_TW"], ["front_02_zh", "front", 2, "zh_TW"],
		["back_20_zh", "back", 20, "zh_TW"], ["back_20_en", "back", 20, "en"], ["back_08_zh", "back", 8, "zh_TW"]]
	for s in shots:
		TranslationServer.set_locale(s[3])
		if s[1] == "":
			close_book()
		else:
			open_book(s[1], s[2])
		for i in 4:
			await get_tree().process_frame
		var path: String = dir.path_join("%s.png" % s[0])
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])
