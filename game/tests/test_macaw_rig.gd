extends "res://tests/base_test.gd"
# MV-SLICE-001b2b1 Task 5：Seven Macaw 的骨架（tools/cut_rig.py 切件，含受傷的頭三件、光點）。
# Task 6：動作、換頭、光源跟著頭骨（world/macaw_animator.gd）。
# 遮罩、外框、疊合、關節覆蓋的工具借 test_enemy_rig.gd（只當工具物件用，不加進場景樹、不跑它的測試）。

const C := "sevenmacaw"
const HEIGHT := 450.0
const PORTRAIT := "res://art/chr/enm_sevenmacaw_rest.png"  # 切件輸出的合成圖（MV-TUNE-003 TUNE3-3）
const HEADS := ["head_jawhurt", "head_maize", "head_blind"]
const POINT_PX := 8.0  # 光點和 b1 量的立繪位置差多少以內
const ANIM_NAMES := ["idle_perch", "idle_ground", "fly", "eat", "throw", "dive", "flail", "spread", "wail", "beam", "stagger", "fall", "down", "yank", "hang", "bow", "collapse"]
const LOOPS := ["idle_perch", "idle_ground", "fly", "eat", "wail", "fall"]
const HEAD_PARTS := ["head", "head_jawhurt", "head_maize", "head_blind"]  # 依 appearance 0～3
const LIGHT_PX := 4.0  # 光源和頭骨上的光點差多少以內（規格驗收：±4 px）
const GameStateScr := preload("res://state/game_state.gd")
const RigView := preload("res://world/rig_view.gd")
const Dive := preload("res://core/boss/moves/dive.gd")
const EatFruit := preload("res://core/boss/moves/eat_fruit.gd")
const ThrowFruit := preload("res://core/boss/moves/throw_fruit.gd")
const Flail := preload("res://core/boss/moves/flail.gd")
const ThroneCharge := preload("res://core/boss/moves/throne_charge.gd")
const StaggerPounce := preload("res://core/boss/moves/stagger_pounce.gd")
const TEST_SAVE := "user://test_macaw_rig_slot.json"
## b1 從靜態立繪量的光源位置（面向右、相對腳底：下顎、玉牙、眼睛）。原本是 seven_macaw.gd 的 ART_LIGHT_OFFSETS
## （MV-SLICE-001b1）；Task 7 光源全由骨架放、移除該常數，數字搬來這裡核對切件的光點
const B1_LIGHTS := [Vector2(87, -358), Vector2(87, -372), Vector2(56, -405)]
const BODY_PARTS := ["torso", "pelvis", "thigh_l", "shin_l", "claw_l", "thigh_r", "shin_r", "claw_r"]  # SLICE-b2b-6：身體＋腳（不含頭、脖子、翅膀、尾羽）
const BODY_PX := 2.0  # BODY 常數和骨架量的外框差多少以內
const FLAPS := ["fly", "flail"]  # MV-TUNE-003：拍翅循環
const SPREADS := ["dive", "spread", "wail", "fall", "stagger"]  # MV-TUNE-003：往上張；其餘動作是待機類
const SHOULDER_BOX := 30  # 肩膀關節周圍的方框半邊（遊戲 px）：蓋住翅膀根；60 會包進頭冠和翅膀之間的天空凹口（遠側翅膀抬起就封住、被當成洞）
const SHOULDER_MARGIN := 60  # 取遮罩時方框再往外擴，背景才繞得出去
const HOLE_PX := 4  # 方框內被輪廓包住的透明像素上限
const ROLL_LEAD := 3  # 閃招測試：在站著會被打到的那一幀之前幾幀按翻滾（無敵從 0.03 秒＝第 2 幀開始）


func helpers() -> Node:
	return load("res://tests/test_enemy_rig.gd").new()


func make_rig() -> Node2D:
	var r: Node2D = load("res://world/rig_view.gd").new()
	add_child(r)
	r.build(C)
	return r


