extends Node
# --self-test：每個 test_ 開頭的方法是一項測試，依名稱排序執行。
# 執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，驗證時要另外 grep。

# MV-ASSET-010 起分件切自基準圖：腰布畫在軀幹上（沒有可擺動的腰布分件），共 16 件，短名＋角色前綴
const SHORT_PARTS := [
	"head", "torso",
	"upperarm_r", "forearm_r", "hand_open_r", "hand_grip_r",
	"upperarm_l", "forearm_l", "hand_open_l", "hand_grip_l",
	"thigh_r", "shin_r", "foot_r",
	"thigh_l", "shin_l", "foot_l",
]
const WEAPON := "wpn_axe"
const MAX_SPREAD := 0.15  # MV-ASSET-010 驗收：分件縮放比例差距 ≤ 15%（第 0 批分開生成時是 201.8%）
const Rig := preload("res://rig/rig.gd")
const Build := preload("res://rig/build_rig.gd")
const Anims := preload("res://rig/anims.gd")
const Showcase := preload("res://showcase.gd")

var pass_count := 0
var fail_count := 0
var _name := ""
var _failed := false


func run() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m.name).begins_with("test_"):
			names.append(m.name)
	names.sort()
	for n in names:
		_name = n
		_failed = false
		await call(n)
		if _failed:
			fail_count += 1
		else:
			pass_count += 1
		print("SELFTEST %s %s" % ["FAIL" if _failed else "PASS", n])
	print("SELFTEST SUMMARY pass=%d fail=%d" % [pass_count, fail_count])


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("SELFTEST   x %s：%s" % [_name, msg])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ---- Task 1：素材 ----

## 有對照表的角色（hunahpu 一定要有；xbalanque 切好之後才有）
func chars() -> Array:
	var out := []
	for c in Rig.CHARS:
		if c == "hunahpu" or FileAccess.file_exists(Rig.path_for(c)):
			out.append(c)
	return out


func parts_of(c: String) -> Array:
	return SHORT_PARTS.map(func(n): return "chr_%s_%s" % [c, n])


func test_art_synced_and_imported() -> void:
	var names := [WEAPON]
	for c in chars():
		names += parts_of(c) + ["chr_%s_reference" % c]
	for n in names:
		var p := "res://art/%s.png" % n
		check(FileAccess.file_exists(p), "缺少 %s（先執行 ./sync_art.sh）" % p)
		check(ResourceLoader.exists(p), "%s 沒有匯入" % p)


func test_textures_import_with_mipmaps() -> void:
	for c in chars():
		var cfg := ConfigFile.new()
		var path := "res://art/chr_%s_torso.png.import" % c
		check(cfg.load(path) == OK, "缺少匯入設定 %s" % path)
		check(cfg.get_value("params", "mipmaps/generate", false) == true, "%s 分件要產生 mipmap（縮到 180 px 時才不會閃爍）" % c)

# ---- Task 2：關節對照表 ----

func load_rig(c := "hunahpu"):
	var r := Rig.new()
	check(r.load_file(Rig.path_for(c)) == OK, "讀不到 %s" % Rig.path_for(c))
	return r


