extends "res://tests/base_test.gd"
# MV-SLICE-001b1 Task 5：角色的靜態立繪（SLICE-b10、SLICE-b12）。

const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const Index := preload("res://world/rooms/index.gd")
const TEST_SAVE := "user://test_portraits_slot.json"
const OPEN := Vector2(14800, 900)  # 宮殿兩座低台（14300～14620、15150～15470）之間的地面：Boss 頭上沒有平台


func setup(room: String) -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.set_flag("intro_seen")
	for w in [Weapons.Weapon.AXE, Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
		gs.give_weapon(w)
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


func teardown(s: Array) -> void:
	s[0].queue_free()
	await frames(2)
	s[1].free()


func gs_fight() -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	for w in [Weapons.Weapon.AXE, Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
		gs.give_weapon(w)
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


func free_gs_fight(s: Array) -> void:
	await free_fight(s[0])
	s[1].free()


## 雙胞胎的骨架（MV-SLICE-001b2a，取代 b1 的立繪）：看得到的分件不透明像素在玩家座標的外框
func rig_bounds(p: Node2D) -> Rect2:
	var a = p.get_node("TwinAnimator")
	var box := Rect2()
	var first := true
	for spr in a.rigs[p.twin_index].find_children("*", "Sprite2D", true, false):
		if not spr.is_visible_in_tree():
			continue
		var img: Image = spr.texture.get_image()
		var xf: Transform2D = p.global_transform.affine_inverse() * spr.global_transform
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y).a > 0.5:
					var q: Vector2 = xf * (Vector2(x + 0.5, y + 0.5) + spr.offset)
					box = Rect2(q, Vector2.ZERO) if first else box.expand(q)
					first = false
	return box


func test_twin_portrait_height_and_feet() -> void:
	var s: Array = await setup("forest_1")
	var p = s[0].current.player
	check(p.get_node_or_null("Portrait") == null and p.get_node_or_null("TwinAnimator") != null, "雙胞胎是骨架、不是立繪")
	if p.get_node_or_null("TwinAnimator") == null:
		await teardown(s)
		return
	var b := rig_bounds(p)
	check(absf(b.size.y - 180.0) <= 9.0 and absf(b.end.y) <= 2.0, "雙胞胎骨架高 180±9、腳底在原點（高 %.0f、底 %.1f）" % [b.size.y, b.end.y])
	var rigs: Array = p.get_node("TwinAnimator").rigs
	check(rigs[0].visible and not rigs[1].visible, "開場是胡納普的骨架")
	p.intent.swap_pressed = true
	await frames(3)
	check(rigs[1].visible and not rigs[0].visible, "換人後只顯示希巴拉克的骨架")
	await teardown(s)


func test_portrait_flips_with_facing() -> void:
	var s: Array = await setup("forest_1")
	var p = s[0].current.player
	var a = p.get_node_or_null("TwinAnimator")
	check(a != null, "雙胞胎是骨架")
	if a != null:
		p.facing = -1
		a._apply()
		check(a.rigs[p.twin_index].scale.x < 0.0, "面向左（基準圖面向右）→ 骨架翻面")
		p.facing = 1
		a._apply()
		check(a.rigs[p.twin_index].scale.x > 0.0, "面向右 → 不翻")
	var e = s[0].current.enemies[0]
	e.facing = 1
	e.get_node("EnemyAnimator")._apply()
	check(e.get_node("Rig").scale.x < 0.0, "造物的基準圖面向左：面向右時骨架翻面（MV-SLICE-001b2b1 換成骨架）")
	await teardown(s)


## Review Focus 2：立繪畫在父節點後面，前搖輪廓、訊號、光環、裂紋都在它上面
func test_portrait_drawn_behind_signals() -> void:
	var s: Array = await setup("forest_1")
	var p = s[0].current.player
	var e = s[0].current.enemies[0]
	var pr = e.get_node_or_null("Rig")
	check(pr != null and pr.show_behind_parent and e.portrait_drawn, "%s 的骨架在訊號後面、不畫灰盒身體" % e.name)
	var a = p.get_node_or_null("TwinAnimator")
	check(a != null and a.rigs.all(func(r): return r.show_behind_parent) and p.portrait_drawn, "雙胞胎的骨架在訊號後面、不畫灰盒身體")
	await teardown(s)
	var f: Array = await gs_fight()
	var br = f[0].boss.get_node_or_null("Rig")
	check(br != null and br.show_behind_parent and f[0].boss.portrait_drawn, "Seven Macaw 的骨架在訊號後面（MV-SLICE-001b2b1 換成骨架）")
	await free_gs_fight(f)


## Review Focus 5：受擊閃白、翻滾無敵與受擊無敵的半透明
func test_portrait_shows_hit_and_invuln() -> void:
	var s: Array = await setup("forest_1")
	var e = s[0].current.enemies[0]
	e.flash_left = 0.1
	e.get_node("EnemyAnimator")._apply()
	check(e.get_node("Rig").modulate.r > 1.0, "敵人受擊閃白")
	var p = s[0].current.player
	var a = p.get_node_or_null("TwinAnimator")
	check(a != null, "雙胞胎是骨架（顏色規則見 test_twin_animator.test_rig_tint_rules）")
	if a != null:
		p.health.invuln_left = 0.14  # int(0.14 × 15) ＝ 2：閃爍的「暗」幀
		a._apply()
		check(is_equal_approx(a.rigs[p.twin_index].modulate.a, 0.3), "實際房間：受擊無敵的閃爍幀 alpha 0.3")
	await teardown(s)


## Review Focus 4：Seven Macaw 的外觀跟著段落
func test_macaw_appearance_follows_phase() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	fight.begin_at_rest("palace_camp")
	check(fight.boss.appearance == 1, "宮殿篝火繼續：下顎受傷（是 %d）" % fight.boss.appearance)
	fight.start_at(3)
	check(fight.boss.appearance == 2, "第 3 段：失去玉牙")
	fight._retry(2)
	check(fight.boss.appearance == 1, "死亡重試回第 2 段：下顎受傷")
	fight.start_at(4)
	check(fight.boss.appearance == 3, "覺醒後：失去眼睛")
	await free_gs_fight(f)


## MV-SLICE-001b2b1：Seven Macaw 換成骨架（world/macaw_animator.gd），高度與底邊照 b1 立繪
func test_macaw_rig_about_450() -> void:
	var f: Array = await gs_fight()
	var b = f[0].boss
	var h = load("res://tests/test_enemy_rig.gd").new()
	var box: Rect2 = h.visible_bounds(b.get_node("Rig"))
	h.free()
	box.position -= b.global_position
	# 規格驗收「站姿高度與 b1 立繪相同（±5%）」；待機時遠側翅膀從近側後面露出一點，比靜止姿勢高幾 px
	check(absf(box.size.y - 450.0) <= 450.0 * 0.05 and absf(box.end.y) <= 2.0, "Seven Macaw 骨架高 450±5%%、底邊在腳底（%s）" % box)
	await free_gs_fight(f)


# ---- Seven Macaw 的弱點對到畫面（Brian 試玩 b1，2026-10-11：弱點打不中）----

## 骨架分件 names 的不透明像素（Alpha > 0.5）在 Boss 區域座標的外框
func macaw_parts_box(b, names: Array) -> Rect2:
	var r = b.get_node("Rig")
	var box := Rect2()
	var first := true
	for n in names:
		var spr: Sprite2D = r.sprite(n)
		var img: Image = spr.texture.get_image()
		var xf: Transform2D = b.global_transform.affine_inverse() * spr.global_transform
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y).a > 0.5:
					var q: Vector2 = xf * (Vector2(x + 0.5, y + 0.5) + spr.offset)
					box = Rect2(q, Vector2.ZERO) if first else box.expand(q)
					first = false
	return box


