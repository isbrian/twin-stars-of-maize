extends Node2D
# 骨架（MV-SLICE-001b2a，SLICE-b2a-8；b2b1 改成資料驅動）：執行時依 game/rig/{角色}_rig.json 組出 Skeleton2D／Bone2D／分件 Sprite2D，
# 不產生 .tscn。骨頭表（bones、root_length）、原點（origin）、動作檔（anims）、是否人形（humanoid）都在資料裡；
# 人形（雙胞胎）才有肩膀收邊、手勢、近側手臂分組、吹射覆寫與武器附件。骨頭只管位置；分件攤平在同一層（Parts），依資料的 z 排好節點順序、z_index 一律 0，
# 每次擺姿勢後同步到骨頭上——整副骨架和 b1 的立繪一樣跟玩家同一層、依樹順序排前後（最終審查 Important 2）。
# 原點：x＝origin.x_joint 的 x（雙胞胎是髖中心）、y＝靜止姿勢下 origin.sole_parts 最低的不透明像素
# （雙胞胎是腳底；p4 的 ground 是腳踝與腳趾關節，腳的圖還有 3～4 px 的鞋底厚度，會陷進地板）。面向用整副骨架的 scale.x 翻轉。
# 座標是遊戲像素（tools/import_rig.py 從 p4 換算）；角度用弧度，0＝朝右、正值順時針。
# _r＝近側（基準圖上看得到）、_l＝遠側。

