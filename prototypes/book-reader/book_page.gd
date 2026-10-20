extends Control
# 繪本的一頁：插圖（或素色底）、左側底板、標題、正文、「遊戲裡」、頁碼、缺圖標記。

const Style := preload("res://book_style.gd")

var volume := "front"
var num := 1
var art_missing := false
var _text: VBoxContainer
var _folio: Label
var _marker: Label


## art 可以傳入貼圖（測試用）；沒傳時讀 res://art/book_{volume}_{num}.png，不存在就用素色底
func setup(p_volume: String, p_num: int, art: Texture2D = null, art_path := "") -> void:
	volume = p_volume
	num = p_num
	size = Vector2(Style.W, Style.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art == null:
		var path := art_path if art_path != "" else "res://art/%s.png" % art_name()
		if ResourceLoader.exists(path):
			art = load(path)
	art_missing = art == null
	if art_missing:
		var bg := ColorRect.new()
		bg.color = Style.PLACEHOLDER[volume][num - 1]
		bg.size = size
		add_child(bg)
	else:
		var tex := TextureRect.new()
		tex.texture = art
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
	_folio = Label.new()
	_folio.position = Vector2(Style.MARGIN_L, Style.H - Style.BOTTOM + 16)
	add_child(_folio)
	_marker = Label.new()
	_marker.visible = art_missing
	add_child(_marker)
	refresh()


func art_name() -> String:
	return "book_%s_%02d" % [volume, num]


## 依目前語言重排所有文字（切換語言時呼叫）
func refresh() -> void:
	var lang := Style.lang_of(TranslationServer.get_locale())
	for c in _text.get_children():
		_text.remove_child(c)
		c.queue_free()
	var key := "BOOK_%s_%02d" % [volume.to_upper(), num]
	var body_size := Style.size_of(lang, "body")
	_add_label(tr(key + "_TITLE"), lang, "title", Style.INK)
	_gap(body_size * Style.TITLE_GAP)
	var paras := tr(key + "_BODY").split("\n")
	for i in paras.size():
		_add_label(paras[i], lang, "body", Style.INK)
		if i < paras.size() - 1:
			_gap(body_size * Style.PARA_GAP)
	var note := tr(key + "_NOTE")
	if note != key + "_NOTE":
		_gap(body_size * Style.NOTE_GAP / 2)
		var rule := ColorRect.new()
		rule.color = Style.RULE
		rule.custom_minimum_size = Vector2(Style.RULE_W, 1)
		rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_text.add_child(rule)
		_gap(body_size * Style.NOTE_GAP / 2 - 1)
		_add_label(tr("UI_NOTE_LABEL") + note, lang, "note", Style.INK_SOFT)
	var folio_key := "UI_FOLIO_FRONT" if volume == "front" else "UI_FOLIO_BACK"
	_folio.text = tr(folio_key) % [num, Style.TOTAL[volume]]
	_folio.label_settings = Style.label_settings(lang, "folio", Style.INK_SOFT)
	_marker.text = tr("UI_MISSING_ART") % art_name()
	_marker.label_settings = Style.label_settings(lang, "folio", Color(1, 1, 1, 0.5))
	_marker.reset_size()
	_marker.position = Vector2(Style.W - 40 - _marker.size.x, Style.H - 56)


## 文字最底部的 y（版面座標）；呼叫前要先讓容器排版（等一兩個 frame）
func text_bottom() -> float:
	return _text.position.y + _text.get_combined_minimum_size().y


func title_text() -> String:
	return (_text.get_child(0) as Label).text


func _add_label(s: String, lang: String, kind: String, color: Color) -> void:
	var l := Label.new()
	l.text = s
	l.language = "zh_TW" if lang == "zh" else "en"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Style.TEXT_W, 0)
	l.label_settings = Style.label_settings(lang, kind, color)
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