## 兩隻腳爪左右範圍的中點落在 Boss 原點 ±20 px（兩個面向）
func test_macaw_feet_on_origin() -> void:
	var f: Array = await gs_fight()
	var b = f[0].boss
	for facing in [-1, 1]:
		b.facing = facing
		b.get_node("MacawAnimator")._apply()
		var box := macaw_parts_box(b, ["claw_l", "claw_r"])
		var cx := box.get_center().x
		check(absf(cx) <= 20.0, "面向 %d：腳爪中心在 Boss 原點（是 %.0f，範圍 %.0f～%.0f）" % [facing, cx, box.position.x, box.end.x])
	await free_gs_fight(f)


## 三段的光源各落在看得到的頭件上的下顎（米色喙）、玉牙（綠）、眼睛（青）
func test_macaw_lights_on_art() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	var b = fight.boss
	var r = b.get_node("Rig")
	var a = b.get_node("MacawAnimator")
	var looks := {
		1: func(c: Color) -> bool: return c.r > 0.75 and c.g > 0.65 and c.b < 0.72,
		2: func(c: Color) -> bool: return c.g > c.r + 0.25 and c.g > c.b,
		3: func(c: Color) -> bool: return c.b > c.r + 0.2 and c.g > c.r + 0.2,
	}
	for ph in [1, 2, 3]:
		fight.start_at(ph)
		await frames(2)
		for facing in [-1, 1]:
			b.facing = facing
			a._apply()
			var spr: Sprite2D = r.sprite(a.HEADS[b.appearance])
			var img: Image = spr.texture.get_image()
			var at := Vector2i(spr.global_transform.affine_inverse() * b.light.global_position - spr.offset)
			# 光點周圍 ±3 px（頭件像素）內有該部位的顏色：牙齒之間有墨線，單一像素可能剛好落在線上
			var found := false
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var q := at + Vector2i(dx, dy)
					if spr.visible and Rect2i(Vector2i.ZERO, img.get_size()).has_point(q):
						var c := img.get_pixelv(q)
						found = found or (c.a > 0.5 and looks[ph].call(c))
			check(found, "第 %d 段、面向 %d：光源在頭件 %s 的 %s 上（像素 %s 顏色 %s）" % [ph, facing, a.HEADS[b.appearance], Macaw.LIGHT_NAMES[ph - 1], at, img.get_pixelv(at) if Rect2i(Vector2i.ZERO, img.get_size()).has_point(at) else Color(0, 0, 0, 0)])
	await free_gs_fight(f)