func test_macaw_rig_assembles() -> void:
	var h := helpers()
	var d: Dictionary = h.rig_json(C)
	check(not d.is_empty(), "game/rig/sevenmacaw_rig.json 存在")
	if d.is_empty():
		h.free()
		return
	check(d.get("humanoid", true) == false, "不是人形")
	check(int(d.get("faces", 1)) == -1, "基準圖面向左（faces −1）")
	check(d.get("anims", "") == "res://rig/sevenmacaw_anims.json", "動作檔路徑")
	var r := make_rig()
	for part in d.parts:
		var short: String = part.substr(("chr_%s_" % C).length())
		var s: Sprite2D = r.sprite(short)
		check(s != null and s.texture != null, "分件 %s 在" % short)
	for n in ["head", "wing_arm", "wing_fore", "wing_tip", "wing_arm_l", "wing_fore_l", "wing_tip_l", "tail", "claw_r"]:
		check(r.sprite(n) != null, "分件 %s 在" % n)
	for n in HEADS:
		var s: Sprite2D = r.sprite(n)
		check(s != null and not s.visible, "受傷的頭 %s 在、預設隱藏" % n)
		if s != null:
			check(d.parts["chr_%s_%s" % [C, n]].bone == "head", "%s 掛 head 骨" % n)
	var b: Rect2 = h.visible_bounds(r)
	check(absf(b.size.y - HEIGHT) <= HEIGHT * 0.05, "靜止姿勢高 450±5%%（%.1f）" % b.size.y)
	check(absf(b.end.y) <= 1.0, "腳爪底部在原點 y=0±1（%.1f）" % b.end.y)
	r.free()
	h.free()


func test_macaw_rig_rest_matches_reference() -> void:
	var h := helpers()
	if h.rig_json(C).is_empty():
		check(false, "沒有 rig")
		h.free()
		return
	var r := make_rig()
	var got: Dictionary = h.rig_mask(r)
	r.free()
	var want: Dictionary = h.image_mask((load(PORTRAIT) as Texture2D).get_image())
	# 兩邊都裁到內容外框（R4），左上角對齊；外框右、下兩邊差 ≤ 2 px、不透明像素 2 px 內互相涵蓋
	check(absi(got.w - want.w) <= h.MATCH_PX and absi(got.h - want.h) <= h.MATCH_PX,
		"內容外框 %dx%d（立繪 %dx%d）" % [got.w, got.h, want.w, want.h])
	var a: float = h.near_share(got, want)
	var bb: float = h.near_share(want, got)
	check(a == 1.0 and bb == 1.0, "不透明像素 2 px 內互相涵蓋（骨架→立繪 %.4f、立繪→骨架 %.4f）" % [a, bb])
	var o: float = h.iou(got, want)
	check(o >= h.MIN_IOU, "遮罩 IoU %.3f ≥ %.1f" % [o, h.MIN_IOU])
	print("  sevenmacaw 靜止姿勢 %dx%d、立繪 %dx%d、IoU %.3f" % [got.w, got.h, want.w, want.h, o])
	h.free()


func test_macaw_points_on_head() -> void:
	var h := helpers()
	if h.rig_json(C).is_empty():
		check(false, "沒有 rig")
		h.free()
		return
	var r := make_rig()
	# B1_LIGHTS 是面向右、相對腳底；骨架是基準圖方向（面向左），x 反過來比
	var names := ["jaw", "teeth", "eye"]
	for i in names.size():
		var want: Vector2 = B1_LIGHTS[i] * Vector2(-1, 1)
		var got: Vector2 = r.point(names[i])
		check(got.distance_to(want) <= POINT_PX, "光點 %s 在 %s，立繪量的 %s（差 ≤ %d px）" % [names[i], got, want, POINT_PX])
	r.free()
	h.free()


# ---- Task 6：動作、換頭、光源 ----

func anims() -> Dictionary:
	var h := helpers()
	var d: Dictionary = h.anims_of(C)
	h.free()
	return d


func animator_script():
	return load("res://world/macaw_animator.gd") if ResourceLoader.exists("res://world/macaw_animator.gd") else null


## 單獨一隻 Seven Macaw 掛上骨架；Boss 與 animator 都不跑物理（狀態、招式由測試設定）。沒有 animator 時 [b, null]
func rigged_macaw() -> Array:
	var b = Macaw.new()
	add_child(b)
	b.set_physics_process(false)
	var scr = animator_script()
	var a = scr.attach(b) if scr != null else null
	if a != null:
		a.set_physics_process(false)
	return [b, a]


## 有 GameState 的 Boss 戰（做法同 test_portraits.gs_fight）
func macaw_fight() -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
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
	f.card.min_time = 0.0
	f.boss.cycle_enabled = false
	return [f, gs]


func set_move(b, mv: String, step: int, t := 0.0) -> void:
	var m = Macaw.MOVES[mv].new()
	m.boss = b
	m.step = step
	m.t = t
	b.move = m
	b.move_name = mv
	b.state = Macaw.State.MOVE


