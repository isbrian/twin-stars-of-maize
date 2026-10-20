extends RefCounted
# 兩兄弟的角色資料（MV-PROTO-002 規格書第 1 節）。場上只有一個身體，換人只切換這份資料；
# 跑速、跳躍等基礎數值兩人相同，差別只在武器與專屬能力。

const Weapons := preload("res://player/weapons.gd")

var display_name: String
var color: Color
var weapon: int
var default_weapon: int
var can_double_jump := false
var can_send_tool := false
var weapon_enabled := true  # 斷臂時 false（MV-PROTO-003 BOSS-2）
var can_trigger_setup := false  # 只有 Hunahpu 的吹箭能觸發設局（BOSS-6-3a）


static func hunahpu():
	var t = new()
	t.display_name = "胡納普"  # MV-NAME-001 H01
	t.color = Color(0.85, 0.55, 0.25)  # 暖色（ART-8）
	t.default_weapon = Weapons.Weapon.AXE
	t.weapon = t.default_weapon
	t.can_double_jump = true
	t.can_trigger_setup = true
	return t


static func xbalanque():
	var t = new()
	t.display_name = "希巴拉克"  # MV-NAME-001 H02
	t.color = Color(0.25, 0.65, 0.7)  # 冷色
	t.default_weapon = Weapons.Weapon.BALLGEAR
	t.weapon = t.default_weapon
	t.can_send_tool = true
	return t
