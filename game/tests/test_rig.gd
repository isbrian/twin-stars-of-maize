extends "res://tests/base_test.gd"
# MV-SLICE-001b2a：雙胞胎的骨架（執行時從 game/rig/ 的資料組出）與動作資料。

const RigView := preload("res://world/rig_view.gd")
const MacawAnimator := preload("res://world/macaw_animator.gd")
const TWIN_IDS := ["hunahpu", "xbalanque"]
const NEAR_ARM := ["upperarm_r", "forearm_r", "hand_open_r", "hand_grip_r"]
const GEAR := ["wpn_axe", "wpn_digging_stick", "wpn_ballgear_yoke", "wpn_ballgear_armguard"]


## 組好一副骨架、掛在測試節點下（原點在世界原點）；rig_view.gd 不存在時回傳 null
func make_rig(c: String) -> Node2D:
	var scr = load("res://world/rig_view.gd")
	if scr == null:
		return null
	var r: Node2D = scr.new()
	add_child(r)
	r.build(c)
	return r


func rig_json(c: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://rig/%s_rig.json" % c))


## 所有看得到的分件與附件，不透明像素（Alpha > 0.5）在世界座標的外框
func visible_bounds(r: Node2D) -> Rect2:
	var box := Rect2()
	var first := true
	for s in r.find_children("*", "Sprite2D", true, false):
		if not s.is_visible_in_tree():
			continue
		var img: Image = s.texture.get_image()
		var xf: Transform2D = s.global_transform
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a <= 0.5:
					continue
				var p: Vector2 = xf * (Vector2(x + 0.5, y + 0.5) + s.offset)
				if first:
					box = Rect2(p, Vector2.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


func test_rig_height_and_feet() -> void:
	for c in TWIN_IDS:
		var r := make_rig(c)
		check(r != null, "rig_view.gd 存在")
		if r == null:
			return
		var b := visible_bounds(r)
		check(absf(b.size.y - 180.0) <= 9.0, "%s 站姿高 180±9（%.1f）" % [c, b.size.y])
		check(absf(b.end.y) <= 2.0, "%s 腳底在 y=0±2（%.1f）" % [c, b.end.y])
		r.free()


func test_rig_rest_matches_reference() -> void:
	for c in TWIN_IDS:
		var r := make_rig(c)
		check(r != null, "rig_view.gd 存在")
		if r == null:
			return
		# 比對形狀（以髖為準）；整副骨架的上下位置由 test_rig_height_and_feet 的腳底釘住
		var joints: Dictionary = rig_json(c).reference.joints
		var hip := Vector2(joints.hip[0], joints.hip[1])
		for j in joints:
			var want := Vector2(joints[j][0], joints[j][1]) - hip
			var got: Vector2 = r.joint_global(j) - r.joint_global("hip")
			check(got.distance_to(want) <= 2.0, "%s 關節 %s 在 %s（應為 %s）" % [c, j, got, want])
		r.free()


func test_rig_weapon_and_hand() -> void:
	var r := make_rig("hunahpu")
	check(r != null, "rig_view.gd 存在")
	if r == null:
		return
	var vis := func(n: String) -> bool: return r.sprite(n).is_visible_in_tree()
	check(not vis.call("wpn_blowgun") and not vis.call("prop_soup_bowl"), "預設不顯示吹箭與湯碗")
	r.set_weapon(Weapons.Weapon.AXE)
	check(vis.call("wpn_axe") and vis.call("hand_grip_r") and not vis.call("hand_open_r"), "斧頭：斧頭可見、近側手握持")
	check(not vis.call("wpn_digging_stick") and not vis.call("wpn_ballgear_yoke"), "斧頭：其他武器與球具隱藏")
	r.set_weapon(Weapons.Weapon.STICK)
	check(vis.call("wpn_digging_stick") and not vis.call("wpn_axe") and vis.call("hand_grip_r"), "掘棒：掘棒可見、近側手握持")
	r.set_weapon(Weapons.Weapon.BALLGEAR)
	check(vis.call("wpn_ballgear_yoke") and vis.call("wpn_ballgear_armguard"), "球具：護腰、護手可見")
	check(not vis.call("wpn_axe") and not vis.call("wpn_digging_stick") and vis.call("hand_open_r"), "球具：斧頭與掘棒隱藏、手張開")
	r.set_weapon(-1)
	check(vis.call("hand_open_r") and not vis.call("hand_grip_r"), "空手：手張開")
	for n in GEAR:
		check(not vis.call(n), "空手：%s 隱藏" % n)
	r.set_weapon(Weapons.Weapon.AXE)
	r.set_arm_visible(false)
	for n in NEAR_ARM + ["wpn_axe"]:
		check(not vis.call(n), "斷臂：%s 隱藏" % n)
	r.set_arm_visible(true)
	check(vis.call("upperarm_r") and vis.call("wpn_axe"), "手臂回來：上臂與斧頭可見")
	r.show_attachment("wpn_blowgun", true)
	r.show_attachment("prop_soup_bowl", true)
	check(vis.call("wpn_blowgun") and vis.call("prop_soup_bowl"), "show_attachment 讓吹箭、湯碗出現")
	r.show_attachment("wpn_blowgun", false)
	check(not vis.call("wpn_blowgun"), "show_attachment(false) 收起吹箭")
	r.free()


## 分件跟玩家同一層（相對 z 0、依樹順序排前後），和 b1 的立繪一樣：畫在先加入的篝火、撿拾物、NPC 之上，
## 夜晚的灌木（z −1）與場景遠景（−10）之下的東西都在後面；玩家程式畫的訊號由 show_behind_parent 蓋在上面（最終審查 Important 2）
func abs_z(n: Node) -> int:
	var z := 0
	while n is CanvasItem:
		z += n.z_index
		if not n.z_as_relative:
			break
		n = n.get_parent()
	return z


func test_rig_parts_share_player_layer() -> void:
	var r := make_rig("hunahpu")
	for s in r.find_children("*", "Sprite2D", true, false):
		check(abs_z(s) == 0, "%s 的層次 %d 應為 0（同玩家）" % [s.name, abs_z(s)])
	r.free()


# ---- 動作資料（Task 3）----

const ANIM_NAMES := [
	"idle", "run", "jump_up", "fall", "land", "roll", "hurt", "heal", "interact", "swap_in", "double_jump", "tool_cast",
	"attack_axe_side", "attack_axe_up", "attack_axe_down", "attack_stick_side", "attack_stick_up", "attack_stick_down",
	"parry_side", "parry_up", "ballgear_down", "parry_success", "dart",
]
## 攻擊類（出招／判定／收招三段，t 是段落時間 0～3）→ [武器, 量方向的附件, 攻擊方向（度）]
const ATTACKS := {
	"attack_axe_side": [Weapons.Weapon.AXE, "wpn_axe", 0.0],
	"attack_axe_up": [Weapons.Weapon.AXE, "wpn_axe", -90.0],
	"attack_axe_down": [Weapons.Weapon.AXE, "wpn_axe", 90.0],
	"attack_stick_side": [Weapons.Weapon.STICK, "wpn_digging_stick", 0.0],
	"attack_stick_up": [Weapons.Weapon.STICK, "wpn_digging_stick", -90.0],
	"attack_stick_down": [Weapons.Weapon.STICK, "wpn_digging_stick", 90.0],
	"ballgear_down": [Weapons.Weapon.BALLGEAR, "wpn_ballgear_armguard", 90.0],
}
## 招架沒有出招段：判定段（1～2）＝招架窗口、收招段（2～3）
const PARRIES := ["parry_side", "parry_up"]
const PHASE_RANGE := {"startup": Vector2(0, 1), "active": Vector2(1, 2), "recovery": Vector2(2, 3)}


func anim_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://rig/twin_anims.json"))


func test_all_anims_present() -> void:
	var a: Dictionary = anim_data().anims
	for n in ANIM_NAMES:
		check(a.has(n) and a[n].frames.size() >= 1, "動作 %s 有資料" % n)


func test_attack_frames_cover_phases() -> void:
	var a: Dictionary = anim_data().anims
	for n in ATTACKS.keys() + PARRIES:
		if not a.has(n):
			check(false, "動作 %s 有資料" % n)
			continue
		var seen := {}
		for f in a[n].frames:
			var ph: String = f.get("phase", "")
			check(PHASE_RANGE.has(ph), "%s@%s 有段落標記" % [n, f.t])
			if PHASE_RANGE.has(ph):
				var r: Vector2 = PHASE_RANGE[ph]
				check(f.t >= r.x and f.t < r.y, "%s@%s 的時間落在 %s 段 [%d, %d)" % [n, f.t, ph, r.x, r.y])
				seen[ph] = true
		var need := ["active", "recovery"] if n in PARRIES else ["startup", "active", "recovery"]
		for ph in need:
			check(seen.has(ph), "%s 有 %s 段的影格" % [n, ph])


## 附件主軸（握點→末端）在世界座標的角度（度）
func gear_angle(r: Node2D, n: String) -> float:
	var att: Dictionary = r.attachments()[n]
	var axis := Vector2(att.tip[0], att.tip[1]) - Vector2(att.pivot[0], att.pivot[1])
	return rad_to_deg(r.sprite(n).global_transform.basis_xform(axis).angle())


func test_attack_swing_points_dir() -> void:
	var a: Dictionary = anim_data().anims
	for c in TWIN_IDS:
		var r := make_rig(c)
		for n in ATTACKS:
			if not a.has(n):
				check(false, "動作 %s 有資料" % n)
				continue
			var spec: Array = ATTACKS[n]
			r.set_weapon(spec[0])
			var best := 180.0
			for f in a[n].frames:
				if f.get("phase", "") == "active":
					r.pose(n, f.t)
					best = minf(best, absf(wrapf(gear_angle(r, spec[1]) - spec[2], -180.0, 180.0)))
			check(best <= 30.0, "%s %s 判定段的揮出姿勢朝攻擊方向（差 %.0f°）" % [c, n, best])
		r.free()


## 關節周圍半徑 14×k 的 16 個取樣點被兩側分件（看得到的）不透明像素蓋住的比例。同 p4 joint_coverage
func joint_coverage(r: Node2D, joint: String, k: float, images: Dictionary) -> float:
	var pair: Array = r.JOINT_PAIRS[joint]
	var center: Vector2 = r.bone_of(pair[1]).global_position
	var covered := 0
	for i in 16:
		var p := center + Vector2.from_angle(TAU * i / 16.0) * 14.0 * k
		for part in pair:
			var s: Sprite2D = r.sprite(part)
			if not s.is_visible_in_tree():
				continue
			var px: Vector2 = s.global_transform.affine_inverse() * p - s.offset
			var img: Image = images[part]
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height() and img.get_pixelv(Vector2i(px)).a >= 0.3:
				covered += 1
				break
	return covered / 16.0


func test_joints_covered_in_every_frame() -> void:
	var a: Dictionary = anim_data().anims
	for c in TWIN_IDS:
		var r := make_rig(c)
		var k: float = rig_json(c).scale
		var images := {}
		for pair in r.JOINT_PAIRS.values():
			for part in pair:
				images[part] = r.sprite(part).texture.get_image()
		var gaps := []
		for n in a:
			r.set_weapon(ATTACKS[n][0] if ATTACKS.has(n) else Weapons.Weapon.AXE)
			for f in a[n].frames:
				r.pose(n, f.t)
				for joint in r.JOINT_PAIRS:
					var cov := joint_coverage(r, joint, k, images)
					if cov < 1.0:
						gaps.append("%s@%s %s %.0f%%" % [n, f.t, joint, cov * 100.0])
		check(gaps.is_empty(), "%s 關節露縫：%s" % [c, ", ".join(gaps)])
		r.free()


func test_pose_steps_without_interp() -> void:
	var run: Dictionary = anim_data().anims.get("run", {})
	check(run.get("loop", false) and run.get("frames", []).size() >= 2, "run 是至少兩格的循環動作")
	if run.get("frames", []).size() < 2:
		return
	var r := make_rig("hunahpu")
	var f0: Dictionary = run.frames[0]
	var f1: Dictionary = run.frames[1]
	var length: float = run.frames[-1].t + 1.0 / anim_data().fps
	for t in [lerpf(f0.t, f1.t, 0.9), length + lerpf(f0.t, f1.t, 0.5)]:
		r.pose("run", t)
		for b in ["thigh_r", "upperarm_r"]:
			var want: float = r.bone(b).rest.get_rotation() + deg_to_rad(f0.bones.get(b, 0.0))
			check(is_equal_approx(r.bone(b).rotation, want), "run@%.3f 的 %s 取前一格的角度（不內插）" % [t, b])
	r.free()


func test_pose_sets_hand() -> void:
	var r := make_rig("hunahpu")
	r.set_weapon(Weapons.Weapon.AXE)
	r.pose("heal", 0.0)
	check(r.sprite("hand_grip_r").visible and r.sprite("wpn_axe").visible, "治療：湯碗在遠側手，近側手照舊握斧頭")
	r.set_weapon(Weapons.Weapon.BALLGEAR)
	r.pose("dart", 0.0)
	check(r.sprite("hand_grip_r").visible and not r.sprite("hand_open_r").visible, "吹射（hand: grip）：近側手握著")
	r.pose("idle", 0.0)
	check(r.sprite("hand_open_r").visible and not r.sprite("hand_grip_r").visible, "待機（hand: weapon）：球具 → 手張開")
	r.free()


## 斷臂時肩膀收邊（規格「風險與退路」：膚色圓盤）：原本上臂所在的肩膀處被軀幹或圓盤蓋住，手臂回來時圓盤收起
func test_broken_arm_shoulder_closed() -> void:
	for c in TWIN_IDS:
		var r := make_rig(c)
		check(not r.sprite("shoulder_cap").is_visible_in_tree(), "%s 手臂在時沒有收邊圓盤" % c)
		r.set_arm_visible(false)
		check(r.sprite("shoulder_cap").is_visible_in_tree(), "%s 斷臂時顯示收邊圓盤" % c)
		var ua: Bone2D = r.bone("upperarm_r")
		var dir: Vector2 = ua.global_transform.x.normalized()
		var holes := 0
		for ring in [2.0, 4.0]:
			for i in 16:
				var p: Vector2 = ua.global_position + dir * 4.0 + Vector2.from_angle(TAU * i / 16.0) * ring
				var hit := false
				for n in ["torso", "shoulder_cap"]:
					var s: Sprite2D = r.sprite(n)
					var px: Vector2 = s.global_transform.affine_inverse() * p - s.offset
					var img: Image = s.texture.get_image()
					if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height() and img.get_pixelv(Vector2i(px)).a >= 0.5:
						hit = true
				if not hit:
					holes += 1
		check(holes == 0, "%s 斷臂的肩膀沒有缺口（%d 個取樣點露底）" % [c, holes])
		r.set_arm_visible(true)
		check(not r.sprite("shoulder_cap").is_visible_in_tree(), "%s 手臂回來時圓盤收起" % c)
		r.free()


# ---- 動作展示畫面（Task 6）----

func test_launch_args_rig_view() -> void:
	check(LaunchArgs.parse(PackedStringArray(["--rig-view"])).mode == "rig_view", "--rig-view → rig_view")
	var a := LaunchArgs.parse(PackedStringArray(["--rig-view", "--frames", "/tmp/rig_frames"]))
	check(a.mode == "rig_view" and a.frames_dir == "/tmp/rig_frames", "--rig-view --frames <資料夾> → 逐格輸出（錄驗收影片）")


## 錄影不靠視窗：展示畫面畫在 1920×1080 的 SubViewport（視窗被專案設定與螢幕大小夾住，Movie Writer 只錄得到視窗大小）
func test_showcase_renders_1080p() -> void:
	var scr = load("res://world/rig_showcase.gd")
	var sc: Node = scr.new()
	add_child(sc)
	await frames(1)
	check(sc.viewport is SubViewport and sc.viewport.size == Vector2i(1920, 1080), "展示畫面的 SubViewport 是 1920×1080")
	sc.queue_free()
	await frames(1)


func test_showcase_playlist_covers_all() -> void:
	var scr = load("res://world/rig_showcase.gd")
	check(scr != null, "rig_showcase.gd 存在")
	if scr == null:
		return
	# MV-SLICE-001b2b1：每項 {char, anim, secs, head}；雙胞胎播完接爬行型、飛行型、Seven Macaw（四種頭各播一輪）
	var seen := {}
	var order: Array = []
	for item in scr.playlist():
		check(item.secs > 0.0, "%s %s 播放秒數 > 0" % [item.char, item.anim])
		seen["%s/%s/%s" % [item.char, item.anim, item.head]] = true
		if order.is_empty() or order[-1] != item.char:
			order.append(item.char)
	check(order == ["twins", "crawler", "flyer", "reflector", "xmucane", "healer_man", "healer_woman", "rat", "chimalmat", "sevenmacaw"],
		"雙胞胎播完依序接爬行型、飛行型、反光型（MV-SLICE-001c4c2）、NPC（MV-SLICE-001b2b2）、Seven Macaw：%s" % [order])
	check(seen.has("reflector/thud/"), "展示清單有反光型的擋下一震")
	for n in ANIM_NAMES:
		check(seen.has("twins/%s/" % n), "展示清單有雙胞胎 %s" % n)
	var files := {"twins": "twin", "crawler": "crawler", "flyer": "flyer", "reflector": "reflector", "sevenmacaw": "sevenmacaw",
		"xmucane": "xmucane", "healer_man": "healer_man", "healer_woman": "healer_woman", "rat": "rat", "chimalmat": "chimalmat"}
	for c in files:
		var heads: Array = MacawAnimator.HEADS if c == "sevenmacaw" else [""]
		for n in RigView.anims_at("res://rig/%s_anims.json" % files[c]).anims:
			for h in heads:
				check(seen.has("%s/%s/%s" % [c, n, h]), "展示清單有 %s %s %s" % [c, n, h])


# ---- 骨頭表改成資料驅動（MV-SLICE-001b2b1 Task 1）----

const SNAPSHOT_PATH := "res://tests/fixtures/twin_rig_snapshot.json"
const SNAPSHOT_TOL := 0.01


func _xf6(t: Transform2D) -> Array:
	return [snappedf(t.x.x, 0.001), snappedf(t.x.y, 0.001), snappedf(t.y.x, 0.001), snappedf(t.y.y, 0.001), snappedf(t.origin.x, 0.001), snappedf(t.origin.y, 0.001)]


## 目前這個姿勢：骨頭在骨架座標的變換、分件的 transform、看得到的分件；再翻面記一次分件的世界變換（面向 −1）
func _capture_pose(r: Node2D) -> Dictionary:
	var out := {"bones": {}, "sprites": {}, "vis": [], "flip": {}}
	r.scale.x = 1.0
	for b in r.find_children("*", "Bone2D", true, false):
		out.bones[b.name] = _xf6(r._rig_xf(b))
	for s in r.find_children("*", "Sprite2D", true, false):
		out.sprites[s.name] = _xf6(s.transform)
		if s.is_visible_in_tree():
			out.vis.append(String(s.name))
	out.vis.sort()
	r.scale.x = -1.0
	for s in r.find_children("*", "Sprite2D", true, false):
		out.flip[s.name] = _xf6(s.global_transform)
	r.scale.x = 1.0
	return out


## 一副骨架的快照：關節（以腳底為原點）、twin_anims.json 每個動作每一格、吹射覆寫三個角度、球具與斷臂各一格
func twin_snapshot(r: Node2D) -> Dictionary:
	var out := {"joints": {}, "poses": {}}
	for j in r.joints:
		out.joints[j] = [snappedf(r.joints[j].x, 0.001), snappedf(r.joints[j].y, 0.001)]
	r.set_weapon(Weapons.Weapon.AXE)
	var anims: Dictionary = r.anims().anims
	for n in anims:
		for i in anims[n].frames.size():
			r.pose(n, anims[n].frames[i].t)
			out.poses["%s|%d" % [n, i]] = _capture_pose(r)
	for deg in [0, 90, 180]:
		r.pose("idle", 0.0)
		r.overlay_dart(Vector2.from_angle(deg_to_rad(deg)))
		out.poses["dart_overlay|%d" % deg] = _capture_pose(r)
	r.set_weapon(Weapons.Weapon.BALLGEAR)
	r.pose("idle", 0.0)
	out.poses["ballgear|idle"] = _capture_pose(r)
	r.set_weapon(Weapons.Weapon.AXE)
	r.set_arm_visible(false)
	r.pose("idle", 0.0)
	out.poses["arm_broken|idle"] = _capture_pose(r)
	r.set_arm_visible(true)
	return out


## 逐項比對（數字誤差 ≤ tol）；不同的路徑放進 bad
func _diff(want, got, path: String, bad: Array) -> void:
	if bad.size() >= 8:
		return
	if want is Dictionary:
		if not got is Dictionary or want.size() != got.size():
			bad.append("%s 的鍵不同" % path)
			return
		for k in want:
			if not got.has(k):
				bad.append("%s/%s 不見了" % [path, k])
			else:
				_diff(want[k], got[k], "%s/%s" % [path, k], bad)
	elif want is Array:
		if not got is Array or want.size() != got.size():
			bad.append("%s 的長度不同" % path)
			return
		for i in want.size():
			_diff(want[i], got[i], "%s[%d]" % [path, i], bad)
	elif want is float or want is int:
		if not (got is float or got is int) or absf(float(want) - float(got)) > SNAPSHOT_TOL:
			bad.append("%s：%s → %s" % [path, want, got])
	elif want != got:
		bad.append("%s：%s → %s" % [path, want, got])


func test_twin_rig_matches_snapshot() -> void:
	var want = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_PATH))
	check(want is Dictionary, "快照檔存在且是 JSON")
	if not want is Dictionary:
		return
	for c in TWIN_IDS:
		var r := make_rig(c)
		var bad := []
		_diff(want.get(c, {}), twin_snapshot(r), c, bad)
		check(bad.is_empty(), "%s 骨架和快照不同：%s" % [c, "；".join(bad)])
		r.free()


func test_rig_json_has_bone_table() -> void:
	for c in TWIN_IDS:
		var d := rig_json(c)
		check(d.get("bones", []).size() == 16, "%s 的 rig json 有 16 根骨頭" % c)
		for b in d.get("bones", []):
			check(b is Array and b.size() == 4, "%s 骨頭條目是 [名稱, 父, 起點, 終點]" % c)
		check(d.get("humanoid", false) == true, "%s 是人形（humanoid）" % c)
		check(d.get("anims", "") == "res://rig/twin_anims.json", "%s 的 anims 指向 twin_anims.json" % c)
		check(d.has("root_length") and d.get("origin", {}).get("x_joint", "") == "hip", "%s 有 root_length 與 origin" % c)