func test_macaw_anims_present() -> void:
	var d := anims()
	check(not d.is_empty(), "game/rig/sevenmacaw_anims.json 存在")
	if d.is_empty():
		return
	check(int(d.get("fps", 0)) == 12, "12 fps")
	var h := helpers()
	var bones: Array = h.rig_json(C).bones.map(func(x): return x[0])
	h.free()
	for n in ANIM_NAMES:
		var a: Dictionary = d.anims.get(n, {})
		check(a.get("frames", []).size() >= 1, "有 %s 動作" % n)
		check(a.get("loop", false) == LOOPS.has(n), "%s %s" % [n, "循環" if LOOPS.has(n) else "不循環（停在最後一格）"])
		for f in a.get("frames", []):
			for b in f.get("bones", {}):
				check(bones.has(b), "%s 的骨頭 %s 存在" % [n, b])
	check(d.anims.size() == ANIM_NAMES.size(), "只有規格動作清單裡的動作（%s）" % [d.anims.keys()])


## 狀態對應（規格「動作清單」、Review Focus 3：DOWN、INTRO、BROKEN 跌落）
func test_macaw_state_to_anim() -> void:
	var s := rigged_macaw()
	var b = s[0]
	var a = s[1]
	check(a != null, "world/macaw_animator.gd 存在")
	if a == null:
		b.free()
		return
	var S = Macaw.State
	var tn = b.tn
	# 待機依高度：樹冠、低枝 → 樹上；宮殿地面 → 地面
	var spots := [[Nance.CANOPY, "idle_perch"], [Nance.PERCH, "idle_perch"], [Palace.HOME, "idle_ground"]]
	for st in [S.GAP, S.DOWN, S.INTRO]:
		for sp in spots:
			b.state = st
			b.position = sp[0]
			b.phase = 1 if sp[0] != Palace.HOME else 2
			b.appearance = b.phase - 1  # 段落還沒結束
			b._intro_step = 1  # 開場在低枝吃果子（不在飛）
			check(a.choose(b)[0] == sp[1], "狀態 %d 在 %s → %s（%s）" % [st, sp[0], sp[1], a.choose(b)[0]])
	# 待機用累計時鐘
	b.state = S.GAP
	a.clock = 0.7
	b.state_time = 0.0
	check(is_equal_approx(a.choose(b)[1], 0.7), "待機用累計時鐘")
	# 開場的 fly_to → 飛行
	b.state = S.INTRO
	for step in [0, 2]:
		b._intro_step = step
		check(a.choose(b)[0] == "fly", "開場第 %d 步（fly_to）→ fly（%s）" % [step, a.choose(b)[0]])
	# 段落結束（設局成功後 deactivate：appearance 已等於這一段）→ 倒下
	b.state = S.DOWN
	for ph in [1, 2]:
		b.phase = ph
		b.appearance = ph
		b.position = Nance.PERCH if ph == 1 else Palace.HOME
		check(a.choose(b)[0] == "down", "第 %d 段結束的 DOWN → down（%s）" % [ph, a.choose(b)[0]])
	b.appearance = 0
	b.phase = 1
	# 各招：[招式, 階段, 動作]
	var table := [
		["dive", Dive.Step.TRAVEL, "fly"], ["dive", Dive.Step.TELEGRAPH, "dive"], ["dive", Dive.Step.DIVE, "dive"], ["dive", Dive.Step.REST, "dive"],
		["eat_fruit", EatFruit.Step.TRAVEL, "fly"], ["eat_fruit", EatFruit.Step.EAT, "eat"],
		["throw_fruit", ThrowFruit.Step.TRAVEL, "fly"], ["throw_fruit", ThrowFruit.Step.TELEGRAPH, "throw"],
		["false_flash", FalseFlash.Step.TRAVEL, "fly"], ["false_flash", FalseFlash.Step.TELEGRAPH, "spread"],
		["summon", 0, "spread"], ["wail", 0, "wail"],
		["flail", Flail.Step.CHASE, "fly"], ["flail", Flail.Step.TELEGRAPH, "flail"], ["flail", Flail.Step.ATTACK, "flail"], ["flail", Flail.Step.DONE, "flail"],
		["throne_charge", ThroneCharge.Step.REPOSITION, "fly"], ["throne_charge", ThroneCharge.Step.TELEGRAPH, "dive"],
		["throne_charge", ThroneCharge.Step.CHARGE, "dive"], ["throne_charge", ThroneCharge.Step.PILLARS, "dive"],
		["stagger_pounce", StaggerPounce.Step.TELEGRAPH, "dive"], ["stagger_pounce", StaggerPounce.Step.POUNCE, "dive"], ["stagger_pounce", StaggerPounce.Step.REST, "dive"],
		["beam", Beam.Step.CHARGE, "beam"], ["beam", Beam.Step.FIRE, "beam"], ["beam", Beam.Step.WOBBLE, "beam"],
	]
	for row in table:
		set_move(b, row[0], row[1])
		var got: Array = a.choose(b)
		check(got[0] == row[2], "%s 階段 %d → %s（%s）" % [row[0], row[1], row[2], got[0]])
	check(Macaw.MOVES.keys().all(func(k): return table.any(func(r): return r[0] == k)), "十招都在表裡")
	# 分段時間（同雙胞胎的 attack_time）：前搖 0～1、出招 1～2、收招 2～3，依數值表
	var seg := [
		["dive", Dive.Step.TELEGRAPH, tn.dive_telegraph, 0.5], ["dive", Dive.Step.REST, tn.dive_rest, 2.5],
		["throne_charge", ThroneCharge.Step.TELEGRAPH, tn.charge_telegraph, 0.5],
		["throne_charge", ThroneCharge.Step.PILLARS, tn.pillar_warn + tn.pillar_active, 2.5],
		["stagger_pounce", StaggerPounce.Step.TELEGRAPH, tn.pounce_telegraph, 0.5], ["stagger_pounce", StaggerPounce.Step.REST, tn.pounce_rest, 2.5],
		["flail", Flail.Step.TELEGRAPH, tn.flail_telegraph, 0.5], ["flail", Flail.Step.ATTACK, tn.flail_active, 1.5],
		["beam", Beam.Step.CHARGE, tn.beam_charge, 0.5], ["beam", Beam.Step.FIRE, tn.beam_active, 1.5], ["beam", Beam.Step.WOBBLE, tn.beam_wobble, 2.5],
		["throw_fruit", ThrowFruit.Step.TELEGRAPH, tn.throw_telegraph, 0.5], ["false_flash", FalseFlash.Step.TELEGRAPH, tn.flash_telegraph, 0.5],
		["summon", 0, tn.summon_telegraph, 0.5],
	]
	for row in seg:
		set_move(b, row[0], row[1], row[2] / 2.0)
		var tt: float = a.choose(b)[1]
		check(absf(tt - row[3]) < 0.001, "%s 階段 %d 經過一半 → 時間 %.1f（%.3f）" % [row[0], row[1], row[3], tt])
	for mv in [["dive", Dive.Step.DIVE], ["throne_charge", ThroneCharge.Step.CHARGE], ["stagger_pounce", StaggerPounce.Step.POUNCE]]:
		set_move(b, mv[0], mv[1], 0.4)
		var tt: float = a.choose(b)[1]
		check(tt >= 1.0 and tt < 2.0, "%s 的衝刺在 1～2 段（%.3f）" % [mv[0], tt])
	# 硬直、破綻、跌落
	b.move = null
	b.move_name = ""
	b.state_time = 0.25
	b.state = S.INTERRUPTED
	check(a.choose(b) == ["stagger", 0.25], "INTERRUPTED → stagger、state_time（%s）" % [a.choose(b)])
	b.state = S.BROKEN
	b._falling = false
	check(a.choose(b) == ["stagger", 0.25], "BROKEN → stagger（%s）" % [a.choose(b)])
	b._falling = true
	check(a.choose(b)[0] == "fall", "BROKEN 跌落中 → fall（%s）" % [a.choose(b)])
	b.free()