## 受擊框蓋住骨架的軀幹與腳、不蓋住頭（光源不在身體受擊框裡）
func test_macaw_hurtbox_on_torso() -> void:
	var f: Array = await gs_fight()
	var b = f[0].boss
	var cs: CollisionShape2D = b.hurtbox.get_child(0)
	var r := Rect2(cs.position - cs.shape.size / 2.0, cs.shape.size)
	check(r.size.y >= 280.0 and r.size.x >= 200.0, "受擊框夠大（%s）" % r)
	check(r.end.y >= -1.0 and r.has_point(Vector2(0, -150)), "受擊框從腳底往上蓋住軀幹（%s）" % r)
	for ph in [1, 2, 3]:
		b.phase = ph
		b.get_node("MacawAnimator")._apply()
		check(not r.has_point(b.light.position), "第 %d 段的光源不在身體受擊框裡（%s）" % [ph, b.light.position])
	await free_gs_fight(f)


## 從地面用吹箭直線瞄準，射得中每一段的光源（第 1 段在吃果子的樹枝上，第 2、3 段在宮殿地面）
func test_macaw_lights_reachable_by_dart() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	var b = fight.boss
	var pl = fight.player
	for ph in [1, 2, 3]:
		fight.start_at(ph)
		await frames(2)
		b.deactivate()
		b.position = Nance.PERCH if ph == 1 else Palace.HOME
		pl.position = Vector2(b.position.x - 600.0, Nance.GROUND_Y)
		pl.velocity = Vector2.ZERO
		b.facing = -1
		b.get_node("MacawAnimator")._apply()
		b.light.set_state(Light.State.GLOW)
		await frames(3)
		var hits := [0]
		var cb := func(_a, _s, _k): hits[0] += 1
		b.light.hurt.connect(cb)
		pl.blowgun.cooldown_left = 0.0
		pl.blowgun.try_fire(Intent.aim_toward(b.light.global_position - pl.global_position, pl.facing))
		await frames(40)
		b.light.hurt.disconnect(cb)
		check(hits[0] >= 1, "第 %d 段：從 600 px 外的地面射得中光源" % ph)
	await free_gs_fight(f)


## Brian 試玩 2026-10-11：第 1 段破綻滿時他若在樹冠上，下顎在畫面外（8 次亮點 7 次沒射中）→ 跌到低枝，亮點從落定才開始算
func test_macaw_broken_in_canopy_falls_to_branch() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	var b = fight.boss
	fight.start_at(1)
	await frames(2)
	b.deactivate()
	b.position = Nance.CANOPY
	b.state = b.State.GAP
	b.add_gauge(fight.tn.gauge_max)
	check(b.state == b.State.BROKEN and b.light.state == Light.State.BRIGHT, "破綻滿：硬直、光源最亮")
	var landed: bool = await wait_until(func(): return b.position.distance_to(Nance.PERCH) < 4.0, 120)
	check(landed and b.state == b.State.BROKEN, "跌到吃果子的低枝（%s），仍在硬直中" % b.position)
	check(b.light.global_position.y > Nance.VIEW.position.y + 40.0, "下顎在畫面內（y＝%.0f）" % b.light.global_position.y)
	await frames(int((fight.tn.boss_stagger_time - 0.3) * 60.0))
	check(b.state == b.State.BROKEN, "落定後的亮點時間仍是完整的 boss_stagger_time")
	await free_gs_fight(f)


