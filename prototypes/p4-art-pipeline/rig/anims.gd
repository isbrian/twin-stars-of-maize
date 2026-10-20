extends RefCounted
# 三個動作（PROTO4-2）。角度一律是「全域角度」（度；0＝朝右、90＝朝下、-90＝朝上）；
# rel＝相對父骨頭的全域角度（例如小腿＝大腿角度＋膝彎）；mean 為 null＝用靜止姿勢的角度。
# 沒列出的骨頭維持靜止姿勢的全域角度（例如待機時腿不動）。
# 循環動作以正弦描述、12 fps 取樣；斧頭側攻四個姿勢對應 MV-PROTO-001 的出招 0.06、判定 0.08、收招 0.18 秒。
# 預設不內插（抄本平面感）；set_smooth() 切成線性內插對照。

const Rig := preload("res://rig/rig.gd")
const FPS := 12.0
const AXE_LENGTH := 0.32
const JOINT_RING := 14.0  # 穿幫檢查的取樣半徑（基準圖像素）
const JOINT_PAIRS := {  # 分件用短名，使用時以 rig.pn() 補上角色
	"neck": ["torso", "head"],
	"shoulder_r": ["torso", "upperarm_r"],
	"elbow_r": ["upperarm_r", "forearm_r"],
	"wrist_r": ["forearm_r", "hand_open_r", "hand_grip_r"],  # 兩種手勢依動作切換
	"shoulder_l": ["torso", "upperarm_l"],
	"elbow_l": ["upperarm_l", "forearm_l"],
	"wrist_l": ["forearm_l", "hand_grip_l"],
	"hip_r": ["torso", "thigh_r"],
	"knee_r": ["thigh_r", "shin_r"],
	"ankle_r": ["shin_r", "foot_r"],
	"hip_l": ["torso", "thigh_l"],
	"knee_l": ["thigh_l", "shin_l"],
	"ankle_l": ["shin_l", "foot_l"],
}

const CYCLES := {
	"idle": {"length": 1.0, "bob": 3.0, "bob_freq": 1.0, "bones": {
		"spine": {"amp": 2.0, "phase": 0.0, "mean": null, "rel": false},
		"head": {"amp": 1.5, "phase": 0.1, "mean": null, "rel": true},
		"upperarm_r": {"amp": 3.0, "phase": 0.05, "mean": null, "rel": true},
		"forearm_r": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"hand_r": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"upperarm_l": {"amp": 3.0, "phase": 0.05, "mean": null, "rel": true},
		"forearm_l": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"hand_l": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"loincloth": {"amp": 1.0, "phase": 0.2, "mean": null, "rel": true},
	}},
	"run": {"length": 0.5, "bob": 8.0, "bob_freq": 2.0, "bones": {
		"spine": {"amp": 2.0, "phase": 0.25, "mean": -78.0, "rel": false},
		"head": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"thigh_r": {"amp": 35.0, "phase": 0.0, "mean": 95.0, "rel": false},
		"shin_r": {"amp": 30.0, "phase": 0.75, "mean": 40.0, "rel": true},
		"foot_r": {"amp": 10.0, "phase": 0.0, "mean": null, "rel": true},
		"thigh_l": {"amp": 35.0, "phase": 0.5, "mean": 95.0, "rel": false},
		"shin_l": {"amp": 30.0, "phase": 0.25, "mean": 40.0, "rel": true},
		"foot_l": {"amp": 10.0, "phase": 0.5, "mean": null, "rel": true},
		"upperarm_r": {"amp": 30.0, "phase": 0.5, "mean": 95.0, "rel": false},
		"forearm_r": {"amp": 10.0, "phase": 0.5, "mean": -70.0, "rel": true},
		"hand_r": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"upperarm_l": {"amp": 30.0, "phase": 0.0, "mean": 95.0, "rel": false},
		"forearm_l": {"amp": 10.0, "phase": 0.0, "mean": -70.0, "rel": true},
		"hand_l": {"amp": 0.0, "phase": 0.0, "mean": null, "rel": true},
		"loincloth": {"amp": 6.0, "phase": 0.0, "mean": null, "rel": true},
	}},
}
## 武器只在攻擊時出現：斧頭側攻顯示近側握拳手＋斧頭，其他動作顯示近側張開手（規格：跑步時近側手張開）
const ARMED := ["hand_grip_r", "wpn_axe"]
const UNARMED := ["hand_open_r"]
## 斧頭側攻：[時間, 姿勢]；姿勢裡的值同上（amp 省略＝0）；空姿勢＝回到靜止
const AXE_POSES := [
	[0.0, {  # 出招：舉斧過肩、身體後仰
		"spine": {"mean": -95.0, "rel": false}, "head": {"mean": null, "rel": true},
		"upperarm_r": {"mean": -150.0, "rel": false}, "forearm_r": {"mean": -30.0, "rel": true}, "hand_r": {"mean": null, "rel": true},
		"upperarm_l": {"mean": 120.0, "rel": false}, "forearm_l": {"mean": -40.0, "rel": true}, "hand_l": {"mean": null, "rel": true},
	}],
	[0.06, {  # 判定：手臂揮到正前方、身體前傾
		"spine": {"mean": -75.0, "rel": false}, "head": {"mean": null, "rel": true},
		"upperarm_r": {"mean": 0.0, "rel": false}, "forearm_r": {"mean": 0.0, "rel": true}, "hand_r": {"mean": null, "rel": true},
		"upperarm_l": {"mean": 110.0, "rel": false}, "forearm_l": {"mean": -30.0, "rel": true}, "hand_l": {"mean": null, "rel": true},
	}],
	[0.14, {  # 收招：揮過頭往下
		"spine": {"mean": -72.0, "rel": false}, "head": {"mean": null, "rel": true},
		"upperarm_r": {"mean": 60.0, "rel": false}, "forearm_r": {"mean": 15.0, "rel": true}, "hand_r": {"mean": null, "rel": true},
		"upperarm_l": {"mean": 100.0, "rel": false}, "forearm_l": {"mean": -20.0, "rel": true}, "hand_l": {"mean": null, "rel": true},
	}],
	[AXE_LENGTH, {}],
]


