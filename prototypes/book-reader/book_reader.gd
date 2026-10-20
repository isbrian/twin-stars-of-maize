extends Control
# 翻頁、交叉淡入淡出、語言切換。最後一頁再往下翻、或按返回，發出 closed。

signal closed

const Style := preload("res://book_style.gd")
const BookPage := preload("res://book_page.gd")

var volume := "front"
var index := 1
var page: Control = null
var _old: Control = null
var _tween: Tween = null


func _ready() -> void:
	size = Vector2(Style.W, Style.H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(p_volume: String, p_index := 1) -> void:
	volume = p_volume
	index = clampi(p_index, 1, Style.TOTAL[volume])
	_finish_fade()
	if page:
		page.queue_free()
	page = _make_page(index)
	add_child(page)


func next_page() -> void:
	_finish_fade()
	if index >= Style.TOTAL[volume]:
		closed.emit()
		return
	_go(index + 1)


func prev_page() -> void:
	_finish_fade()
	if index > 1:
		_go(index - 1)


func is_fading() -> bool:
	return _tween != null and _tween.is_running()


## 繁中與英文互換，目前這一頁立即重排
func toggle_language() -> void:
	var lang := Style.lang_of(TranslationServer.get_locale())
	TranslationServer.set_locale("en" if lang == "zh" else "zh_TW")
	if page:
		page.refresh()


func _go(n: int) -> void:
	index = n
	_old = page
	page = _make_page(n)
	page.modulate.a = 0.0
	add_child(page)
	_tween = create_tween().set_parallel()
	_tween.tween_property(page, "modulate:a", 1.0, Style.FADE_TIME)
	_tween.tween_property(_old, "modulate:a", 0.0, Style.FADE_TIME)
	_tween.chain().tween_callback(_drop_old)


## 轉場中又要翻頁時，直接把轉場做完
func _finish_fade() -> void:
	if is_fading():
		_tween.kill()
		page.modulate.a = 1.0
		_drop_old()
	_tween = null


func _drop_old() -> void:
	if _old:
		_old.queue_free()
		_old = null


func _make_page(n: int) -> Control:
	var p: Control = BookPage.new()
	p.setup(volume, n)
	return p


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if e.position.x >= Style.W / 2.0:
			next_page()
		else:
			prev_page()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("page_next"):
		next_page()
	elif e.is_action_pressed("page_prev"):
		prev_page()
	elif e.is_action_pressed("book_back"):
		_finish_fade()
		closed.emit()
	elif e.is_action_pressed("lang_toggle"):
		toggle_language()
	else:
		return
	get_viewport().set_input_as_handled()