## 原型模式（沒有立繪）照原型：破綻滿時留在原地
func test_macaw_broken_stays_without_portrait() -> void:
	var fight = await make_fight(1)
	var b = fight.boss
	b.deactivate()
	b.position = Nance.CANOPY
	b.state = b.State.GAP
	b.add_gauge(fight.tn.gauge_max)
	await frames(30)
	check(b.state == b.State.BROKEN and b.position.is_equal_approx(Nance.CANOPY), "原型模式：硬直時不移動")
	await free_fight(fight)


## 閘門與木障是要操作的東西，不跟著光源變暗（Brian 試玩：出口時木障看不到）
func test_arena_props_keep_colour_in_dark() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	fight.start_at(4)
	await frames(2)
	check(fight.scenery.modulate.is_equal_approx(Color(0.3, 0.3, 0.3)), "場景暗到 0.3")
	check(fight.palace.modulate.is_equal_approx(Color.WHITE) and fight.nance.modulate.is_equal_approx(Color.WHITE), "閘門與木障保持原色")
	await free_gs_fight(f)


## 一發吹箭從 from 瞄準光源；回傳 [光源被射中次數, 身體被射中次數]
## 角色站在 from 往 aim（預設：光源）射一箭；回傳 [光源被打到次數, 身體被飛鏢打到次數]
func shoot_light(fight, from: Vector2, aim := Vector2.INF) -> Array:
	var b = fight.boss
	var pl = fight.player
	pl.position = from
	pl.velocity = Vector2.ZERO
	await frames(3)
	var hits := [0, 0]
	var on_light := func(_a, _s, _k): hits[0] += 1
	var on_body := func(_a, _s, k): if k == &"dart": hits[1] += 1
	b.light.hurt.connect(on_light)
	b.hurtbox.hurt.connect(on_body)
	pl.blowgun.cooldown_left = 0.0
	var to: Vector2 = b.light.global_position if aim == Vector2.INF else aim
	pl.blowgun.try_fire(Intent.aim_toward(to - pl.global_position, pl.facing))
	await frames(30)
	b.light.hurt.disconnect(on_light)
	b.hurtbox.hurt.disconnect(on_body)
	return hits


const IDLE_CLOCKS := [0.0, 0.0833, 0.1667, 0.25, 0.3333, 0.4167, 0.5, 0.5833, 0.6667, 0.75, 0.8333, 0.9167]  # 待機循環（1 秒、12 格）每一格


## 開打第 ph 段、Boss 停在 at 面向左、光源微亮；animator 停住（動作時間由 pose_idle 設定，射擊期間頭不動）
func light_setup(fight, ph: int, at: Vector2) -> void:
	var b = fight.boss
	fight.start_at(ph)
	await frames(2)
	b.deactivate()
	b.position = at
	b.facing = -1  # 面向左：正面在左邊
	b.get_node("MacawAnimator").set_physics_process(false)
	pose_idle(b, 0.0)
	b.light.set_state(Light.State.GLOW)


func pose_idle(b, clock: float) -> void:
	var a = b.get_node("MacawAnimator")
	a.clock = clock
	a._apply()


## [說明, Boss 腳底, 角色站位, 該不該射中光源]；Boss 面向左（正面在左邊）。
## 第 1 段在樹枝上：樹枝只延伸到 Boss 背後 210 px（再遠站地面、往上射會被樹枝擋），背後取 200。
## 第 2、3 段：HOME 在宮殿低台底下、頭穿過平台（平台擋住從底下往上的箭，SLICE-b2b-5 地形照舊擋），
## 近距離與背後在兩座低台之間的空地（OPEN）射；正面遠 400 在 HOME 射（OPEN 往左 400 會被左邊的低台擋）
func light_cases(ph: int) -> Array:
	var g := Nance.GROUND_Y
	if ph == 1:
		var at := Nance.PERCH
		return [["正面近 100（往上）", at, Vector2(at.x - 100.0, at.y), true], ["正面遠 400", at, Vector2(at.x - 400.0, g), true],
			["背後 200", at, Vector2(at.x + 200.0, at.y), true], ["背後近 100（往上）", at, Vector2(at.x + 100.0, at.y), true]]
	var home := Palace.HOME
	return [["正面近 100（往上）", OPEN, Vector2(OPEN.x - 100.0, g), true], ["正面遠 400", home, Vector2(home.x - 400.0, g), true],
		["背後 250", OPEN, Vector2(OPEN.x + 250.0, g), true], ["背後近 100（往上）", OPEN, Vector2(OPEN.x + 100.0, g), true],
		["低台底下正面 150", home, Vector2(home.x - 150.0, g), false]]


