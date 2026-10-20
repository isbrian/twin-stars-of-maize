extends RefCounted
# 關節對照表（PROTO4-1）：讀 rig/{角色}_rig.json（MV-ASSET-010 起由 tools/cut_parts.py 產生）。
# 座標一律是該角色基準圖 chr_{角色}_reference.png 的像素（y 向下）；角度用弧度，0＝朝右、正值順時針。

const CHARS := ["hunahpu", "xbalanque"]
const PATH := "res://rig/hunahpu_rig.json"
const JOINTS := [
	"hip", "neck", "crown", "waist", "loin_tip",
	"shoulder_r", "elbow_r", "wrist_r", "hand_tip_r",
	"shoulder_l", "elbow_l", "wrist_l", "hand_tip_l",
	"hip_r", "knee_r", "ankle_r", "toe_r",
	"hip_l", "knee_l", "ankle_l", "toe_l",
]
## [骨頭, 父骨頭, 起點關節, 終點關節]；父骨頭排在前面；終點空字串＝固定朝下（骨盆）
const BONES := [
	["pelvis", "", "hip", ""],
	["spine", "pelvis", "hip", "neck"],
	["head", "spine", "neck", "crown"],
	["upperarm_l", "spine", "shoulder_l", "elbow_l"],
	["forearm_l", "upperarm_l", "elbow_l", "wrist_l"],
	["hand_l", "forearm_l", "wrist_l", "hand_tip_l"],
	["thigh_l", "pelvis", "hip_l", "knee_l"],
	["shin_l", "thigh_l", "knee_l", "ankle_l"],
	["foot_l", "shin_l", "ankle_l", "toe_l"],
	["loincloth", "pelvis", "waist", "loin_tip"],
	["thigh_r", "pelvis", "hip_r", "knee_r"],
	["shin_r", "thigh_r", "knee_r", "ankle_r"],
	["foot_r", "shin_r", "ankle_r", "toe_r"],
	["upperarm_r", "spine", "shoulder_r", "elbow_r"],
	["forearm_r", "upperarm_r", "elbow_r", "wrist_r"],
	["hand_r", "forearm_r", "wrist_r", "hand_tip_r"],
]

const PELVIS_LENGTH := 60.0
const WEAPON_LENGTH_RATIO := 0.4  # 握點到斧刃端＝身高 × 0.4（手柄全長約身高一半，握點距末端 1/5）
const OUTLIER := 0.15  # 縮放比例偏離中位數超過這個比例 → 列入補生成清單

var joints := {}
var parts := {}
var ref_size := Vector2.ZERO
var cid := "hunahpu"


static func path_for(c: String) -> String:
	return "res://rig/%s_rig.json" % c


## 分件全名：短名（例如 torso、hand_grip_r）＋角色；武器沒有角色前綴
func pn(short: String) -> String:
	return short if short.begins_with("wpn_") else "chr_%s_%s" % [cid, short]


func load_file(path := PATH) -> Error:
	cid = path.get_file().get_slice("_rig", 0)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ERR_FILE_NOT_FOUND
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	ref_size = v(d.reference.size)
	joints.clear()
	for j in d.reference.joints:
		joints[j] = v(d.reference.joints[j])
	parts = d.parts
	return OK


static func v(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


## 場景裡的分件節點名（避免和骨頭同名，例如骨頭 head、分件 head_art）
static func sprite_name(part: String) -> String:
	if part.begins_with("chr_"):
		return part.substr(part.find("_", 4) + 1) + "_art"
	return part.replace("wpn_", "") + "_art"


func bone_spec(name: String) -> Array:
	for b in BONES:
		if b[0] == name:
			return b
	return []


## 骨頭在基準圖上的靜止姿勢：起點、角度（弧度）、長度
func bone_global(name: String) -> Dictionary:
	var b := bone_spec(name)
	var a: Vector2 = joints[b[2]]
	if b[3] == "":
		return {"pos": a, "angle": PI / 2.0, "length": PELVIS_LENGTH}
	var c: Vector2 = joints[b[3]]
	return {"pos": a, "angle": (c - a).angle(), "length": a.distance_to(c)}


## 角色原點：髖中心正下方、最低的腳趾或腳踝高度
func ground() -> Vector2:
	var y := 0.0
	for j in ["ankle_r", "toe_r", "ankle_l", "toe_l"]:
		y = maxf(y, joints[j].y)
	return Vector2(joints.hip.x, y)


func body_height() -> float:
	return ground().y - joints.crown.y


func part_length(part: String) -> float:
	return v(parts[part].pivot).distance_to(v(parts[part].tip))


## 分件在基準圖上應有的長度：骨頭長度；斧頭依身高比例
func target_length(part: String) -> float:
	if part.begins_with("wpn_"):
		return body_height() * WEAPON_LENGTH_RATIO
	return bone_global(parts[part].bone).length


func part_scale(part: String) -> float:
	var p: Dictionary = parts[part]
	if p.has("scale_from"):
		return part_scale(p.scale_from)
	return target_length(part) / part_length(part)


## 分件一致性（問題 1）：每件的縮放比例與統計；scale_from 的分件沒出現在基準圖，不量
func consistency() -> Dictionary:
	var scales := {}
	var unmeasured := []
	for n in parts:
		if not n.begins_with("chr_"):
			continue
		if parts[n].has("scale_from"):
			unmeasured.append(n)
		else:
			scales[n] = part_scale(n)
	var vals: Array = scales.values()
	vals.sort()
	var m := vals.size()
	var median: float = vals[m / 2] if m % 2 == 1 else (vals[m / 2 - 1] + vals[m / 2]) / 2.0
	var mean := 0.0
	for s in vals:
		mean += s
	mean /= m
	var sq := 0.0
	for s in vals:
		sq += (s - mean) * (s - mean)
	var outliers := []
	for n in scales:
		if absf(scales[n] / median - 1.0) > OUTLIER:
			outliers.append(n)
	return {
		"scales": scales, "median": median, "min": vals[0], "max": vals[m - 1],
		"spread": vals[m - 1] / vals[0] - 1.0, "stdev_ratio": sqrt(sq / m) / mean,
		"outliers": outliers, "unmeasured": unmeasured,
	}