## 每根有父骨頭的骨頭：靜止姿勢蓋得住的關節取樣點，每個動作每一格都還蓋得住（做法同 test_enemy_rig）
func test_macaw_joints_covered_in_every_frame() -> void:
	var d := anims()
	if d.is_empty():
		check(false, "沒有動作檔")
		return
	var h := helpers()
	var r := make_rig()
	var rj: Dictionary = h.rig_json(C)
	var images := {}
	for b in rj.bones:
		images[b[0]] = r.sprite(b[0]).texture.get_image()
	var rest := {}
	for b in rj.bones:
		if b[1] != "":
			rest[b[0]] = h.bone_coverage(r, b, rj.scale, images)
	var gaps := []
	for n in d.anims:
		for f in d.anims[n].frames:
			r.pose(n, f.t)
			for b in rj.bones:
				if b[1] == "":
					continue
				var cov: Array = h.bone_coverage(r, b, rj.scale, images)
				var lost := 0
				for i in 16:
					if rest[b[0]][i] and not cov[i]:
						lost += 1
				if lost > 0:
					gaps.append("%s@%s %s 露出 %d 點" % [n, f.t, b[2] + "/" + b[0], lost])
	check(gaps.is_empty(), "關節露縫：%s" % ", ".join(gaps))
	r.free()
	h.free()


