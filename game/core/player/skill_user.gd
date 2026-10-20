extends Node
# 動物技能的發動（MV-SLICE-001a 規格「動物技能」）：掛在角色下（Loadout 加上，節點名 SkillUser）。
# 角色按技能鍵 → 槽裡是老鼠、在地上且可自由行動、資源夠 → 扣資源、放出老鼠；資源不夠 → denied（HUD 閃一下）。
# 不在地上或正在攻擊、翻滾等：按了沒反應、也不扣資源。

const Rat := preload("res://core/player/rat.gd")
const RatTarget := preload("res://core/player/rat_target.gd")

signal denied
signal used(slot: int)

var gs
var player


func _ready() -> void:
	player = get_parent()
	player.skill_pressed.connect(_on_skill)


func _on_skill(slot: int) -> void:
	if gs.skill_slots[slot] != "rat":
		return
	if not player.is_on_floor() or player.state != player.State.FREE:
		return
	if not gs.use_skill(player.tn.skill_cost):
		denied.emit()
		return
	var tn = player.tn
	var target := RatTarget.pick(player.global_position, player.facing, get_tree().get_nodes_in_group("enemy"), tn.rat_range, tn.rat_max_dy)
	var r := Rat.new()
	r.tn = tn
	player.get_parent().add_child(r)
	r.launch(player.global_position, player.facing, target, player)
	used.emit(slot)