func load_art(part: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://art/%s.png" % part))


func opaque_near(img: Image, pt: Vector2, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := Vector2i(pt) + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a >= 0.5:
				return true
	return false


func test_rig_has_all_parts_and_joints() -> void:
	for c in chars():
		var r = load_rig(c)
		for n in parts_of(c) + [WEAPON]:
			check(r.parts.has(n), "對照表缺少分件 %s" % n)
		for j in Rig.JOINTS:
			check(r.joints.has(j), "%s 對照表缺少基準圖關節 %s" % [c, j])
		for n in r.parts:
			check(Rig.BONES.any(func(b): return b[0] == r.parts[n].bone), "%s 掛的骨頭 %s 不存在" % [n, r.parts[n].bone])


func test_rig_part_sizes_match_files() -> void:
	for c in chars():
		var r = load_rig(c)
		check(Vector2(load_art("chr_%s_reference" % c).get_size()) == r.ref_size, "%s 基準圖尺寸與對照表不符" % c)
		for n in r.parts:
			var size := Vector2i(int(r.parts[n].size[0]), int(r.parts[n].size[1]))
			check(load_art(n).get_size() == size, "%s 的尺寸 %s 與對照表 %s 不符（重新切件後要重新同步）" % [n, load_art(n).get_size(), size])


func test_rig_points_on_opaque_pixels() -> void:
	# MV-ASSET-010 起分件切自基準圖：軸心可能藏在別的分件底下（例如髖關節在腰布下、不在大腿分件的範圍內），
	# 所以檢查「關節落在基準圖的角色身上」，分件的軸心與末端只要在分件附近（一個關節圓的距離內）
	for c in chars():
		var r = load_rig(c)
		var ref := load_art("chr_%s_reference" % c)
		for n in r.parts:
			if n.begins_with("wpn_"):
				continue
			var img := load_art(n)
			var near_rect := Rect2(Vector2.ZERO, Vector2(img.get_size())).grow(140.0)
			for key in ["pivot", "tip"]:
				var pt := Rig.v(r.parts[n][key])
				check(near_rect.has_point(pt), "%s 的 %s %s 離分件太遠" % [n, key, pt])
		for j in r.joints:
			check(Rect2(Vector2.ZERO, r.ref_size).has_point(r.joints[j]), "%s 基準圖關節 %s 在圖外" % [c, j])
			if j in ["shoulder_l", "elbow_l", "wrist_l", "hand_tip_l"]:
				continue  # 遠側手臂的關節是近側往後移的推算值，不一定在角色身上
			check(opaque_near(ref, r.joints[j], 24), "%s 的關節 %s %s 不在角色身上" % [c, j, r.joints[j]])


# ---- Task 3：靜止姿勢與一致性 ----

func test_bones_parents_before_children() -> void:
	var seen := {}
	for b in Rig.BONES:
		check(b[1] == "" or seen.has(b[1]), "骨頭 %s 的父骨頭 %s 必須排在前面" % [b[0], b[1]])
		seen[b[0]] = true


func test_bone_global_matches_joints() -> void:
	var r = load_rig()
	for b in Rig.BONES:
		var g: Dictionary = r.bone_global(b[0])
		check(g.pos.is_equal_approx(r.joints[b[2]]), "%s 的起點應在關節 %s" % [b[0], b[2]])
		if b[3] != "":
			check(is_equal_approx(g.length, r.joints[b[2]].distance_to(r.joints[b[3]])), "%s 的長度應等於兩關節距離" % b[0])


func test_body_height_and_ground() -> void:
	var r = load_rig()
	check(r.body_height() > 0.6 * r.ref_size.y, "身高應佔基準圖大部分，實際 %.0f px" % r.body_height())
	check(r.ground().y >= r.joints.toe_r.y and r.ground().y >= r.joints.toe_l.y, "原點應在最低的腳趾高度")


func test_part_consistency_report() -> void:
	for ch in chars():
		var r = load_rig(ch)
		var c: Dictionary = r.consistency()
		check(c.scales.size() == SHORT_PARTS.size(), "%s：%d 件都要量（分件切自基準圖），實際 %d" % [ch, SHORT_PARTS.size(), c.scales.size()])
		for n in c.scales:
			check(c.scales[n] > 0.0, "%s 的縮放比例應為正數" % n)
		check(c.min <= c.median and c.median <= c.max, "統計值順序錯誤")
		check(c.spread <= MAX_SPREAD, "%s：縮放比例差距 %.1f%% 超過 %.0f%%" % [ch, c.spread * 100.0, MAX_SPREAD * 100.0])
		print("CONSISTENCY %s median=%.3f min=%.3f max=%.3f spread=%.1f%% stdev=%.1f%% outliers=%s" % [ch, c.median, c.min, c.max, c.spread * 100.0, c.stdev_ratio * 100.0, c.outliers])


# ---- Task 4：產生場景 ----

func test_build_structure() -> void:
	for c in chars():
		var r = load_rig(c)
		var root: Node2D = Build.build(r)
		check(root != null, "%s 產生失敗" % c)
		if root == null:
			continue
		check(root.get_node_or_null("Skeleton") is Skeleton2D, "缺少 Skeleton2D")
		var sprites := root.find_children("*", "Sprite2D", true, false)
		check(sprites.size() == SHORT_PARTS.size() + 1, "%s 應有 %d 個分件 Sprite2D，實際 %d" % [c, SHORT_PARTS.size() + 1, sprites.size()])
		for s in sprites:
			check(s.get_parent() is Bone2D, "%s 沒有掛在骨頭上" % s.name)
		var axe := root.find_child(Rig.sprite_name(WEAPON), true, false)
		check(axe != null and axe.get_parent().name == "hand_r", "斧頭應掛在近側手 hand_r")
		root.free()


func test_rest_pose_matches_reference() -> void:
	for c in chars():
		await _rest_pose(load_rig(c))


func _rest_pose(r) -> void:
	var root: Node2D = Build.build(r)
	add_child(root)
	var g: Vector2 = r.ground()
	for b in Rig.BONES:
		var bone: Bone2D = root.find_child(b[0], true, false)
		check(bone.global_position.distance_to(r.joints[b[2]] - g) < 0.5, "骨頭 %s 應在關節 %s" % [b[0], b[2]])
	for part in r.parts:
		var p: Dictionary = r.parts[part]
		if p.has("scale_from") or part.begins_with("wpn_"):
			continue
		var spec: Array = r.bone_spec(p.bone)
		if spec[3] == "":
			continue
		var s: Sprite2D = root.find_child(Rig.sprite_name(part), true, false)
		var tip_global := s.global_transform * (Rig.v(p.tip) + s.offset)
		check(tip_global.distance_to(r.joints[spec[3]] - g) < 1.0, "%s 的末端應落在關節 %s" % [part, spec[3]])
	root.queue_free()
	await frames(1)


func test_build_refuses_missing_art() -> void:
	var r = load_rig()
	r.parts[r.pn("missing")] = r.parts[r.pn("head")].duplicate()
	var root = Build.build(r)
	check(root == null, "缺少分件檔時不應產生殘缺的場景")
	if root != null:
		root.free()


func test_build_does_not_overwrite_hand_edits() -> void:
	var out := "user://selftest_hunahpu.tscn"
	var md5 := "user://selftest_hunahpu.md5"
	for f in [out, md5]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var r = load_rig()
	var root: Node2D = Build.build(r)
	check(Build.save_scene(root, out, md5) == OK, "第一次存檔應成功")
	var f := FileAccess.open(out, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("\n")  # 模擬在編輯器手動改過
	f.close()
	check(Build.save_scene(root, out, md5) == ERR_ALREADY_EXISTS, "手動改過後不加 force 不應覆蓋")
	check(Build.save_scene(root, out, md5, true) == OK, "加 force 應可覆蓋")
	root.free()
	for p in [out, md5]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_saved_scene_loads() -> void:
	for c in chars():
		var out := Build.out_for(c)
		check(ResourceLoader.exists(out), "缺少 %s（先執行 --build-rig）" % out)
		if not ResourceLoader.exists(out):
			continue
		var inst: Node = load(out).instantiate()
		check(inst.find_children("*", "Sprite2D", true, false).size() == SHORT_PARTS.size() + 1, "%s 存檔的場景分件數不對" % c)
		inst.free()


# ---- Task 5：動作 ----

func test_animations_exist_and_default_stepped() -> void:
	var r = load_rig()
	var root: Node2D = Build.build(r)
	var ap: AnimationPlayer = root.get_node("Anim")
	for spec in [["idle", 1.0, true], ["run", 0.5, true], ["axe_side", 0.32, false]]:
		check(ap.has_animation(spec[0]), "缺少動作 %s" % spec[0])
		if not ap.has_animation(spec[0]):
			continue
		var a := ap.get_animation(spec[0])
		check(is_equal_approx(a.length, spec[1]), "%s 長度應為 %.2f 秒" % [spec[0], spec[1]])
		check((a.loop_mode == Animation.LOOP_LINEAR) == spec[2], "%s 的循環設定錯誤" % spec[0])
		for t in a.get_track_count():
			check(a.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST, "%s 預設應不內插" % spec[0])
	root.free()


func test_interpolation_toggle() -> void:
	var root: Node2D = Build.build(load_rig())
	var ap: AnimationPlayer = root.get_node("Anim")
	Anims.set_smooth(ap, true)
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			check(a.track_get_interpolation_type(t) == Animation.INTERPOLATION_LINEAR, "%s 切換後應為線性內插" % name)
	Anims.set_smooth(ap, false)
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			check(a.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST, "%s 切回後應不內插" % name)
	root.free()


func test_rotation_keys_are_unwrapped() -> void:
	var root: Node2D = Build.build(load_rig())
	var ap: AnimationPlayer = root.get_node("Anim")
	for name in ap.get_animation_list():
		var a := ap.get_animation(name)
		for t in a.get_track_count():
			if not String(a.track_get_path(t)).ends_with(":rotation"):
				continue
			for k in range(1, a.track_get_key_count(t)):
				var d := absf(a.track_get_key_value(t, k) - a.track_get_key_value(t, k - 1))
				check(d <= PI, "%s 的 %s 相鄰關鍵影格差 %.0f°，平滑內插會繞遠路" % [name, a.track_get_path(t), rad_to_deg(d)])
	root.free()


func joint_coverage(root: Node, r, joint: String, images: Dictionary) -> float:
	var pair: Array = Anims.JOINT_PAIRS[joint].map(func(n): return r.pn(n))
	var child_bone: Bone2D = root.find_child(r.parts[pair[1]].bone, true, false)
	var c := child_bone.global_position
	var covered := 0
	for i in 16:
		var p := c + Vector2.from_angle(TAU * i / 16.0) * Anims.JOINT_RING
		for part in pair:
			var s: Sprite2D = root.find_child(Rig.sprite_name(part), true, false)
			if not s.is_visible_in_tree():  # 同一根骨頭上可能有兩種手勢，只算畫面上看得到的
				continue
			var px := s.global_transform.affine_inverse() * p - s.offset
			var img: Image = images[part]
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height() and img.get_pixelv(Vector2i(px)).a >= 0.3:
				covered += 1
				break
	return covered / 16.0


func test_joints_covered_in_every_key() -> void:
	for c in chars():
		await _joints_covered(load_rig(c))


func _joints_covered(r) -> void:
	var root: Node2D = Build.build(r)
	add_child(root)
	var images := {}
	for pair in Anims.JOINT_PAIRS.values():
		for part in pair:
			images[r.pn(part)] = load_art(r.pn(part))
	var ap: AnimationPlayer = root.get_node("Anim")
	var gaps := []
	for name in ["idle", "run", "axe_side"]:
		var a := ap.get_animation(name)
		ap.play(name)
		for k in a.track_get_key_count(0):
			var t := a.track_get_key_time(0, k)
			ap.seek(t, true)
			for joint in Anims.JOINT_PAIRS:
				var cov := joint_coverage(root, r, joint, images)
				if cov < 1.0:
					gaps.append("%s@%.2fs %s %.0f%%" % [name, t, joint, cov * 100.0])
	check(gaps.is_empty(), "%s 關節穿幫：%s" % [r.cid, ", ".join(gaps)])
	root.queue_free()
	await frames(1)


func test_hand_and_axe_visibility_per_animation() -> void:
	# 規格：跑步時近側手張開；斧頭側攻時近側握拳手持斧。武器只在攻擊時出現
	var r = load_rig()
	var root: Node2D = Build.build(r)
	add_child(root)
	var ap: AnimationPlayer = root.get_node("Anim")
	var open_r: Sprite2D = root.find_child(Rig.sprite_name(r.pn("hand_open_r")), true, false)
	var grip_r: Sprite2D = root.find_child(Rig.sprite_name(r.pn("hand_grip_r")), true, false)
	var axe: Sprite2D = root.find_child(Rig.sprite_name(WEAPON), true, false)
	for spec in [["idle", false], ["run", false], ["axe_side", true]]:
		ap.play(spec[0])
		ap.seek(0.0, true)
		check(grip_r.visible == spec[1] and axe.visible == spec[1] and open_r.visible != spec[1], "%s：近側握拳手與斧頭應%s顯示、張開手相反" % [spec[0], "" if spec[1] else "不"])
	root.queue_free()
	await frames(1)


# ---- Task 6：展示畫面 ----

func test_showcase_heroes_are_180px() -> void:
	var sc := Showcase.new()
	add_child(sc)
	await frames(2)
	var n := sc.rigs.size()
	check(n == chars().size(), "展示畫面應有 %d 位角色，實際 %d" % [chars().size(), n])
	check(sc.heroes.size() == 3 * n, "每位角色應有三個 180 px 小人")
	var i := 0
	for c in sc.rigs:
		for k in 3:
			var h: Node2D = sc.heroes[i * 3 + k]
			check(absf(h.scale.y * sc.rigs[c].body_height() - Showcase.TARGET_HEIGHT) < 1.0, "%s 角色高度應約 180 px" % c)
		i += 1
	var names := sc.heroes.map(func(h): return String(h.get_node("Anim").current_animation))
	var expect := []
	for k in n:
		expect += ["idle", "run", "axe_side"]
	check(names == expect, "每位角色應依序播待機、跑、斧頭側攻，實際 %s" % [names])
	sc.queue_free()
	await frames(1)


func test_showcase_toggles() -> void:
	var sc := Showcase.new()
	add_child(sc)
	await frames(2)
	sc.toggle_gray()
	check(sc.gray.visible, "按 G 應開啟灰階")
	sc.toggle_gray()
	check(not sc.gray.visible, "再按 G 應關閉灰階")
	sc.toggle_smooth()
	var a: Animation = sc.heroes[1].get_node("Anim").get_animation("run")
	check(a.track_get_interpolation_type(0) == Animation.INTERPOLATION_LINEAR, "按 T 應切成平滑內插")
	sc.toggle_smooth()
	check(a.track_get_interpolation_type(0) == Animation.INTERPOLATION_NEAREST, "再按 T 應切回不內插")
	sc.set_view("consistency")
	check(sc.consistency_view.visible and not sc.showcase_view.visible, "應切到一致性對照")
	sc.set_view("showcase")
	check(sc.showcase_view.visible and not sc.consistency_view.visible, "應切回展示畫面")
	sc.queue_free()
	await frames(1)


# ---- 最終審查修正 ----

func test_capture_uses_1080p_window() -> void:
	# 截圖要在 1920×1080 下拍，角色才是 180 px（預設視窗 1280×720 時只有約 120 px）
	var sc := Showcase.new()
	add_child(sc)
	await frames(2)
	var before := get_window().size
	sc.freeze_for_capture()
	check(get_window().size == Showcase.CAPTURE_SIZE, "截圖前視窗應為 %s，實際 %s" % [Showcase.CAPTURE_SIZE, get_window().size])
	get_window().size = before
	sc.queue_free()
	await frames(1)


func test_editor_tweaks_contract() -> void:
	# README 的微調說明：骨頭位置（骨盆除外）與分件偏移不受動作影響；骨頭旋轉每格都由動作決定
	var root: Node2D = Build.build(load_rig())
	add_child(root)
	var bone: Bone2D = root.find_child("forearm_r", true, false)
	var art: Sprite2D = root.find_child(Rig.sprite_name("chr_hunahpu_forearm_r"), true, false)  # 對照表預設是 hunahpu
	var pos := bone.position + Vector2(7, -3)
	var off := art.offset + Vector2(4, 4)
	bone.position = pos
	art.offset = off
	bone.rotation += 0.5
	var tweaked_rot := bone.rotation
	var ap: AnimationPlayer = root.get_node("Anim")
	ap.play("run")
	ap.seek(0.25, true)
	check(bone.position == pos, "骨頭位置的微調應保留")
	check(art.offset == off, "分件偏移的微調應保留")
	check(not is_equal_approx(bone.rotation, tweaked_rot), "骨頭旋轉應由動作覆蓋（README 要說明改旋轉要回填對照表）")
	root.queue_free()
	await frames(1)
