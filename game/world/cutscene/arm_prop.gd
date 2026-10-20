extends Node2D
# 胡納普被扯下的手臂（MV-SLICE-001c2a）：他自己的骨架擺 idle，只留近側手臂一組（NearArm＝upperarm_r 以下）的分件；
# 原點在肩膀（upperarm_r 的起點關節）、往下垂。不用新美術：剪影時叼在 Seven Macaw 嘴上，之後掛在宮殿火堆上方的繩子上（c2c 取回）。

const RigView := preload("res://world/rig_view.gd")
const ROOT_BONE := "upperarm_r"

var rig: Node2D


static func make() -> Node2D:
	var p = new()
	p.name = "ArmProp"
	p.rig = RigView.new()
	p.add_child(p.rig)
	p.rig.build("hunahpu")
	p.rig.pose("idle", 0.0)
	for s in p.rig.find_children("*", "Sprite2D", true, false):
		s.visible = s.visible and s.get_parent().name == "NearArm"
	for b in p.rig.bone_table:
		if b[0] == ROOT_BONE:
			p.rig.position = -p.rig.joints[b[2]]
	return p