## MV-TUNE-003：近側翅膀真的往上拍／張開（負值＝上抬）；待機類只稍微放寬
func test_macaw_wings_flap() -> void:
	var d := anims()
	if d.is_empty():
		check(false, "沒有動作檔")
		return
	for n in ANIM_NAMES:
		var lo := INF
		var hi := -INF
		for f in d.anims.get(n, {}).get("frames", []):
			var w: float = f.get("bones", {}).get("wing_arm", 0.0)
			lo = minf(lo, w)
			hi = maxf(hi, w)
		if FLAPS.has(n):
			check(lo <= -20.0 and hi - lo >= 35.0, "%s 拍翅：wing_arm 最小 %s ≤ −20、幅度 %s ≥ 35" % [n, lo, hi - lo])
		elif SPREADS.has(n):
			check(lo <= -15.0, "%s 張翅：wing_arm 最小 %s ≤ −15" % [n, lo])
		else:
			check(lo >= -8.0, "%s 待機類：wing_arm 最小 %s ≥ −8" % [n, lo])


## MV-TUNE-003：每個動作每一格、面向 ±1，肩膀關節周圍 SHOULDER_BOX px 方框內被輪廓包住的透明像素 ≤ HOLE_PX
func test_macaw_no_shoulder_hole() -> void:
	var d := anims()
	if d.is_empty():
		check(false, "沒有動作檔")
		return
	var r := make_rig()
	var images := {}
	for s in r.find_children("*", "Sprite2D", true, false):
		images[s] = s.texture.get_image()
	var holes := []
	for facing in [1, -1]:
		r.scale.x = facing
		for n in ANIM_NAMES:
			for f in d.anims[n].frames:
				r.pose(n, f.t)
				var k := shoulder_holes(r, images)
				if k > HOLE_PX:
					holes.append("%s@%s 面向 %d：%d px" % [n, f.t, facing, k])
	check(holes.is_empty(), "肩膀露洞：%s" % ", ".join(holes))
	r.free()


## 肩膀方框外擴 SHOULDER_MARGIN 取不透明遮罩（同 rig_mask：像素中心反推到分件、Alpha > 0.5），
## 從外框邊界沿透明像素填滿背景；回傳方框內沒填到的透明像素數
func shoulder_holes(r: Node2D, images: Dictionary) -> int:
	var c: Vector2 = r.joint_global("shoulder")
	var half := SHOULDER_BOX + SHOULDER_MARGIN
	var n := half * 2
	var x0 := floori(c.x) - half
	var y0 := floori(c.y) - half
	var region := Rect2(x0, y0, n, n)
	var on := PackedByteArray()
	on.resize(n * n)
	for s in images:
		if not s.is_visible_in_tree():
			continue
		var img: Image = images[s]
		if not (s.global_transform * Rect2(s.offset, img.get_size())).intersects(region):
			continue
		var inv: Transform2D = s.global_transform.affine_inverse()
		for y in n:
			for x in n:
				if on[y * n + x]:
					continue
				var t: Vector2 = inv * Vector2(x0 + x + 0.5, y0 + y + 0.5) - s.offset
				var tx := floori(t.x)
				var ty := floori(t.y)
				if tx >= 0 and ty >= 0 and tx < img.get_width() and ty < img.get_height() and img.get_pixel(tx, ty).a > 0.5:
					on[y * n + x] = 1
	var stack: Array[int] = []
	for i in n:
		stack.append_array([i, (n - 1) * n + i, i * n, i * n + n - 1])
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if on[i]:
			continue
		on[i] = 2  # 背景
		var x := i % n
		var y := i / n
		if x > 0: stack.append(i - 1)
		if x < n - 1: stack.append(i + 1)
		if y > 0: stack.append(i - n)
		if y < n - 1: stack.append(i + n)
	var count := 0
	for y in range(SHOULDER_MARGIN, SHOULDER_MARGIN + SHOULDER_BOX * 2):
		for x in range(SHOULDER_MARGIN, SHOULDER_MARGIN + SHOULDER_BOX * 2):
			if on[y * n + x] == 0:
				count += 1
	return count


