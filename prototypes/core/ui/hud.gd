extends Control
# 灰盒 HUD：血量（方塊）、治療次數（圓點）、兩兄弟與各自的武器（MV-PROTO-002）、除錯鍵提示；
# MV-PROTO-003：Boss 名稱、三段血條、破綻條（boss_name 空字串時不畫）。

const Weapons := preload("res://player/weapons.gd")

var player
var show_hint := true  # Boss 戰不顯示除錯鍵（不告訴外人）
var boss_name := ""
var boss_segments := 3
var boss_gauge := 0.0  # 0～1
var notice := ""  # 畫面下方的短提示（例：再按一次回選單）


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.health == null:
		return
	var h = player.health
	for i in h.max_hp:
		draw_rect(Rect2(40 + i * 46, 40, 36, 36), Color(0.95, 0.9, 0.8) if i < h.hp else Color(0.3, 0.3, 0.3))
	for i in player.tn.heal_charges:
		draw_circle(Vector2(58 + i * 46, 104), 14.0, Color(0.5, 0.9, 0.6) if i < h.heal_charges else Color(0.25, 0.3, 0.27))
	var lines := twin_lines()
	for i in lines.size():
		var current: bool = i == player.twin_index
		draw_string(ThemeDB.fallback_font, Vector2(40, 160 + i * 36), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.95 if current else 0.4))
	if boss_name != "":
		_draw_boss()
	if notice != "":
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 160), notice, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.9))
	if show_hint:
		draw_string(ThemeDB.fallback_font, Vector2(40, 1050), "Tab／Y 換人　1／2／3 換武器　F9 存回數值並印出數值表與招架紀錄　F10 重置房間", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))


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
	draw_string(font, Vector2(0, y), boss_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.95, 0.9, 0.8))
	var left := size.x / 2.0 - 465.0
	for i in 3:
		draw_rect(Rect2(left + i * 315.0, y + 18, 300, 18), Color(0.95, 0.8, 0.35) if i < boss_segments else Color(0.25, 0.25, 0.25))
	draw_rect(Rect2(left, y + 44, 930, 10), Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(left, y + 44, 930 * clampf(boss_gauge, 0.0, 1.0), 10), Color.WHITE if boss_gauge >= 1.0 else Color(0.85, 0.75, 0.5))