const RIG_PATH := "res://rig/%s_rig.json"
const PART_PATH := "res://art/chr/parts/%s/%s.png"
const ANIMS_PATH := "res://rig/twin_anims.json"
const ATTACH_PATH := "res://rig/attachments.json"
const Weapons := preload("res://core/player/weapons.gd")
## 關節 → 兩側分件的短名（覆蓋檢查用）。同 p4 anims.gd
const JOINT_PAIRS := {
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
const HEAD_LIMIT := PI / 4.0  # 吹射時頭轉動的上限（Review Focus 3）
const DART_BONES := ["head", "upperarm_r", "forearm_r", "hand_r", "upperarm_l", "forearm_l", "hand_l"]
const HELD := ["wpn_axe", "wpn_digging_stick"]  # 握在近側手上的武器（球具是穿的）
const CAP_RADIUS := 7  # 斷臂收邊圓盤的半徑（遊戲像素）
const CAP_OUTLINE := Color(0.16, 0.1, 0.07)
## 武器 → 顯示的附件；球具＝穿上護腰護手、手張開
const WEAPON_GEAR := {
	Weapons.Weapon.AXE: ["wpn_axe"],
	Weapons.Weapon.STICK: ["wpn_digging_stick"],
	Weapons.Weapon.BALLGEAR: ["wpn_ballgear_yoke", "wpn_ballgear_armguard"],
}

static var _anims_cache: Dictionary = {}  # 動作檔路徑 → 內容
static var _attach_cache: Dictionary = {}

var cid := ""
var faces := 1  # 資料的 faces：基準圖面向（−1＝面向左，R5）；animator 設 scale.x＝面向×faces
var humanoid := false  # 資料的 humanoid：肩膀收邊、手勢、NearArm、吹射覆寫、武器附件只給人形
var anims_path := ANIMS_PATH  # 這副骨架的動作檔（資料的 anims）
var bone_table: Array = []  # 資料的 bones：[骨頭, 父骨頭, 起點關節, 終點關節]；父骨頭排在前面；終點空字串＝固定朝下（用 root_length）
var root_length := 0.0  # 終點空字串的骨頭（骨盆）的長度，遊戲像素
var joints := {}  # 遊戲像素、以腳底為原點
var points := {}  # 資料的 points：光點名 → {bone, at}（at＝骨頭座標：x 沿骨頭、遊戲像素）
var weapon := -1
var _bones := {}  # 名稱 → Bone2D
var _sprites := {}  # 分件短名或附件名 → Sprite2D
var _bone_of := {}  # 分件短名或附件名 → 掛的骨頭
var _local := {}  # 分件短名或附件名 → 相對骨頭的變換
var _arm: Node2D  # 近側上臂以下的分件（斷臂時整組隱藏）


static func anims_at(path: String) -> Dictionary:
	if not _anims_cache.has(path):
		_anims_cache[path] = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _anims_cache[path]


## 雙胞胎的動作檔（舊呼叫端的捷徑）
static func anims() -> Dictionary:
	return anims_at(ANIMS_PATH)


static func attachments() -> Dictionary:
	if _attach_cache.is_empty():
		_attach_cache = JSON.parse_string(FileAccess.get_file_as_string(ATTACH_PATH))
	return _attach_cache


static func v(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


func build(char_id: String) -> void:
	cid = char_id
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH % cid))
	humanoid = d.get("humanoid", false)
	faces = int(d.get("faces", 1))
	anims_path = d.get("anims", ANIMS_PATH)
	bone_table = d.bones
	root_length = d.root_length
	points = d.get("points", {})
	var raw := {}
	for j in d.reference.joints:
		raw[j] = v(d.reference.joints[j])
	var g := Vector2(raw[d.origin.x_joint].x, 0.0)  # y 之後由 origin.sole_parts 的最低像素定
	for j in raw:
		joints[j] = raw[j] - g
	var sk := Skeleton2D.new()
	sk.name = "Skeleton"
	add_child(sk)
	for b in bone_table:
		var bone := Bone2D.new()
		bone.name = b[0]
		var gl := _rest_global(b)
		var parent: Node = sk
		var parent_xf := Transform2D.IDENTITY
		if b[1] != "":
			parent = _bones[b[1]]
			var pg := _rest_global(_spec(b[1]))
			parent_xf = Transform2D(pg.angle, pg.pos)
		bone.transform = parent_xf.affine_inverse() * Transform2D(gl.angle, gl.pos)
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(gl.length)
		bone.set_bone_angle(0.0)
		bone.rest = bone.transform
		parent.add_child(bone)
		_bones[b[0]] = bone
	for part in d.parts:
		var p: Dictionary = d.parts[part]
		var short: String = part.substr(("chr_%s_" % cid).length())
		var pivot := v(p.pivot)
		var tip := v(p.tip)
		var k: float = _bones[p.bone].get_length() / pivot.distance_to(tip)
		var s := _sprite(short, load(PART_PATH % [cid, short]), pivot, -(tip - pivot).angle(), int(p.get("z", 0)))
		s.scale = Vector2(k, k)
		s.visible = p.get("visible", true)
		_bones[p.bone].add_child(s)
	if humanoid:
		_add_shoulder_cap()
		_sprites.hand_grip_l.visible = true  # 遠側手一律握拳（p4 沒有用到遠側手；動作裡手臂會擺到軀幹外）
		var att := attachments()
		for n in att:
			var a: Dictionary = att[n]
			var pivot := v(a.pivot)
			var s := _sprite(n, load(a.tex), pivot, -(v(a.tip) - pivot).angle() + deg_to_rad(a.angle_deg), int(a.z))
			s.position = Vector2(_bones[a.bone].get_length() * a.get("at", 0.0), 0.0)
			s.visible = false
			_bones[a.bone].add_child(s)
		set_weapon(-1)
	var sole := _sole_y(d.origin.sole_parts)
	sk.position.y -= sole
	for j in joints:
		joints[j].y -= sole
	_flatten()
	_sync()


## 把掛在骨頭上的分件搬到同一層：依 z、同 z 照原本的樹順序排；近側上臂以下的放進 _arm 一組
func _flatten() -> void:
	var order := []
	_collect(get_node("Skeleton"), order)
	var keyed := []
	for i in order.size():
		keyed.append([order[i].z_index, i, order[i]])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var parts := Node2D.new()
	parts.name = "Parts"
	add_child(parts)
	var arm_root: Bone2D = null
	if humanoid:
		_arm = Node2D.new()
		_arm.name = "NearArm"
		arm_root = _bones.upperarm_r
	for k in keyed:
		var s: Sprite2D = k[2]
		var b: Bone2D = s.get_parent()
		_bone_of[s.name] = b
		_local[s.name] = s.transform
		b.remove_child(s)
		s.z_index = 0
		if arm_root != null and (b == arm_root or arm_root.is_ancestor_of(b)):
			if _arm.get_parent() == null:
				parts.add_child(_arm)
			_arm.add_child(s)
		else:
			parts.add_child(s)


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Sprite2D:
			out.append(c)
		else:
			_collect(c, out)


## 分件跟到骨頭目前的位置（骨架座標）
func _sync() -> void:
	for n in _sprites:
		_sprites[n].transform = _rig_xf(_bone_of[n]) * _local[n]