## Review Focus 1、SLICE-b2b-7：每個動作每一格、面向 ±1、三段，光源＝頭骨上的光點（±4 px），且落在看得到的頭件上
func test_macaw_light_on_head_every_frame() -> void:
	var d := anims()
	var s := rigged_macaw()
	var b = s[0]
	var a = s[1]
	if a == null or d.is_empty():
		check(false, "沒有 animator 或動作檔")
		b.free()
		return
	var r = b.get_node("Rig")
	var bad := []
	var n_checked := 0
	var mirror := {}  # 面向 −1 的光源位置：面向 +1 時應左右鏡射
	for ph in [1, 2, 3]:
		b.phase = ph
		b.set_appearance(ph - 1)
		var pt: Dictionary = r.points[Macaw.LIGHT_NAMES[ph - 1]]
		for facing in [-1, 1]:
			b.facing = facing
			for n in d.anims:
				for f in d.anims[n].frames:
					a.pose_at(n, f.t)
					var head: Bone2D = r.bone(pt.bone)
					var want: Vector2 = b.to_local(head.global_transform * RigView.v(pt.at))
					var got: Vector2 = b.light.position
					var spr: Sprite2D = r.sprite(HEAD_PARTS[ph - 1])
					var img: Image = spr.texture.get_image()
					var px: Vector2 = spr.global_transform.affine_inverse() * b.to_global(got) - spr.offset
					var on_art: bool = spr.visible and Rect2(Vector2.ZERO, img.get_size()).has_point(px) and img.get_pixelv(Vector2i(px)).a > 0.5
					n_checked += 1
					var key := "%d %s %s" % [ph, n, f.t]
					if facing < 0:
						mirror[key] = got
					var flipped: bool = facing < 0 or got.distance_to(mirror[key] * Vector2(-1, 1)) <= 0.01
					if got.distance_to(want) > LIGHT_PX or not on_art or not flipped:
						bad.append("第%d段 面向%d %s@%s：光源 %s、光點 %s、在頭件上 %s、左右鏡射 %s" % [ph, facing, n, f.t, got, want, on_art, flipped])
	check(bad.is_empty(), "光源離開頭件（%d/%d）：%s" % [bad.size(), n_checked, ", ".join(bad.slice(0, 6))])
	b.free()


## SLICE-b2b-8：appearance 0～3 各只顯示對應的頭件
func test_macaw_head_swaps_with_appearance() -> void:
	var s := rigged_macaw()
	var b = s[0]
	var a = s[1]
	if a == null:
		check(false, "沒有 animator")
		b.free()
		return
	var r = b.get_node("Rig")
	for st in 4:
		b.set_appearance(st)
		a._apply()
		var shown: Array = HEAD_PARTS.filter(func(n): return r.sprite(n).visible)
		check(shown == [HEAD_PARTS[st]], "外觀 %d 只顯示 %s（%s）" % [st, HEAD_PARTS[st], shown])
	b.free()


## 有 GameState 的 Boss 戰：Seven Macaw 是骨架、沒有立繪；隱藏、停在場邊、跌落時骨架與光源照常更新（Review Focus 3）
func test_boss_fight_uses_macaw_rig() -> void:
	var f: Array = await macaw_fight()
	var fight = f[0]
	var b = fight.boss
	var r = b.get_node_or_null("Rig")
	check(r != null and r.cid == C and r.show_behind_parent, "Boss 底下有 Seven Macaw 的骨架、畫在訊號後面")
	check(b.get_node_or_null("MacawAnimator") != null and b.portrait_drawn, "有 MacawAnimator、不畫灰盒身體")
	check(b.get_node_or_null("Portrait") == null, "沒有 Seven Macaw 的立繪")
	check(fight.couple.all(func(n): return n.get_node_or_null("NpcAnimator") != null and n.get_node_or_null("Portrait") == null), "老夫婦是骨架（MV-SLICE-001b2b2）")
	if r != null:
		var on_point := func() -> bool:
			var want: Vector2 = r.point(Macaw.LIGHT_NAMES[b.phase - 1]) * Vector2(r.scale.x, 1)
			return b.light.position.distance_to(want) <= LIGHT_PX
		await frames(2)
		check(on_point.call(), "停在場邊（park）：光源在頭上的光點（%s）" % b.light.position)
		fight.start_at(1)
		await frames(2)
		b.deactivate()
		b.position = Nance.CANOPY
		b.state = b.State.GAP
		b.add_gauge(fight.tn.gauge_max)
		await frames(3)
		check(b._falling and b.get_node("MacawAnimator").choose(b)[0] == "fall" and on_point.call(), "第 1 段樹冠上破綻滿：跌落動作、光源跟著頭")
		b.deactivate(true)
		await frames(3)
		check(on_point.call(), "隱藏後骨架與光源照常更新")
	await free_fight(fight)
	f[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


# ---- Task 7：判定框（SLICE-b2b-6）----

## 骨架站姿「身體＋腳」分件的不透明外框：面向右（基準圖面向左，scale.x −1 翻過來）、相對原點
func measured_body() -> Rect2:
	var h := helpers()
	var r := make_rig()
	r.scale.x = -1.0
	for s in r.find_children("*", "Sprite2D", true, false):
		s.visible = false
	for n in BODY_PARTS:
		r.sprite(n).visible = true
	var box: Rect2 = h.visible_bounds(r)
	r.free()
	h.free()
	return box


func rect_near(a: Rect2, b: Rect2, px: float) -> bool:
	return absf(a.position.x - b.position.x) <= px and absf(a.position.y - b.position.y) <= px \
		and absf(a.end.x - b.end.x) <= px and absf(a.end.y - b.end.y) <= px


## CollisionShape2D 的矩形（本地座標）
func shape_rect(cs: CollisionShape2D) -> Rect2:
	var sz: Vector2 = cs.shape.size
	return Rect2(cs.position - sz / 2.0, sz)


## 面向右的框依面向翻
func faced(r: Rect2, facing: int) -> Rect2:
	return r if facing > 0 else Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)


