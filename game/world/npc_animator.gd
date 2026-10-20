extends Node
# NPC 的骨架與動作（MV-SLICE-001b2b2）：祖母、老夫婦、老鼠（事件與技能）、Chimalmat 共用。
# 動作與面向由呼叫端決定（狀態本來就在各自的程式裡）；這裡只建骨架、累加時間、每幀擺姿勢。
# 循環動作照動作檔的 length 循環；非循環動作播完停在最後一格（rig_view.frame_in），有 then 就接著播 then。

const RigView := preload("res://world/rig_view.gd")

var rig: Node2D
var anim := ""
var t := 0.0
var facing := 1:  # ±1；骨架 scale.x＝facing × faces（設定時立刻套用：不在畫面內的區段可能不跑 _process）
	set(v):
		facing = v
		if rig != null:
			rig.scale.x = v * rig.faces
var _then := ""


## 在 node 底下建骨架（腳底對齊原點，同原本的立繪）與 animator，預設播 idle
static func attach(node: Node2D, char_id: String) -> Node:
	var a = new()
	a.name = "NpcAnimator"
	var r := RigView.new()
	r.name = "Rig"
	r.show_behind_parent = true
	node.add_child(r)
	r.build(char_id)
	a.rig = r
	node.add_child(a)
	a.play("idle")
	a._process(0.0)
	return a


## 換動作時從第 0 格開始；同一個動作重複呼叫不重來。then：非循環動作播完後接著播的動作
func play(name: String, then := "") -> void:
	_then = then
	if name == anim:
		return
	anim = name
	t = 0.0


## 動作一輪的長度：循環動作的 length，否則最後一格再停一格（同 rig_showcase.anim_length）
func length(name: String) -> float:
	var data := RigView.anims_at(rig.anims_path)
	var a: Dictionary = data.anims[name]
	return a.get("length", a.frames[-1].t + 1.0 / data.fps)


func _process(delta: float) -> void:
	t += delta
	var data := RigView.anims_at(rig.anims_path)
	if _then != "" and not data.anims[anim].get("loop", false) and t >= length(anim):
		var next := _then
		_then = ""
		play(next)
	rig.scale.x = facing * rig.faces
	rig.pose(anim, t)
