extends RefCounted
# 繪本版面（MV-SLICE-001d2b）：ART_SPEC 第 15 節「排版」的繁中數值，自原型 prototypes/book-reader/book_style.gd 原樣搬來。
# 原型與 tools/book_layout.py 是同一組；改這裡要同步改那兩邊。只有前篇、只有繁中（SLICE-d2-3）。

const W := 1920
const H := 1080
const COL := 480          # 左側 1/4 直欄
const FADE := 64          # 底板右緣淡出寬度（480～544）
const PANEL := Color8(16, 13, 10, 165)
const MARGIN_L := 48
const MARGIN_R := 36
const TOP := 96
const BOTTOM := 72
const TEXT_W := COL - MARGIN_L - MARGIN_R
const TEXT_LIMIT := H - BOTTOM - 16   # 文字底部不能低於頁碼
const INK := Color8(242, 232, 213)
const INK_SOFT := Color8(205, 191, 166)

# 字級 px、行高倍數、字重
const STYLE := {"title": [36, 1.35, 700], "body": [28, 1.65, 500], "folio": [20, 1.0, 500]}
const PARA_GAP := 0.6     # 段落間距（正文字級的倍數）
const TITLE_GAP := 0.9
const FADE_TIME := 0.3    # 翻頁交叉淡入淡出（秒）

const TOTAL := 8
const FOLIO := "前篇 %d／%d"
const FONT_PATH := "res://art/fonts/NotoSerifTC_ui.ttf"  # 介面字型含繪本的字（SLICE-d2b-4）

static var _fonts := {}


static func art_path(n: int) -> String:
	return "res://art/book/book_front_%02d.webp" % n


static func size_of(kind: String) -> int:
	return STYLE[kind][0]


## 設好字重的字型；同一用途只建一次
static func font(kind: String) -> FontVariation:
	if _fonts.has(kind):
		return _fonts[kind]
	var fv := FontVariation.new()
	fv.base_font = load(FONT_PATH)
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(STYLE[kind][2])}
	_fonts[kind] = fv
	return fv


## Label 的外觀：line_spacing ＝ 字級 × 行高倍數 − 字型自然行高
static func label_settings(kind: String, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	var f := font(kind)
	var size := size_of(kind)
	ls.font = f
	ls.font_size = size
	ls.font_color = color
	ls.line_spacing = size * STYLE[kind][1] - f.get_height(size)
	return ls