## SLICE-b2b-6：BODY＝骨架站姿身體＋腳的外框；Boss 的 body_rect、受擊框、攻擊框（打到角色）都用它，兩個面向
func test_macaw_body_matches_rig() -> void:
	var scr = animator_script()
	var want := measured_body()
	var body = scr.get_script_constant_map().get("BODY") if scr != null else null
	check(body is Rect2 and rect_near(body, want, BODY_PX), "MacawAnimator.BODY %s＝骨架站姿身體＋腳的外框 %s（±%d px）" % [body, want, BODY_PX])
	if not (body is Rect2):
		return
	var s := rigged_macaw()
	var b = s[0]
	check(b.get("body_rect") == body, "boss.body_rect＝BODY（%s）" % [b.get("body_rect")])
	for facing in [1, -1]:
		b.facing = facing
		b.configure_body_hitbox()
		var r := faced(body, facing)
		var hurt := shape_rect(b.hurtbox.get_child(0))
		var hit := shape_rect(b.hitbox.shape)
		check(rect_near(hurt, r, 0.01), "面向 %d：受擊框 %s＝%s" % [facing, hurt, r])
		check(rect_near(hit, r, 0.01), "面向 %d：攻擊框 %s＝%s" % [facing, hit, r])
	b.free()


## Review Focus 5：沒有骨架（make_fight）時照舊：身體 SIZE、攻擊框 SIZE×1.1、光源在 LIGHT_OFFSETS
func test_macaw_without_rig_keeps_greybox_boxes() -> void:
	var f = await make_fight(2)
	var b = f.boss
	check(b.get_node_or_null("Rig") == null and not b.portrait_drawn, "make_fight 的 Boss 沒有骨架")
	var grey := Rect2(-Macaw.SIZE.x / 2.0, -Macaw.SIZE.y, Macaw.SIZE.x, Macaw.SIZE.y)
	var hit_want := Rect2(Vector2(0, -Macaw.SIZE.y / 2.0) - Macaw.SIZE * 0.55, Macaw.SIZE * 1.1)
	check(b.get("body_rect") == grey, "body_rect＝SIZE（%s）" % [b.get("body_rect")])
	for facing in [1, -1]:
		b.facing = facing
		b._place_light()
		b.configure_body_hitbox()
		var hurt := shape_rect(b.hurtbox.get_child(0))
		var hit := shape_rect(b.hitbox.shape)
		check(rect_near(hurt, grey, 0.01), "面向 %d：受擊框 %s＝SIZE" % [facing, hurt])
		check(rect_near(hit, hit_want, 0.01), "面向 %d：攻擊框 %s＝SIZE×1.1 %s" % [facing, hit, hit_want])
		var lw: Vector2 = Macaw.LIGHT_OFFSETS[b.phase - 1] * Vector2(facing, 1)
		check(b.light.position == lw, "面向 %d：光源 %s 在 LIGHT_OFFSETS %s" % [facing, b.light.position, lw])
	await free_fight(f)


