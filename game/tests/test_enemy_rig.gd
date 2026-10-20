extends "res://tests/base_test.gd"
# MV-SLICE-001b2b1 Task 3：爬行型、飛行型的骨架（tools/cut_rig.py 從基準圖切件、import_rig.py 換成遊戲尺寸）。
# Task 4：動作（game/rig/{crawler,flyer}_anims.json）、world/enemy_animator.gd 的狀態對應、接進房間與 Boss 戰的召喚。

## 角色 → [b1 立繪（game/art/chr/）, 遊戲中的高度]
const ENEMIES := {
	"crawler": ["enm_falselight_crawler_reference", 70.0],
	"flyer": ["enm_falselight_flyer_reference", 60.0],
	"reflector": ["enm_falselight_reflector_reference", 150.0],  # MV-SLICE-001c4c2
}
const MATCH_PX := 2.0  # 疊合容許：兩邊的內容外框每一邊、每個不透明像素到對方最近的不透明像素都在 2 px 內
const MIN_IOU := 0.9  # 左上角對齊後兩個遮罩的交集÷聯集（切件後分件各自縮放，邊緣差 1 px 是正常的）
const ANIM_NAMES := ["idle", "telegraph", "attack", "recover", "stagger"]
const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const Index := preload("res://world/rooms/index.gd")
const TEST_SAVE := "user://test_enemy_rig_slot.json"
const Tint := preload("res://world/tint.gd")


func make_rig(c: String) -> Node2D:
	var r: Node2D = load("res://world/rig_view.gd").new()
	add_child(r)
	r.build(c)
	return r


