extends Control
# HUD：血量、治療次數、兩兄弟與各自的武器（MV-PROTO-002）、除錯鍵提示；
# MV-PROTO-003：Boss 名稱、三段血條、破綻條（boss_name 空字串時不畫）。
# MV-SLICE-001b1（SLICE-b8）：版面同 a，色塊換成素材；Boss 的條維持程式繪製、改用色盤配色（不用紅色）。

const Weapons := preload("res://core/player/weapons.gd")
const TEXTURES := {
	"health_full": preload("res://art/ui/ui_health_pip_full.png"),
	"health_empty": preload("res://art/ui/ui_health_pip_empty.png"),
	"health_half": preload("res://art/ui/ui_health_pip_half.png"),  # MV-ASSET-017 C-03
	"heal_full": preload("res://art/ui/ui_heal_pip_full.png"),
	"heal_empty": preload("res://art/ui/ui_heal_pip_empty.png"),
	"res_frame": preload("res://art/ui/ui_resource_frame.png"),
	"res_fill": preload("res://art/ui/ui_resource_fill.png"),
	"skill_frame": preload("res://art/ui/ui_skill_slot_frame.png"),
	"rat": preload("res://art/ui/ui_icon_rat.png"),
	"cacao": preload("res://art/ui/ui_icon_cacao.png"),
	"soup": preload("res://art/ui/ui_icon_soup.png"),
}
const WEAPON_ICONS := [  # 依 Weapons.Weapon 的順序
	preload("res://art/ui/ui_icon_axe.png"),
	preload("res://art/ui/ui_icon_digging_stick.png"),
	preload("res://art/ui/ui_icon_ballgear.png"),
]
# 色盤（ART_SPEC 第 15 節的文字色與底板色＋HUD 素材上的金與玉綠）
const TEXT := Color8(242, 232, 213)  # #F2E8D5
const MUTED := Color8(205, 191, 166)  # #CDBFA6
const GOLD := Color8(220, 159, 71)
const JADE := Color8(71, 150, 102)
const DARK := Color8(16, 13, 10)  # #100D0A
const SPENT := Color8(60, 52, 44)
const ROW := 46  # 圖示間距（同 a 的方塊）
const RES_CELL := Vector2(40, 20)  # 資源條每格的大小（填色圖縮放）

var player
var show_hint := true  # Boss 戰不顯示除錯鍵（不告訴外人）
var boss_name := ""
var boss_segments := 3
var boss_gauge := 0.0  # 0～1
var notice := ""  # 畫面下方的短提示（例：再按一次回選單）
var gs  # MV-SLICE-001a：GameState（可可豆、熱湯、技能資源）；null 時不畫
var show_objective := true  # Boss 段落關掉（那裡的目標就是眼前的 Boss）
var _skill_flash_left := 0.0
const SKILL_FLASH_TIME := 0.3


func _process(delta: float) -> void:
	_skill_flash_left = maxf(_skill_flash_left - delta, 0.0)
	queue_redraw()


func half_heart() -> bool:
	return gs != null and gs.fragments() % 2 == 1


func _draw() -> void:
	if player == null or player.health == null:
		return
	var font := ThemeDB.fallback_font
	var t := TEXTURES
	var h = player.health
	for i in h.max_hp:
		draw_texture(t.health_full if i < h.hp else t.health_empty, Vector2(40 + i * ROW, 40))
	if half_heart():  # 血量碎片湊一半（MV-SLICE-001c4a）：一格的左半片
		draw_texture(t.health_half, Vector2(40 + h.max_hp * ROW, 40))
	for i in player.tn.heal_charges:
		draw_texture(t.heal_full if i < h.heal_charges else t.heal_empty, Vector2(44 + i * ROW, 88))
	if gs != null:  # 熱湯接在治療圖示後面
		var sx: float = 44.0 + player.tn.heal_charges * ROW + 10.0
		draw_texture(t.soup, Vector2(sx, 88))
		draw_string(font, Vector2(sx + 38, 114), "%d／%d" % [gs.soup, gs.tn.soup_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEXT)
	for i in player.twins.size():  # 名字＋武器圖示（斷臂、沒有武器顯示「—」）；場上的人較亮
		var tw = player.twins[i]
		var c := Color(TEXT, 0.95 if i == player.twin_index else 0.4)
		var y: float = 160.0 + i * 46.0
		draw_string(font, Vector2(40, y), tw.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, c)
		var x := 40.0 + font.get_string_size(tw.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 14.0
		var icon := weapon_icon(tw.weapon) if tw.weapon_enabled else null
		if icon != null:
			draw_texture(icon, Vector2(x, y - 30), Color(1, 1, 1, c.a))
		else:
			draw_string(font, Vector2(x, y), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, c)
	if gs != null:
		draw_texture(t.cacao, Vector2(40, 228))
		draw_string(font, Vector2(88, 254), str(gs.cacao), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEXT)
		if gs.skill_slots[0] != "":
			_draw_skill(Vector2(40, 276))
		if show_objective and objective_line() != "":
			draw_string(font, Vector2(40, 390), objective_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(TEXT, 0.9))
	if boss_name != "":
		_draw_boss()
	if notice != "":
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 160), notice, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.9))
	if show_hint:
		draw_string(ThemeDB.fallback_font, Vector2(40, 1050), "Tab／Y 換人　1／2／3 換武器　F9 存回數值並印出數值表與招架紀錄　F10 重置房間", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))