## 有骨架的 Boss 戰出一招：角色站在地面 px；roll_at／jump_at ≥ 0：出招後第幾幀按翻滾／跳。
## 回傳角色第一次被 Boss 本身打到的幀（−1＝整招沒被打到；反光柱等別的來源不算）
func strike_player(ph: int, mv: String, px: float, roll_at := -1, jump_at := -1) -> int:
	var f: Array = await macaw_fight()
	var fight = f[0]
	var b = fight.boss
	var p = fight.player
	fight.start_at(ph)
	await frames(2)
	b.deactivate()
	b.position = Nance.CANOPY if ph == 1 else Palace.HOME
	p.position = Vector2(px, Nance.GROUND_Y)
	p.velocity = Vector2.ZERO
	await frames(3)
	var hp: int = p.health.hp
	var hit_at := -1
	b.start_move(mv)
	for i in 300:
		if i == roll_at:
			p.intent.roll_pressed = true
		if i == jump_at:
			p.intent.jump_pressed = true
			p.intent.jump_held = true
		await frames(1)
		if p.health.hp < hp:
			if hit_at < 0 and p.last_hurt_source == b:
				hit_at = i
			hp = p.health.hp
		if b.move == null:
			break
	await free_fight(fight)
	f[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	return hit_at


## SLICE-b2b-6 重驗手感：判定框換成骨架的身體＋腳後，俯衝、撞寶座、失衡撲擊、亂揮翅膀照樣打得到站著的角色，
## 被打到前翻滾（無敵）閃得掉；光束打得到站著的角色、單跳跳得過（招式同 test_boss，Boss 換成有骨架的 Boss 戰）
func test_macaw_moves_still_hit_and_dodge() -> void:
	if animator_script() == null:
		check(false, "沒有 animator")
		return
	var cases := [
		[1, "dive", Nance.CANOPY.x - 500.0],
		[2, "throne_charge", Palace.LEFT + 900.0],
		[2, "flail", Palace.HOME.x - 500.0],
		[3, "stagger_pounce", Palace.HOME.x - 500.0],
	]
	for c in cases:
		var at: int = await strike_player(c[0], c[1], c[2])
		check(at >= 0, "%s 打得到站著的角色" % c[1])
		if at < 0:
			continue
		var rolled: int = await strike_player(c[0], c[1], c[2], maxi(at - ROLL_LEAD, 0))
		check(rolled < 0, "%s：被打到（第 %d 幀）前 %d 幀翻滾閃得掉（實際第 %d 幀被打到）" % [c[1], at, ROLL_LEAD, rolled])
	var beam_at: int = await strike_player(3, "beam", Palace.HOME.x - 500.0)
	check(beam_at >= 0, "光束打得到站著的角色")
	var t := fresh_tuning()
	var jump_at := int((t.beam_charge - 0.1) * Engine.physics_ticks_per_second)
	var jumped: int = await strike_player(3, "beam", Palace.HOME.x - 500.0, -1, jump_at)
	check(jumped < 0, "蓄力結束前 0.1 秒單跳跳得過光束（實際第 %d 幀被打到）" % jumped)


# ---- Final review 修正：往左牆走的招式夾在「身體框半寬」而不是舊灰盒的 90 ----

## 把 move 跑到結束追逐／撲擊（最多 600 幀）；回傳整段中身體框左緣（世界座標）的最小值。
## 角色放在左牆外很遠，逼 Boss 走到被夾住的位置。
func left_edge_while(b, mv: String, facing: int) -> float:
	var tgt := Node2D.new()
	add_child(tgt)
	tgt.global_position = Vector2(Palace.LEFT - 500.0, b.global_position.y)
	b.target = tgt
	b.facing = facing
	b.position.x = Palace.LEFT + 200.0
	set_move(b, mv, 0)
	if mv == "stagger_pounce":
		b.move.begin()
	var lo := INF
	for i in 600:
		b.move.tick(1.0 / 60.0)
		lo = minf(lo, b.position.x + b.faced_body().position.x)
		if mv == "flail" and b.move.step != Flail.Step.CHASE:
			break
		if mv == "stagger_pounce" and b.move.step == StaggerPounce.Step.REST:
			break
	tgt.free()
	return lo


## 剛才那一招夾住的位置：撲擊看目標點，亂揮看 Boss 停下的 x
func wall_x(b, mv: String) -> float:
	return b.move.aim_x if mv == "stagger_pounce" else b.position.x


func test_wall_clamp_uses_body_half_width() -> void:
	if animator_script() == null:
		check(false, "缺 world/macaw_animator.gd")
		return
	for mv in ["stagger_pounce", "flail"]:
		for facing in [1, -1]:
			var s := rigged_macaw()
			var b = s[0]
			var half: float = maxf(-b.body_rect.position.x, b.body_rect.end.x)
			check(half > 90.0, "有骨架：身體半寬 %s 大於舊灰盒 90" % half)
			var lo: float = left_edge_while(b, mv, facing)
			check(lo >= Palace.LEFT - 0.01, "%s 面向 %d：身體框左緣 %s 不超出左牆 %s" % [mv, facing, lo, Palace.LEFT])
			check(absf(wall_x(b, mv) - (Palace.LEFT + half)) <= 0.01, "%s：夾在 LEFT+半寬 %s（實際 %s）" % [mv, Palace.LEFT + half, wall_x(b, mv)])
			b.free()


func test_wall_clamp_greybox_stays_90() -> void:
	for mv in ["stagger_pounce", "flail"]:
		var b = Macaw.new()
		add_child(b)
		b.set_physics_process(false)
		check(b.body_rect == Rect2(-Macaw.SIZE.x / 2.0, -Macaw.SIZE.y, Macaw.SIZE.x, Macaw.SIZE.y), "沒有骨架：body_rect＝SIZE")
		left_edge_while(b, mv, 1)
		check(is_equal_approx(wall_x(b, mv), Palace.LEFT + 90.0), "%s 灰盒：夾在 LEFT+90（x=%s）" % [mv, wall_x(b, mv)])
		b.free()