func rig_json(c: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string("res://rig/%s_rig.json" % c)
	var d = JSON.parse_string(txt) if txt != "" else null
	return d if d is Dictionary else {}


## 看得到的分件，不透明像素（Alpha > 0.5）中心在世界座標的外框
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


## 骨架目前的樣子畫成不透明遮罩：每個畫面像素中心反推到每個看得到的分件取樣（Alpha > 0.5），裁到內容外框
func rig_mask(r: Node2D) -> Dictionary:
	var box := visible_bounds(r)
	var x0 := floori(box.position.x)
	var y0 := floori(box.position.y)
	var w := ceili(box.end.x) - x0 + 1
	var h := ceili(box.end.y) - y0 + 1
	var on := PackedByteArray()
	on.resize(w * h)
	for s in r.find_children("*", "Sprite2D", true, false):
		if not s.is_visible_in_tree():
			continue
		var img: Image = s.texture.get_image()
		var inv: Transform2D = s.global_transform.affine_inverse()
		for y in h:
			for x in w:
				var t: Vector2 = inv * Vector2(x0 + x + 0.5, y0 + y + 0.5) - s.offset
				var tx := floori(t.x)
				var ty := floori(t.y)
				if tx >= 0 and ty >= 0 and tx < img.get_width() and ty < img.get_height() and img.get_pixel(tx, ty).a > 0.5:
					on[y * w + x] = 1
	return crop_mask({"w": w, "h": h, "on": on})


## 圖片的不透明遮罩（Alpha > 0.5），裁到內容外框
func image_mask(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var on := PackedByteArray()
	on.resize(w * h)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				on[y * w + x] = 1
	return crop_mask({"w": w, "h": h, "on": on})


func crop_mask(m: Dictionary) -> Dictionary:
	var x0: int = m.w
	var y0: int = m.h
	var x1 := -1
	var y1 := -1
	for y in m.h:
		for x in m.w:
			if m.on[y * m.w + x]:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	var w := x1 - x0 + 1
	var h := y1 - y0 + 1
	var on := PackedByteArray()
	on.resize(maxi(w * h, 0))
	for y in h:
		for x in w:
			on[y * w + x] = m.on[(y + y0) * m.w + x + x0]
	return {"w": w, "h": h, "on": on}


func mask_at(m: Dictionary, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < m.w and y < m.h and m.on[y * m.w + x] == 1


## a 的不透明像素裡，MATCH_PX 內找得到 b 的不透明像素的比例
func near_share(a: Dictionary, b: Dictionary) -> float:
	var r := int(MATCH_PX)
	var total := 0
	var near := 0
	for y in a.h:
		for x in a.w:
			if not mask_at(a, x, y):
				continue
			total += 1
			var hit := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy <= MATCH_PX * MATCH_PX and mask_at(b, x + dx, y + dy):
						hit = true
						break
				if hit:
					break
			if hit:
				near += 1
	return float(near) / maxi(total, 1)


func iou(a: Dictionary, b: Dictionary) -> float:
	var both := 0
	var either := 0
	for y in maxi(a.h, b.h):
		for x in maxi(a.w, b.w):
			var p := mask_at(a, x, y)
			var q := mask_at(b, x, y)
			both += int(p and q)
			either += int(p or q)
	return float(both) / maxi(either, 1)


func test_enemy_rig_assembles() -> void:
	for c in ENEMIES:
		var d := rig_json(c)
		check(not d.is_empty(), "%s：game/rig/%s_rig.json 存在" % [c, c])
		if d.is_empty():
			continue
		check(d.get("humanoid", true) == false, "%s：不是人形" % c)
		check(int(d.get("faces", 1)) == -1, "%s：基準圖面向左（faces −1）" % c)
		check(d.get("anims", "") == "res://rig/%s_anims.json" % c, "%s：動作檔路徑" % c)
		var r := make_rig(c)
		for part in d.parts:
			var short: String = part.substr(("chr_%s_" % c).length())
			var s: Sprite2D = r.sprite(short)
			check(s != null and s.texture != null, "%s：分件 %s 在" % [c, short])
			if s == null or s.texture == null:
				continue
			var want := Vector2(d.parts[part].size[0], d.parts[part].size[1])
			check((s.texture.get_size() - want).abs().x <= 1.0 and (s.texture.get_size() - want).abs().y <= 1.0,
				"%s：分件 %s 的圖 %s 和資料 %s 一致" % [c, short, s.texture.get_size(), want])
		var b := visible_bounds(r)
		var target: float = ENEMIES[c][1]
		check(absf(b.size.y - target) <= target * 0.05, "%s：靜止姿勢高 %d±5%%（%.1f）" % [c, target, b.size.y])
		check(absf(b.end.y) <= 1.0, "%s：底部在原點 y=0±1（%.1f）" % [c, b.end.y])
		r.free()


func test_enemy_rig_rest_matches_reference() -> void:
	for c in ENEMIES:
		if rig_json(c).is_empty():
			check(false, "%s：沒有 rig" % c)
			continue
		var r := make_rig(c)
		var got := rig_mask(r)
		r.free()
		var ref_tex: Texture2D = load("res://art/chr/%s.png" % ENEMIES[c][0])
		var want := image_mask(ref_tex.get_image())
		# 兩邊都裁到內容外框（R4），左上角對齊；外框右、下兩邊差 ≤ 2 px
		check(absi(got.w - want.w) <= MATCH_PX and absi(got.h - want.h) <= MATCH_PX,
			"%s：內容外框 %dx%d（立繪 %dx%d）" % [c, got.w, got.h, want.w, want.h])
		var a := near_share(got, want)
		var bb := near_share(want, got)
		check(a == 1.0 and bb == 1.0, "%s：不透明像素 2 px 內互相涵蓋（骨架→立繪 %.4f、立繪→骨架 %.4f）" % [c, a, bb])
		var o := iou(got, want)
		check(o >= MIN_IOU, "%s：遮罩 IoU %.3f ≥ %.1f" % [c, o, MIN_IOU])
		print("  %s 靜止姿勢 %dx%d、立繪 %dx%d、IoU %.3f" % [c, got.w, got.h, want.w, want.h, o])


func test_enemy_rest_centred_on_origin() -> void:
	# Task 3 把原點 x 放在內容中心（b1 立繪以圖寬一半為中心）：換成骨架時敵人不會往旁邊跳
	for c in ENEMIES:
		var r := make_rig(c)
		var b := visible_bounds(r)
		check(absf(b.get_center().x) <= 1.0, "%s：靜止姿勢內容中心 x=0±1（%.2f）" % [c, b.get_center().x])
		r.free()


func anims_of(c: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string("res://rig/%s_anims.json" % c)
	var d = JSON.parse_string(txt) if txt != "" else null
	return d if d is Dictionary else {}


func animator_script():
	return load("res://world/enemy_animator.gd") if ResourceLoader.exists("res://world/enemy_animator.gd") else null


## 測試世界放一隻敵人並掛上骨架；沒有 enemy_animator.gd 時回傳 [w, e, null]
func rigged_enemy(c: String, target: Node2D = null) -> Array:
	var w := make_world()
	var kind = {"crawler": Crawler, "flyer": Flyer, "reflector": preload("res://core/enemies/reflector.gd")}[c]
	var e = await make_enemy(w, kind, Vector2(0, -200) if c == "flyer" else Vector2.ZERO, target)
	if c == "reflector":
		e.turn_left = 0.0  # 生成時面向左、遠處假人在右：會先開始轉身；這裡只測狀態→動作
	var scr = animator_script()
	var a = scr.attach(e, c) if scr != null else null
	return [w, e, a]


func test_enemy_anims_present() -> void:
	for c in ENEMIES:
		var d := anims_of(c)
		check(not d.is_empty(), "%s：game/rig/%s_anims.json 存在" % [c, c])
		if d.is_empty():
			continue
		check(int(d.get("fps", 0)) == 12, "%s：12 fps" % c)
		for n in ANIM_NAMES:
			var a: Dictionary = d.anims.get(n, {})
			check(a.get("frames", []).size() >= 1, "%s：有 %s 動作" % [c, n])
			check(a.get("loop", false) == (n == "idle"), "%s：%s %s" % [c, n, "循環" if n == "idle" else "不循環（停在最後一格）"])
			for f in a.get("frames", []):
				for b in f.get("bones", {}):
					check(rig_json(c).bones.any(func(x): return x[0] == b), "%s：%s 的骨頭 %s 存在" % [c, n, b])


func test_enemy_state_to_anim() -> void:
	for c in ENEMIES:
		var s: Array = await rigged_enemy(c)
		var e = s[1]
		var a = s[2]
		check(a != null, "world/enemy_animator.gd 存在")
		if a == null:
			await free_world(s[0])
			return
		var want := {Enemy.State.IDLE: "idle", Enemy.State.TELEGRAPH: "telegraph", Enemy.State.ATTACK: "attack",
			Enemy.State.RECOVER: "recover", Enemy.State.STAGGER: "stagger"}
		for st in want:
			e.state = st
			e.state_time = 0.123
			var got: Array = a.choose(e)
			check(got[0] == want[st], "%s：狀態 %d → %s（%s）" % [c, st, want[st], got[0]])
			if st != Enemy.State.IDLE:
				check(is_equal_approx(got[1], 0.123), "%s：%s 的時間＝state_time（%.3f）" % [c, want[st], got[1]])
		# 待機用累計時鐘：state_time 歸零（重新進入待機）時循環不跳回第一格
		e.state = Enemy.State.IDLE
		a.clock = 0.4
		e.state_time = 0.0
		check(is_equal_approx(a.choose(e)[1], 0.4), "%s：idle 用累計時鐘" % c)
		await free_world(s[0])


## 每根有父骨頭的骨頭：起點關節周圍 16 個取樣點（半徑 14×scale，同 test_rig.joint_coverage）各自有沒有被
## 「父骨頭的分件＋這根的分件」蓋住。取樣點固定在父骨頭的座標裡，跟著父骨頭走。
## 和雙胞胎不同：切件的關節有些標在輪廓邊上（飛行型的冠羽根、下翼根），靜止姿勢本來就有取樣點落在背景，
## 所以比的是「靜止姿勢蓋得住的點，每一格都還蓋得住」——轉動不露出新的縫
func bone_coverage(r: Node2D, b: Array, k: float, images: Dictionary) -> Array:
	var parent: Bone2D = r.bone(b[1])
	var at: Vector2 = r.bone(b[0]).position
	var out := []
	for i in 16:
		var p: Vector2 = parent.global_transform * (at + Vector2.from_angle(TAU * i / 16.0) * 14.0 * k)
		var hit := false
		for part in [b[1], b[0]]:
			var s: Sprite2D = r.sprite(part)
			var px: Vector2 = s.global_transform.affine_inverse() * p - s.offset
			var img: Image = images[part]
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height() and img.get_pixelv(Vector2i(px)).a >= 0.3:
				hit = true
				break
		out.append(hit)
	return out


func test_enemy_joints_covered_in_every_frame() -> void:
	for c in ENEMIES:
		var d := anims_of(c)
		if d.is_empty():
			check(false, "%s：沒有動作檔" % c)
			continue
		var r := make_rig(c)
		var rj := rig_json(c)
		var images := {}
		for b in rj.bones:
			images[b[0]] = r.sprite(b[0]).texture.get_image()
		var rest := {}
		for b in rj.bones:
			if b[1] != "":
				rest[b[0]] = bone_coverage(r, b, rj.scale, images)
				var n: int = rest[b[0]].count(true)
				check(n >= 2, "%s：%s 的關節在靜止姿勢至少有 2/16 個取樣點蓋住（%d/16）" % [c, b[0], n])
		var gaps := []
		for n in d.anims:
			for f in d.anims[n].frames:
				r.pose(n, f.t)
				for b in rj.bones:
					if b[1] == "":
						continue
					var cov := bone_coverage(r, b, rj.scale, images)
					var lost := 0
					for i in 16:
						if rest[b[0]][i] and not cov[i]:
							lost += 1
					if lost > 0:
						gaps.append("%s@%s %s 露出 %d 點" % [n, f.t, b[2] + "/" + b[0], lost])
		check(gaps.is_empty(), "%s 關節露縫：%s" % [c, ", ".join(gaps)])
		r.free()


func test_enemy_rig_faces_and_tints() -> void:
	for c in ENEMIES:
		var s: Array = await rigged_enemy(c)
		var e = s[1]
		var a = s[2]
		if a == null:
			check(false, "world/enemy_animator.gd 存在")
			await free_world(s[0])
			return
		var r: Node2D = e.get_node_or_null("Rig")
		check(r != null and r.show_behind_parent and e.portrait_drawn, "%s：骨架是敵人的子節點、畫在訊號後面、不畫灰盒身體" % c)
		check(e.get_node_or_null("Portrait") == null, "%s：沒有立繪" % c)
		# 基準圖面向左（faces −1）：面向右時骨架翻面，頭（最左的關節）跑到右邊
		e.facing = 1
		a._apply()
		check(r.scale.x < 0.0, "%s：面向右 → scale.x < 0（%.1f）" % [c, r.scale.x])
		var head: Vector2 = r.joint_global(r.bone_table[0][3])
		check(head.x > e.global_position.x, "%s：面向右時頭在右邊（%.1f vs %.1f）" % [c, head.x, e.global_position.x])
		e.facing = -1
		a._apply()
		check(r.scale.x > 0.0, "%s：面向左 → 不翻" % c)
		e.flash_left = 0.1
		a._apply()
		check(r.modulate.r > 1.0, "%s：受擊閃白（Tint.of）" % c)
		e.flash_left = 0.0
		e.health.invuln_left = 0.14
		a._apply()
		check(r.modulate == Tint.of(e), "%s：顏色一律照 Tint.of(e)" % c)
		await free_world(s[0])


## Review Focus 4：攻擊中被消滅，下一幀沒有殘留骨架
func test_enemy_rig_freed_with_enemy() -> void:
	for c in ENEMIES:
		var w := make_world()
		var p = await make_player(w, Vector2(300, 0))
		var e = await make_enemy(w, Crawler if c == "crawler" else Flyer, Vector2(0, -150) if c == "flyer" else Vector2.ZERO, p)
		var scr = animator_script()
		if scr == null:
			check(false, "world/enemy_animator.gd 存在")
			await free_world(w)
			return
		var a = scr.attach(e, c)
		var r: Node2D = e.get_node("Rig")
		e.start_telegraph()
		await wait_until(func(): return e.state == Enemy.State.ATTACK, 120)
		check(e.state == Enemy.State.ATTACK, "%s：進入攻擊" % c)
		await frames(1)
		e.kill()
		await frames(2)
		check(not is_instance_valid(e) and not is_instance_valid(r) and not is_instance_valid(a), "%s：敵人、骨架、animator 一起釋放" % c)
		await free_world(w)


func room_setup(room: String) -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.set_flag("intro_seen")
	var flow = RoomFlow.new()
	flow.gs = gs
	flow.tn = gs.tn
	flow.rooms = Index.ROOMS
	flow.fade_time = 0.0
	flow.save_path = TEST_SAVE
	add_child(flow)
	flow.start(room)
	await wait_until(func(): return not flow.is_busy(), 30)
	flow.current.player.scripted = true
	await frames(2)
	return [flow, gs]


func test_room_enemies_use_rigs() -> void:
	var s: Array = await room_setup("forest_2")
	var kinds := {}
	for e in s[0].current.enemies:
		var c := "crawler" if e is Crawler else "flyer"
		kinds[c] = true
		check(e.get_node_or_null("Portrait") == null, "%s：房間裡的造物沒有立繪" % e.name)
		check(e.get_node_or_null("Rig") != null and e.get_node_or_null("EnemyAnimator") != null and e.portrait_drawn, "%s：房間裡的造物是骨架" % e.name)
		var r = e.get_node_or_null("Rig")
		if r != null:
			check(r.cid == c, "%s：骨架是 %s（%s）" % [e.name, c, r.cid])
	check(kinds.size() == 2, "forest_2 有爬行型與飛行型（%s）" % [kinds.keys()])
	s[0].queue_free()
	await frames(2)
	s[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	# Boss 戰召喚的造物（有 GameState 時才換外觀，同 b1；做法同 test_portraits.gs_fight）
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var f = BossFight.new()
	f.tn = gs.tn
	f.gs = gs
	f.save_path = TEST_SAVE
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.boss.cycle_enabled = false
	for k in [Crawler, Flyer]:
		var e = k.new()
		f._spawn(e, Vector2(f.boss.position.x - 300.0, Nance.GROUND_Y))
		check(e.get_node_or_null("Portrait") == null and e.get_node_or_null("Rig") != null, "召喚的%s是骨架" % ("爬行型" if k == Crawler else "飛行型"))
	await free_fight(f)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