## 一個影格各骨頭的區域旋轉（弧度）；u＝循環進度 0～1
static func frame_locals(rig, values: Dictionary, u: float) -> Dictionary:
	var glob := {}
	var locals := {}
	for b in Rig.BONES:
		var name: String = b[0]
		var parent_g: float = glob[b[1]] if b[1] != "" else 0.0
		var rest_g: float = rig.bone_global(name).angle
		var rest_parent_g: float = rig.bone_global(b[1]).angle if b[1] != "" else 0.0
		var g := rest_g
		if values.has(name):
			var spec: Dictionary = values[name]
			var wave := deg_to_rad(spec.get("amp", 0.0) * sin(TAU * (u + spec.get("phase", 0.0))))
			if spec.rel:
				var base_rel: float = (rest_g - rest_parent_g) if spec.mean == null else deg_to_rad(spec.mean)
				g = parent_g + base_rel + wave
			else:
				var base_abs: float = rest_g if spec.mean == null else deg_to_rad(spec.mean)
				g = base_abs + wave
		glob[name] = g
		locals[name] = g - parent_g
	return locals


static func make_library(rig, bones: Dictionary, root: Node) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for name in CYCLES:
		var c: Dictionary = CYCLES[name]
		var a := _new_anim(c.length, true, bones, root)
		var n := int(round(c.length * FPS))
		for i in n + 1:
			var u := float(i) / n
			_key(a, bones, i * c.length / n, frame_locals(rig, c.bones, u), c.bob * sin(TAU * u * c.bob_freq))
		_show(a, rig, bones, root, false)
		lib.add_animation(name, a)
	var axe := _new_anim(AXE_LENGTH, false, bones, root)
	for pose in AXE_POSES:
		_key(axe, bones, pose[0], frame_locals(rig, pose[1], 0.0), 0.0)
	_show(axe, rig, bones, root, true)
	lib.add_animation("axe_side", axe)
	return lib


static func set_smooth(ap: AnimationPlayer, smooth: bool) -> void:
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR if smooth else Animation.INTERPOLATION_NEAREST)


## 軌道順序：每根骨頭一條旋轉軌（依 BONES 順序），最後一條是骨盆位置（上下起伏）
static func _new_anim(length: float, loop: bool, bones: Dictionary, root: Node) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for b in Rig.BONES:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath(_path(root, bones[b[0]]) + ":rotation"))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
	var p := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(p, NodePath(_path(root, bones["pelvis"]) + ":position"))
	a.track_set_interpolation_type(p, Animation.INTERPOLATION_NEAREST)
	return a


static func _key(a: Animation, bones: Dictionary, time: float, locals: Dictionary, bob: float) -> void:
	for i in Rig.BONES.size():
		var value: float = locals[Rig.BONES[i][0]]
		var count := a.track_get_key_count(i)
		if count > 0:  # 展開角度：和前一個關鍵影格相差不超過半圈，平滑內插才不會繞遠路
			var prev: float = a.track_get_key_value(i, count - 1)
			value = prev + wrapf(value - prev, -PI, PI)
		a.track_insert_key(i, time, value)
	var rest: Vector2 = bones["pelvis"].rest.origin
	a.track_insert_key(Rig.BONES.size(), time, rest + Vector2(0, -absf(bob)))


## 顯示軌（排在旋轉軌與骨盆位置軌之後）；離散更新，不受內插切換影響
static func _show(a: Animation, rig, bones: Dictionary, root: Node, armed: bool) -> void:
	for short in ARMED + UNARMED:
		var part: String = rig.pn(short)
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath(_path(root, bones[rig.parts[part].bone]) + "/" + Rig.sprite_name(part) + ":visible"))
		a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
		a.track_insert_key(t, 0.0, (short in ARMED) == armed)


static func _path(root: Node, node: Node) -> String:
	var names := PackedStringArray()
	var n := node
	while n != root:
		names.insert(0, n.name)
		n = n.get_parent()
	return "/".join(names)
