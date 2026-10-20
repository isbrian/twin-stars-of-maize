extends Control
# 繪本的一頁（MV-SLICE-001d2b，移植自原型 book_page.gd）：插圖、左側底板、標題、正文、頁碼。

const Style := preload("res://ui/book_style.gd")
const BookText := preload("res://ui/book_text.gd")

var num := 1
var _text: VBoxContainer
var _folio: Label


func setup(n: int) -> void:
	num = n
	size = Vector2(Style.W, Style.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.texture = load(Style.art_path(n))  # 8 張都進版控（SLICE-d2b-10，test_book_art_present）
	tex.size = size
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tex)
	add_child(_panel())
	_text = VBoxContainer.new()
	_text.position = Vector2(Style.MARGIN_L, Style.TOP)
	_text.size = Vector2(Style.TEXT_W, 0)
	_text.add_theme_constant_override("separation", 0)
	add_child(_text)
	var page: Array = BookText.FRONT[n - 1]
	var body_size := Style.size_of("body")
	_add_label(page[0], "title", Style.INK)
	_gap(body_size * Style.TITLE_GAP)
	var paras: PackedStringArray = page[1].split("\n")
	for i in paras.size():
		_add_label(paras[i], "body", Style.INK)
		if i < paras.size() - 1:
			_gap(body_size * Style.PARA_GAP)
	_folio = Label.new()
	_folio.position = Vector2(Style.MARGIN_L, Style.H - Style.BOTTOM + 16)
	_folio.text = Style.FOLIO % [n, Style.TOTAL]
	_folio.label_settings = Style.label_settings("folio", Style.INK_SOFT)
	add_child(_folio)


## 文字最底部的 y（版面座標）；呼叫前要先讓容器排版（等一兩個 frame）
func text_bottom() -> float:
	return _text.position.y + _text.get_combined_minimum_size().y


func title_text() -> String:
	return (_text.get_child(0) as Label).text


func folio_text() -> String:
	return _folio.text


func _add_label(s: String, kind: String, color: Color) -> void:
	var l := Label.new()
	l.text = s
	l.language = "zh_TW"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Style.TEXT_W, 0)
	l.label_settings = Style.label_settings(kind, color)
	_text.add_child(l)


func _gap(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_text.add_child(c)


func _panel() -> TextureRect:
	var g := Gradient.new()
	var stop := float(Style.COL) / (Style.COL + Style.FADE)
	g.offsets = PackedFloat32Array([0.0, stop, 1.0])
	var clear := Style.PANEL
	clear.a = 0
	g.colors = PackedColorArray([Style.PANEL, Style.PANEL, clear])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = Style.COL + Style.FADE
	gt.height = 1
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(Style.COL + Style.FADE, Style.H)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
