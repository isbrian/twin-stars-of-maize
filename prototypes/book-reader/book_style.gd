extends RefCounted
# ART_SPEC 第 15 節「排版」的數值；與 tools/book_layout.py 是同一組，改一邊要同步改另一邊。

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
const RULE := Color8(205, 191, 166, 110)
const RULE_W := 96

# 字級 px、行高倍數、字重
const STYLE := {
	"zh": {"title": [36, 1.35, 700], "body": [28, 1.65, 500], "note": [22, 1.55, 500], "folio": [20, 1.0, 500]},
	"en": {"title": [30, 1.25, 700], "body": [23, 1.45, 450], "note": [18, 1.35, 450], "folio": [18, 1.0, 450]},
}
const EN_WIDTH := 87.5    # Noto Serif 字寬軸：半窄體
const PARA_GAP := 0.6     # 段落間距（正文字級的倍數）
const TITLE_GAP := 0.9
const NOTE_GAP := 1.2
const FADE_TIME := 0.3    # 翻頁交叉淡入淡出（秒）

const TOTAL := {"front": 8, "back": 20}
const FONT_FILES := {"zh": "res://fonts/NotoSerifTC.ttf", "en": "res://fonts/NotoSerif.ttf"}

# 缺插圖時的素色底：依各張場景的區域辨識色（ART_SPEC 第 1 節），只是暫代
const PLACEHOLDER := {
	"front": [Color8(28, 46, 58), Color8(34, 58, 44), Color8(24, 28, 40), Color8(34, 58, 44),
		Color8(52, 44, 30), Color8(52, 44, 30), Color8(24, 28, 40), Color8(34, 58, 44)],
	"back": [Color8(34, 58, 44), Color8(52, 38, 28), Color8(30, 32, 46), Color8(14, 14, 16),
		Color8(30, 32, 46), Color8(30, 32, 46), Color8(30, 32, 46), Color8(34, 58, 44),
		Color8(52, 44, 30), Color8(58, 46, 30), Color8(56, 50, 44), Color8(56, 50, 44),
		Color8(52, 44, 30), Color8(30, 32, 46), Color8(22, 22, 26), Color8(44, 40, 34),
		Color8(16, 20, 34), Color8(30, 32, 46), Color8(58, 42, 26), Color8(40, 70, 100)],
}

static var _fonts := {}


static func lang_of(locale: String) -> String:
	return "zh" if locale.begins_with("zh") else "en"


static func size_of(lang: String, kind: String) -> int:
	return STYLE[lang][kind][0]


## 依語言與用途回傳設好字重（英文另設字寬）的字型；同一組合只建一次
static func font(lang: String, kind: String) -> FontVariation:
	var key := "%s/%s" % [lang, kind]
	if _fonts.has(key):
		return _fonts[key]
	var ts := TextServerManager.get_primary_interface()
	var fv := FontVariation.new()
	fv.base_font = load(FONT_FILES[lang])
	var axes := {ts.name_to_tag("wght"): float(STYLE[lang][kind][2])}
	if lang == "en":
		axes[ts.name_to_tag("wdth")] = EN_WIDTH
	fv.variation_opentype = axes
	_fonts[key] = fv
	return fv


## Label 的外觀：line_spacing ＝ 字級 × 行高倍數 − 字型自然行高
static func label_settings(lang: String, kind: String, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	var f := font(lang, kind)
	var size := size_of(lang, kind)
	ls.font = f
	ls.font_size = size
	ls.font_color = color
	ls.line_spacing = size * STYLE[lang][kind][1] - f.get_height(size)
	return ls