## 武器的 HUD 圖示（Weapons.Weapon；-1＝沒有武器 → null）
static func weapon_icon(w: int) -> Texture2D:
	if w < 0 or w >= WEAPON_ICONS.size():
		return null
	return WEAPON_ICONS[w]


func pip_textures() -> Dictionary:
	return TEXTURES


## 技能槽外框＋動物圖示；右邊 3 格資源條（外框＋填色，空格調暗）；資源不夠時整組閃紅（同 a）
func _draw_skill(at: Vector2) -> void:
	var t := TEXTURES
	var flash := Color(1, 0.4, 0.4) if skill_flashing() else Color.WHITE
	var frame: Texture2D = t.skill_frame
	draw_texture(frame, at, flash)
	var icon: Texture2D = t.rat
	var k := minf((frame.get_width() - 14.0) / icon.get_width(), (frame.get_height() - 14.0) / icon.get_height())
	var isz := icon.get_size() * k
	draw_texture_rect(icon, Rect2(at + (frame.get_size() - isz) / 2.0, isz), false)
	var n: int = gs.tn.skill_max
	var bar := Vector2(at.x + frame.get_width() + 12.0, at.y + frame.get_height() / 2.0 - 14.0)
	draw_texture_rect(t.res_frame, Rect2(bar, Vector2(n * (RES_CELL.x + 2.0) + 12.0, 28)), false, flash)
	for i in n:
		var full: bool = i < gs.skill_res
		draw_texture_rect(t.res_fill, Rect2(bar + Vector2(6.0 + i * (RES_CELL.x + 2.0), 4), RES_CELL), false, flash if full else flash * Color(0.35, 0.35, 0.35))


## MV-SLICE-001a：可可豆與熱湯
func status_line() -> String:
	return "可可豆 %d　熱湯 %d／%d" % [gs.cacao, gs.soup, gs.tn.soup_max]


## 目前該做什麼（手把驗收第 1 輪，Brian 2026-10-09：地面開頭每一步都有）；覺醒後不顯示
func objective_line() -> String:
	if gs.awakened:
		return ""
	if not gs.has_flag("tools_obtained"):
		return "目標：到左邊的田地拿工具"
	if not gs.has_flag("field_cleared"):
		return "目標：清理田地——灌木用斧頭（胡納普）、土塊用掘棒（希巴拉克）"
	if not gs.has_flag("rat_caught"):
		return "目標：在田地把老鼠逼到左右的牆角"
	if not gs.has_flag("gear_obtained"):
		return "目標：回祖母家"
	return "目標：往右穿過森林"


## MV-SLICE-001a：技能槽 1 的動物與技能資源（● 有、○ 空）
func skill_line() -> String:
	var names := {"rat": "老鼠"}
	var pips := ""
	for i in gs.tn.skill_max:
		pips += "●" if i < gs.skill_res else "○"
	return "%s　%s" % [names.get(gs.skill_slots[0], ""), pips]


## 資源不足時由 skill_user.denied 呼叫
func flash_skill() -> void:
	_skill_flash_left = SKILL_FLASH_TIME


func skill_flashing() -> bool:
	return _skill_flash_left > 0.0


## 兩兄弟各一行：名稱與武器（場上的人在繪製時亮色）
func twin_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if player == null:
		return out
	for t in player.twins:
		out.append("%s　%s" % [t.display_name, Weapons.NAMES[t.weapon] if t.weapon_enabled else "—"])  # 斷臂顯示「—」（計畫 D20）
	return out


## 畫面底部中央（不壓住樹冠上的 Boss）：名稱、三格血條（打掉的變暗）、破綻條（滿時白色）
func _draw_boss() -> void:
	var font := ThemeDB.fallback_font
	var y := size.y - 100.0
	draw_string(font, Vector2(0, y), boss_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, TEXT)
	var left := size.x / 2.0 - 465.0
	for i in 3:
		draw_rect(Rect2(left + i * 315.0, y + 18, 300, 18), GOLD if i < boss_segments else SPENT)
	draw_rect(Rect2(left, y + 44, 930, 10), DARK)
	draw_rect(Rect2(left, y + 44, 930 * clampf(boss_gauge, 0.0, 1.0), 10), TEXT if boss_gauge >= 1.0 else JADE)
