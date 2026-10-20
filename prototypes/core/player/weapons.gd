extends RefCounted
# 三種近戰武器的動作資料（MV-PROTO-002 規格書第 3、4 節）。player.gd 依目前角色的武器槽讀取。
# 球具的側攻、上攻是招架（不傷人）；下劈仍會彈跳，但傷害 0。

enum Weapon { AXE, STICK, BALLGEAR }
enum Dir { SIDE, UP, DOWN }  # 值與 player.gd 的 AttackDir 相同

const NAMES := ["斧頭", "掘棒", "球具"]


## x 出招、y 判定、z 收招（秒）；球具的下劈用斧頭的時間
static func timing(w: int, tn) -> Vector3:
	if w == Weapon.STICK:
		return Vector3(tn.stick_startup, tn.stick_active, tn.stick_recovery)
	return Vector3(tn.axe_startup, tn.axe_active, tn.axe_recovery)


static func box(w: int, dir: int, tn) -> Vector2:
	match w:
		Weapon.STICK:
			return [tn.stick_side_box, tn.stick_up_box, tn.stick_down_box][dir]
		Weapon.BALLGEAR:
			return tn.ballgear_down_box
	return [tn.axe_side_box, tn.axe_up_box, tn.axe_down_box][dir]


## 側攻判定框中心的高度（角色身高的比例，從腳底往上）：掘棒的突刺放低，才戳得到爬行型與落地的飛行型
static func side_height(w: int) -> float:
	return 0.3 if w == Weapon.STICK else 0.55


static func damage(w: int, tn) -> int:
	match w:
		Weapon.STICK:
			return tn.stick_damage
		Weapon.BALLGEAR:
			return 0
	return tn.axe_damage


static func is_parry(w: int, dir: int) -> bool:
	return w == Weapon.BALLGEAR and dir != Dir.DOWN
