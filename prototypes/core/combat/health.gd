extends RefCounted
# 血量、受擊無敵、治療次數的純邏輯（不依賴物理，--self-test 直接測）。

var max_hp: int
var hp: int
var invuln_left := 0.0
var heal_charges: int


func _init(p_max_hp: int, p_heal_charges: int = 0) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	heal_charges = p_heal_charges


## 扣血；回傳是否真的扣到（受擊無敵中或已死回傳 false）。ignore_invuln：掉坑等場地傷害
func take_damage(amount: int, invuln_after: float = 0.0, ignore_invuln: bool = false) -> bool:
	if hp <= 0 or (invuln_left > 0.0 and not ignore_invuln):
		return false
	hp = maxi(hp - amount, 0)
	invuln_left = maxf(invuln_left, invuln_after)
	return true


func tick(delta: float) -> void:
	invuln_left = maxf(invuln_left - delta, 0.0)


## 開始治療：按下就扣一次（PROTO1-6）；沒有次數、滿血、已死都不能開始
func begin_heal() -> bool:
	if heal_charges <= 0 or hp >= max_hp or hp <= 0:
		return false
	heal_charges -= 1
	return true


## 治療硬直結束時呼叫；回血不超過上限
func finish_heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


func is_dead() -> bool:
	return hp <= 0