## 骨頭在骨架座標的變換（往上乘到本節點為止；不需要在場景樹裡）
func _rig_xf(b: Node2D) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var n: Node = b
	while n != self:
		xf = n.transform * xf
		n = n.get_parent()
	return xf


## 靜止姿勢下 names 這幾個分件最低的不透明像素（y，骨架座標）
func _sole_y(names: Array) -> float:
	var y := -INF
	for n in names:
		var s: Sprite2D = _sprites[n]
		var img := s.texture.get_image()
		var xf := get_global_transform().affine_inverse() * s.get_global_transform()
		for py in img.get_height():
			for px in img.get_width():
				if img.get_pixel(px, py).a > 0.5:
					y = maxf(y, (xf * (Vector2(px + 1, py + 1) + s.offset)).y)
	return y


## 斷臂的肩膀收邊（規格「風險與退路」：膚色圓盤）：近側上臂的膚色＋輪廓，掛在脊椎、畫在軀幹後面，
## 從肩關節往上臂方向偏 4 px、往前（胸口）偏 2 px，填住上臂原本蓋著的缺口（披肩下緣的碎片接上皮膚）
func _add_shoulder_cap() -> void:
	var arm: Sprite2D = _sprites.upperarm_r
	var src := arm.texture.get_image()
	var skin := Color(0, 0, 0, 0)
	var n := 0
	for y in src.get_height():
		for x in src.get_width():
			var px := src.get_pixel(x, y)
			if px.a > 0.9 and px.get_luminance() > 0.35:
				skin += px
				n += 1
	skin = skin / maxi(n, 1)
	skin.a = 1.0
	var size := CAP_RADIUS * 2 + 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= CAP_RADIUS - 1:
				img.set_pixel(x, y, skin)
			elif d <= CAP_RADIUS:
				img.set_pixel(x, y, CAP_OUTLINE)
	var ua: Bone2D = _bones.upperarm_r
	var s := _sprite("shoulder_cap", ImageTexture.create_from_image(img), c, 0.0, -1)
	var spine_angle: float = _bones.pelvis.rest.get_rotation() + _bones.spine.rest.get_rotation()
	s.position = ua.position + Vector2.from_angle(ua.rotation) * 4.0 + Vector2(2, 0).rotated(-spine_angle)
	s.visible = false
	_bones.spine.add_child(s)


