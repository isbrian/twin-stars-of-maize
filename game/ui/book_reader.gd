extends Control
# 繪本閱讀器（MV-SLICE-001d2b，移植自原型 book_reader.gd）：翻頁＋交叉淡入淡出。
# 按鍵（SLICE-d2b-5）：右鍵、攻擊鍵、Enter 下一頁；左鍵上一頁；翻滾、暫停鍵離開。最後一頁再往下＝讀完。
# 輸入用 MenuInput 輪詢（同 credits.gd）；closed 只發一次。
# MV-SLICE-001d2b2：前後頁的插圖用背景執行緒預先載入，翻頁時不同步讀檔。

const Style := preload("res://ui/book_style.gd")
const BookPage := preload("res://ui/book_page.gd")
const MenuInput := preload("res://ui/menu_input.gd")

signal closed

var index := 1
var page: Control = null
var _old: Control = null
var _tween: Tween = null
var _closed := false
var _prefetch := {}  # 頁碼 → 插圖路徑（已送出背景載入、還沒用）
var taken := 0  # 用上預載插圖的次數（測試用）


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
	_prefetch_around(index)
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
	_prefetch_around(n)
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
	p.setup(n, _take(n))
	return p


func prefetched(n: int) -> bool:
	return _prefetch.has(n)


func _prefetch_around(n: int) -> void:
	for m in [n - 1, n + 1]:
		if m >= 1 and m <= Style.TOTAL and not _prefetch.has(m):
			var path: String = Style.art_path(m)
			if ResourceLoader.load_threaded_request(path) == OK:
				_prefetch[m] = path


## 拿預載好的插圖；還在載入就等它（不比同步 load 慢）；沒預載回傳 null，由 BookPage 同步載入
func _take(n: int) -> Texture2D:
	if not _prefetch.has(n):
		return null
	var path: String = _prefetch[n]
	_prefetch.erase(n)
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return null
	taken += 1
	return ResourceLoader.load_threaded_get(path) as Texture2D


## 沒用到的預載也要取回，背景載入的請求才會釋放；還在載入的會等它載完（最多兩張圖的解碼時間）
func _exit_tree() -> void:
	for path in _prefetch.values():
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)
	_prefetch.clear()
