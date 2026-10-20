extends Control
# 開頭選單：前篇、後篇、語言、結束。上下鍵或十字鍵選，確認鍵或滑鼠點選。

signal chosen(item: String)

const Style := preload("res://book_style.gd")
const ITEMS := ["front", "back", "lang", "quit"]
const KEYS := {"front": "UI_MENU_FRONT", "back": "UI_MENU_BACK", "lang": "UI_MENU_LANG", "quit": "UI_MENU_QUIT"}

var selected := 0
var _labels: Array[Label] = []
var _title: Label
var _cursor: Label


func _ready() -> void:
	size = Vector2(Style.W, Style.H)
	var bg := ColorRect.new()
	bg.color = Color8(16, 13, 10)
	bg.size = size
	add_child(bg)
	_title = Label.new()
	_title.position = Vector2(160, 300)
	add_child(_title)
	for i in ITEMS.size():
		var l := Label.new()
		l.position = Vector2(160, 440 + i * 80)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_item_input.bind(i))
		add_child(l)
		_labels.append(l)
	_cursor = Label.new()  # 游標獨立一個元件，項目文字才會對齊
	_cursor.text = "▶"  # 思源宋體有這個字形（▸ 沒有）
	add_child(_cursor)
	refresh()


func refresh() -> void:
	var lang := Style.lang_of(TranslationServer.get_locale())
	_title.text = tr("UI_MENU_TITLE")
	_title.label_settings = Style.label_settings(lang, "title", Style.INK)
	_title.label_settings.font_size = 64
	for i in ITEMS.size():
		var l := _labels[i]
		l.text = tr(KEYS[ITEMS[i]])
		l.label_settings = Style.label_settings(lang, "body", Style.INK if i == selected else Style.INK_SOFT)
		l.reset_size()
	# 游標固定用思源宋體：英文字型沒有 ▶；不用「後備字型」，因為後備會讓 Godot 把英文行高算成思源宋體的高度
	_cursor.label_settings = Style.label_settings("zh", "body", Style.INK)
	_cursor.position = Vector2(120, _labels[selected].position.y)


func item_text(item: String) -> String:
	return _labels[ITEMS.find(item)].text


func choose(i: int) -> void:
	selected = i
	if ITEMS[i] == "lang":
		var lang := Style.lang_of(TranslationServer.get_locale())
		TranslationServer.set_locale("en" if lang == "zh" else "zh_TW")
	refresh()
	chosen.emit(ITEMS[i])


func _on_item_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		choose(i)


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_down"):
		selected = (selected + 1) % ITEMS.size()
		refresh()
	elif e.is_action_pressed("ui_up"):
		selected = (selected - 1 + ITEMS.size()) % ITEMS.size()
		refresh()
	elif e.is_action_pressed("ui_accept"):
		choose(selected)
	else:
		return
	get_viewport().set_input_as_handled()