func _sprite(n: String, tex: Texture2D, pivot: Vector2, rot: float, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = tex
	s.centered = false
	s.offset = -pivot  # 軸心對齊骨頭原點
	s.rotation = rot  # 主軸轉到骨頭方向
	s.z_index = z
	_sprites[n] = s
	return s


func _spec(name: String) -> Array:
	for b in bone_table:
		if b[0] == name:
			return b
	return []


## 骨頭在基準圖上的靜止姿勢（以腳底為原點）：起點、角度、長度
func _rest_global(b: Array) -> Dictionary:
	var a: Vector2 = joints[b[2]]
	if b[3] == "":
		return {"pos": a, "angle": PI / 2.0, "length": root_length}
	var c: Vector2 = joints[b[3]]
	return {"pos": a, "angle": (c - a).angle(), "length": a.distance_to(c)}


## 時間 t 的影格：取 t ≤ 目前時間的最後一格，不內插（SLICE-b2a-3）；循環動作先對長度取餘數
## （長度＝length，沒寫就是最後一格＋1/fps）；非循環動作停在最後一格
static func frame_in(path: String, anim: String, t: float) -> Dictionary:
	var data := anims_at(path)
	var a: Dictionary = data.anims[anim]
	var frames: Array = a.frames
	if a.get("loop", false):
		t = fposmod(t, a.get("length", frames[-1].t + 1.0 / data.fps))
	var f: Dictionary = frames[0]
	for fr in frames:
		if fr.t > t + 0.0001:
			break
		f = fr
	return f


## 雙胞胎動作檔的影格（舊呼叫端的捷徑）
static func frame_at(anim: String, t: float) -> Dictionary:
	return frame_in(ANIMS_PATH, anim, t)


## 套用一個動作的影格：骨頭角度＝靜止姿勢＋影格裡的度數（沒列的骨頭維持靜止姿勢）；根骨頭（骨頭表第一根）位移；近側手勢。
## 位移的鍵：root（b2b1 的新動作檔）；雙胞胎的 twin_anims.json 沿用 pelvis（骨盆就是它們的根骨頭）
func pose(anim: String, t: float) -> void:
	var f := frame_in(anims_path, anim, t)
	var rot: Dictionary = f.get("bones", {})
	for b in bone_table:
		var bone: Bone2D = _bones[b[0]]
		bone.transform = bone.rest
		bone.rotation += deg_to_rad(rot.get(b[0], 0.0))
	var root: Bone2D = _bones[bone_table[0][0]]
	root.position = root.rest.origin + v(f.get("root", f.get("pelvis", [0, 0])))
	if humanoid:
		var hand: String = anims_at(anims_path).anims[anim].get("hand", "weapon")
		set_hand(_weapon_hand() if hand == "weapon" else hand)
	_sync()


func set_hand(kind: String) -> void:
	_sprites.hand_open_r.visible = kind == "open"
	_sprites.hand_grip_r.visible = kind == "grip"


func set_weapon(w: int) -> void:
	weapon = w
	for gear in WEAPON_GEAR.values():
		for n in gear:
			_sprites[n].visible = false
	for n in WEAPON_GEAR.get(w, []):
		_sprites[n].visible = true
	set_hand(_weapon_hand())


## 依裝備的手勢：斧頭、掘棒握著，球具與空手張開
func _weapon_hand() -> String:
	return "grip" if weapon == Weapons.Weapon.AXE or weapon == Weapons.Weapon.STICK else "open"


func show_attachment(n: String, on: bool) -> void:
	_sprites[n].visible = on


## 斷臂（SLICE-b2a-4）：近側上臂以下（前臂、手、握著的武器、護手）一起隱藏
func set_arm_visible(on: bool) -> void:
	if not humanoid:
		return
	_arm.visible = on
	_sprites.shoulder_cap.visible = not on


## 吹射覆寫（SLICE-b2a-7）：頭與雙臂改用 dart 的角度，雙臂整組轉到瞄準方向；頭只抬頭低頭、上限 ±45°。
## aim 是骨架座標（已扣掉面向）：(1, 0)＝前。主動作的軀幹傾斜要扣掉，手臂才會真的指向 aim。
## 近側手扶著吹管，握著的武器暫時收起（吹箭在遠側手）
func overlay_dart(aim: Vector2) -> void:
	if not humanoid:
		return
	var f := frame_in(anims_path, "dart", 0.0)
	var lean: float = _rig_angle(_bones.spine) - (_bones.pelvis.rest.get_rotation() + _bones.spine.rest.get_rotation())
	for n in DART_BONES:
		_bones[n].rotation = _bones[n].rest.get_rotation() + deg_to_rad(f.bones.get(n, 0.0))
	var theta := aim.angle()
	_bones.upperarm_r.rotation += theta - lean
	_bones.upperarm_l.rotation += theta - lean
	var pitch := atan2(aim.y, absf(aim.x))
	_bones.head.rotation = _bones.head.rest.get_rotation() + clampf(deg_to_rad(f.bones.get("head", 0.0)) + pitch - lean, -HEAD_LIMIT, HEAD_LIMIT)
	set_hand("grip")
	for n in HELD:
		_sprites[n].visible = false
	_sprites.wpn_blowgun.visible = true
	_sync()


## 骨頭在骨架座標的角度（扣掉整副骨架的位置與面向翻轉）
func _rig_angle(b: Node2D) -> float:
	return _rig_xf(b).get_rotation()


func bone(n: String) -> Bone2D:
	return _bones[n]


func sprite(n: String) -> Sprite2D:
	return _sprites[n]


## 光點目前的位置（骨架座標，翻轉前；MV-SLICE-001b2b1 R2）
func point(n: String) -> Vector2:
	if not points.has(n):  # 沒有這個光點：當骨頭名，回傳骨頭起點（雙胞胎拿著手臂；c2c）
		return _rig_xf(_bones[n]).origin
	var p: Dictionary = points[n]
	return _rig_xf(_bones[p.bone]) * v(p.at)


func bone_of(n: String) -> Bone2D:
	return _bone_of[n]


## 關節目前的世界座標：骨頭的起點，或終點（頭頂、指尖、腳趾、腰布末端）
func joint_global(j: String) -> Vector2:
	for b in bone_table:
		if b[2] == j:
			return _bones[b[0]].global_position
	for b in bone_table:
		if b[3] == j:
			var bn: Bone2D = _bones[b[0]]
			return bn.global_transform * Vector2(bn.get_length(), 0.0)
	return Vector2.INF
