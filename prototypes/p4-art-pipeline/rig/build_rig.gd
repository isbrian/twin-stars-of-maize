extends RefCounted
# 產生器（PROTO4-1）：依關節對照表建立 Skeleton2D 角色，存成可在編輯器微調的 {角色}.tscn。
# 存檔時記下 MD5；之後檔案被手動改過，重新產生時不覆蓋，除非 force（先把微調回填到對照表）。

const Rig := preload("res://rig/rig.gd")
const Anims := preload("res://rig/anims.gd")
const OUT := "res://hunahpu.tscn"
const HASH_PATH := "res://rig/hunahpu.build.md5"


static func out_for(c: String) -> String:
	return "res://%s.tscn" % c


static func hash_for(c: String) -> String:
	return "res://rig/%s.build.md5" % c


## 建立節點樹（不存檔）；分件檔缺少時回傳 null。呼叫端負責 free()
static func build(rig) -> Node2D:
	for part in rig.parts:
		var path := "res://art/%s.png" % part
		if not ResourceLoader.exists(path):
			printerr("BUILD 缺少分件 %s（先執行 ./sync_art.sh）" % path)
			return null
	var root := Node2D.new()
	root.name = rig.cid.capitalize()
	var sk := Skeleton2D.new()
	sk.name = "Skeleton"
	root.add_child(sk)
	sk.owner = root
	var g: Vector2 = rig.ground()
	var bones := {}
	for b in Rig.BONES:
		var bone := Bone2D.new()
		bone.name = b[0]
		var gl: Dictionary = rig.bone_global(b[0])
		var parent: Node = sk
		var parent_xf := Transform2D.IDENTITY
		if b[1] != "":
			parent = bones[b[1]]
			var pg: Dictionary = rig.bone_global(b[1])
			parent_xf = Transform2D(pg.angle, pg.pos - g)
		bone.transform = parent_xf.affine_inverse() * Transform2D(gl.angle, gl.pos - g)
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(gl.length)
		bone.set_bone_angle(0.0)
		bone.rest = bone.transform
		parent.add_child(bone)
		bone.owner = root
		bones[b[0]] = bone
	for part in rig.parts:
		var p: Dictionary = rig.parts[part]
		var s := Sprite2D.new()
		s.name = Rig.sprite_name(part)
		s.texture = load("res://art/%s.png" % part)
		s.centered = false
		var pivot := Rig.v(p.pivot)
		var tip := Rig.v(p.tip)
		var k: float = rig.part_scale(part)
		s.offset = -pivot  # 軸心對齊骨頭原點
		s.rotation = -(tip - pivot).angle() + deg_to_rad(p.get("angle_deg", 0.0))  # 分件主軸轉到骨頭方向
		s.scale = Vector2(k, k)
		if p.has("attach_t"):
			s.position = Vector2(bones[p.bone].get_length() * p.attach_t, 0)
		s.z_index = int(p.get("z", 0))
		s.visible = p.get("visible", true)
		bones[p.bone].add_child(s)
		s.owner = root
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.owner = root
	ap.add_animation_library("", Anims.make_library(rig, bones, root))
	return root


## 存成場景；out 在上次產生後被手動改過且未 force → ERR_ALREADY_EXISTS
static func save_scene(root: Node2D, out := OUT, hash_path := HASH_PATH, force := false) -> Error:
	if FileAccess.file_exists(out) and not force:
		var last := FileAccess.get_file_as_string(hash_path).strip_edges() if FileAccess.file_exists(hash_path) else ""
		if FileAccess.get_md5(out) != last:
			printerr("BUILD %s 在上次產生後被手動修改過，不覆蓋；確定要覆蓋請加 --force（先把微調回填到對照表 rig/*_rig.json）" % out)
			return ERR_ALREADY_EXISTS
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		return err
	err = ResourceSaver.save(ps, out)
	if err != OK:
		return err
	var f := FileAccess.open(hash_path, FileAccess.WRITE)
	f.store_string(FileAccess.get_md5(out))
	f.close()
	return OK
