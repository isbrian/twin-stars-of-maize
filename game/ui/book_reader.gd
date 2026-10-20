extends Control
# 繪本閱讀器（MV-SLICE-001d2b，移植自原型 book_reader.gd）：翻頁＋交叉淡入淡出。
# 按鍵（SLICE-d2b-5）：右鍵、攻擊鍵、Enter 下一頁；左鍵上一頁；翻滾、暫停鍵離開。最後一頁再往下＝讀完。
# 輸入用 MenuInput 輪詢（同 credits.gd）；closed 只發一次。

const Style := preload("res://ui/book_style.gd")
const BookPage := preload("res://ui/book_page.gd")
const MenuInput := preload("res://ui/menu_input.gd")

signal closed

var index := 1
var page: Control = null
var _old: Control = null
var _tween: Tween = null
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(Style.W, Style.H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(p_index := 1) -> void:
	index = clampi(p_index, 1, Style.TOTAL)
	_finish_fade()
	if page:
		page.queue_free()
	page = _make_page(index)
	add_child(page)
	Audio.play(&"ui_page_open")
	MenuInput.swallow()


func next_page() -> void:
	_finish_fade()
	if index >= Style.TOTAL:
		_close()
		return
	_go(index + 1)


func prev_page() -> void:
	_finish_fade()
	if index > 1:
		_go(index - 1)


func is_fading() -> bool:
	return _tween != null and _tween.is_running()


func _process(_delta: float) -> void:
	if _closed:
		return
	if MenuInput.just(&"move_right") or MenuInput.just(&"attack") or MenuInput.just(&"ui_accept"):
		next_page()
	elif MenuInput.just(&"move_left"):
		prev_page()
	elif MenuInput.just(&"roll") or MenuInput.just(&"pause"):
		_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	_finish_fade()
	Audio.play(&"ui_page_close")
	MenuInput.swallow()
	closed.emit()


func _go(n: int) -> void:
	if _closed:
		return
	index = n
	Audio.play(&"ui_page_open")
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
	p.setup(n)
	return p