## SLICE-b2b-5（Brian 試玩 2026-10-11：背後射不到、近距離往上射被胸口擋）：身體不擋往光源的箭，地形照舊擋。
## 三段：正面近 100（往上）、正面遠 400、背後、背後近 100（往上）都射得中；站在宮殿低台底下往上射被平台擋。
## 正面近距離在待機循環每一格各射一次（Task 6 審查：頭擺 17 px 曾讓低台擋住）
func test_macaw_light_from_front_back_and_close() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	var b = fight.boss
	for ph in [1, 2, 3]:
		for c in light_cases(ph):
			await light_setup(fight, ph, c[1])
			var clocks: Array = IDLE_CLOCKS if c[0].begins_with("正面近") else [0.0]
			var bad := []
			for k in clocks:
				pose_idle(b, k)
				var h: Array = await shoot_light(fight, c[2])
				if (h[0] >= 1) != c[3]:
					bad.append("待機 %s 秒：光源 %d、身體 %d" % [k, h[0], h[1]])
			check(bad.is_empty(), "第 %d 段：%s（角色在 Boss %s）%s；不符：%s" % [ph, c[0], c[2] - c[1], "射得中光源" if c[3] else "被平台擋、射不到光源", ", ".join(bad)])
	await free_gs_fight(f)


## SLICE-b2b-5：路線上沒有光源（瞄準腳）→ 只打到身體
func test_macaw_body_hit_when_path_misses_light() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	var b = fight.boss
	var at: Vector2 = Palace.HOME
	await light_setup(fight, 2, at)
	for side in [-1, 1]:
		var h: Array = await shoot_light(fight, Vector2(at.x + side * 400.0, Nance.GROUND_Y), at + Vector2(0, -30))
		check(h[0] == 0 and h[1] == 1, "%s 瞄準腳：身體 1、光源 0（身體 %d、光源 %d）" % ["正面" if side < 0 else "背後", h[1], h[0]])
	await free_gs_fight(f)


## Review Focus 2：角色站在 Boss 的受擊框裡（腳邊）往頭射 → 打中光源。
## 第 2 段 Boss 移到兩座宮殿低台之間的空地（HOME 在低台底下，往上射會被平台擋）
func test_dart_from_inside_body_finds_light() -> void:
	var f: Array = await gs_fight()
	var fight = f[0]
	var b = fight.boss
	for ph in [1, 2]:
		var at: Vector2 = Nance.PERCH if ph == 1 else OPEN
		await light_setup(fight, ph, at)
		var from := Vector2(at.x - 20.0, at.y)
		var cs: CollisionShape2D = b.hurtbox.get_child(0)
		var inside: bool = Rect2(b.hurtbox.global_position + cs.position - cs.shape.size / 2.0, cs.shape.size).has_point(from + Vector2(0, -60))
		var h: Array = await shoot_light(fight, from)
		check(inside and h[0] == 1, "第 %d 段：站在受擊框裡（%s）往頭射，打中光源（光源 %d、身體 %d）" % [ph, inside, h[0], h[1]])
	await free_gs_fight(f)


## Review Focus 2：換房、休息很多次，每位玩家恰好兩副骨架、一個 animator，沒有雙胞胎立繪
func test_one_rig_pair_per_player() -> void:
	var s: Array = await setup("home")
	var flow = s[0]
	for i in 5:
		flow.goto("field", "to_home")
		await wait_until(func(): return not flow.is_busy() and flow.current_id == "field", 60)
		flow.goto("home", "to_field")
		await wait_until(func(): return not flow.is_busy() and flow.current_id == "home", 60)
	for i in 2:
		flow.rest_here()
		await wait_until(func(): return not flow.is_busy(), 60)
	await frames(2)
	var p = flow.current.player
	var rigs: Array = p.get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path == "res://world/rig_view.gd")
	var anims: Array = p.get_children().filter(func(c): return c.name == "TwinAnimator")
	check(rigs.size() == 2 and anims.size() == 1, "玩家底下 2 副骨架、1 個 animator（%d、%d）" % [rigs.size(), anims.size()])
	check(p.get_node_or_null("Portrait") == null, "沒有雙胞胎立繪")
	await teardown(s)


## 最終審查 Important 2：Boss 段落的篝火排在玩家前面（同層依樹順序），角色在重生的篝火前面
func test_boss_camps_drawn_behind_twin() -> void:
	var f: Array = await gs_fight()
	var p = f[0].player
	for id in f[0].rests:
		var rp = f[0].rests[id]
		check(rp.get_parent() == p.get_parent() and rp.get_index() < p.get_index(), "%s 的篝火畫在角色後面" % id)
	await free_gs_fight(f)
