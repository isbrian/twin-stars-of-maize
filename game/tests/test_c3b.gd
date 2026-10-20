extends "res://tests/base_test.gd"
# MV-SLICE-001c3b：地面事件的素材與動作（MV-ASSET-020 七張圖、新動作、過場換裝）。

const ART := {  # 檔名 → 遊戲高度（px）
	"prop_animal_deer": 170, "prop_animal_rabbit": 60, "prop_animal_coati": 70,
	"prop_food_corn": 50, "prop_food_beans": 25, "prop_tail_deer": 30, "prop_tail_rabbit": 30,
}


func test_c3b_art_present_and_sized() -> void:
	for n in ART:
		var t = load("res://art/prop/%s.png" % n)
		check(t != null, n + " 存在")
		if t != null:
			var h: int = t.get_height()
			check(absf(h - ART[n]) <= ART[n] * 0.1, "%s 高 %d（應約 %d）" % [n, h, ART[n]])


func test_c3b_art_corners_transparent() -> void:
	for n in ART:
		var t = load("res://art/prop/%s.png" % n)
		if t == null:
			check(false, n + " 存在")
			continue
		var img: Image = t.get_image()
		var w := img.get_width() - 1
		var h := img.get_height() - 1
		var ok := true
		for c in [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]:
			if img.get_pixelv(c).a >= 32.0 / 255.0:  # 同 import_art.py 的 ALPHA_MIN：裁到內容外框後，碰到邊的抗鋸齒（長鼻浣熊尾巴尖 3／255）不算
				ok = false
		check(ok, n + " 四角透明（去背成功）")


# ---- Task 2：新動作 ----

const RigView := preload("res://world/rig_view.gd")


func anims_of(cid: String) -> Dictionary:
	var r := RigView.new()
	r.build(cid)
	var d: Dictionary = RigView.anims_at(r.anims_path).anims
	r.free()
	return d


func anim_length(a: Dictionary) -> float:
	return a.get("length", a.frames[-1].t + 1.0 / 12.0)


func test_c3b_anims_present() -> void:
	for cid in ["hunahpu", "xbalanque"]:
		var a := anims_of(cid)
		check(a.has("plant") and a.has("grab"), cid + " 有 plant、grab")
		if a.has("plant") and a.has("grab"):
			check(not a.plant.get("loop", false) and not a.grab.get("loop", false), cid + " plant、grab 不循環")
	var rat := anims_of("rat")
	for n in ["climb", "gnaw", "talk"]:
		check(rat.has(n) and rat[n].get("loop", false), "老鼠有循環的 " + n)
	var x := anims_of("xmucane")
	check(x.has("doze") and x.doze.get("loop", false), "祖母有循環的 doze")
	if x.has("doze"):
		var l := anim_length(x.doze)
		check(l >= 1.8 and l <= 2.4, "doze 約 2 秒一次起伏（%.2f）" % l)


func test_grab_ends_with_hand_forward() -> void:
	var r := RigView.new()
	add_child(r)
	r.build("hunahpu")
	var a: Dictionary = RigView.anims_at(r.anims_path).anims
	if not a.has("grab"):
		check(false, "有 grab")
		r.free()
		return
	r.pose("grab", anim_length(a.grab))
	var hand: Vector2 = r.point("hand_r")
	var shoulder: Vector2 = r.point("upperarm_r")
	var pelvis: Vector2 = r.point("pelvis")
	check(hand.x > shoulder.x, "grab 最後一格近側手在肩膀前方（手 %.0f、肩 %.0f）" % [hand.x, shoulder.x])
	check(hand.y < pelvis.y and hand.y >= shoulder.y - 10.0, "近側手在胸口高度、不高過肩膀（抽格時舉太高像在舉斧頭）（手 %.0f、肩 %.0f、骨盆 %.0f）" % [hand.y, shoulder.y, pelvis.y])
	check(preload("res://world/rig_showcase.gd").weapon_for("grab") == -1, "展示時 grab 空手（握著的是尾巴）")
	r.free()


# ---- Task 3：過場換上正式素材與動作 ----

const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const EventRunner := preload("res://events/event_runner.gd")
const Index := preload("res://world/rooms/index.gd")
const Silhouette := preload("res://world/cutscene/silhouette.gd")
const TEST_SAVE := "user://test_c3b_slot.json"


func setup(room: String, flags := []) -> Array:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	gs.reset_new_game()
	gs.set_flag("intro_seen")
	for f in flags:
		gs.set_flag(f)
	var flow = RoomFlow.new()
	flow.gs = gs
	flow.tn = gs.tn
	flow.rooms = Index.ROOMS
	flow.fade_time = 0.0
	flow.save_path = TEST_SAVE
	add_child(flow)
	var runner = EventRunner.new()
	runner.flow = flow
	runner.gs = gs
	add_child(runner)
	flow.start(room)
	await wait_until(func(): return not flow.is_busy(), 30)
	flow.current.player.scripted = true
	await frames(2)
	return [flow, runner, gs]


func teardown(s: Array) -> void:
	Engine.time_scale = 1.0
	s[1].queue_free()
	s[0].queue_free()
	await frames(2)
	s[2].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func props_of(s: Array, kind: String) -> Array:
	return s[0].current.get_children().filter(func(c): return c.get("kind") == kind and not c.is_queued_for_deletion() and c.get("decor") != true)


func clear_field(s: Array) -> void:
	var p = s[0].current.player
	for c in props_of(s, "bush") + props_of(s, "clod"):
		p.attack_weapon = Weapons.Weapon.AXE if c.kind == "bush" else Weapons.Weapon.STICK
		c.hurtbox.receive(4, p, &"melee")
		await frames(1)


## 看著過場跑完（skip＝一開始就跳過；否則 scale 倍速）：記下替身播過的動作、出現過的粒子、手上拿過的東西、尾巴位置
func watch(s: Array, skip := false, scale := 8.0) -> Dictionary:
	var seen := {"anims": {}, "particles": false, "held": [], "tail_pos": []}
	if not await wait_until(func(): return s[1].cutscene_running(), 600):
		return seen
	var cs = s[1].cutscene
	if skip:
		cs.skipped = true
	else:
		Engine.time_scale = scale
	while cs.running:
		var cast: Node = cs.get_node("Cast")
		for a in cast.get_children():
			if a.get("cid") != null and a.get("anim") != null:
				seen.anims[a.cid + ":" + a.anim] = true
			if a.get("held") != null and is_instance_valid(a.held):
				var k = a.held.get("kind")
				if not seen.held.has(k):
					seen.held.append(k)
				if k == "tail_deer":  # [替身位置, 尾巴與近側手的距離]
					var hand: Vector2 = a.to_global(a.rig.transform * a.rig.point("hand_r"))
					seen.tail_pos.append([a.position, (a.held.global_position - hand).length()])
		if not cast.find_children("*", "CPUParticles2D", true, false).is_empty():
			seen.particles = true
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await frames(3)
	return seen


func any_anim(seen: Dictionary, anim: String) -> bool:
	return seen.anims.keys().any(func(k): return k.ends_with(":" + anim))


func test_silhouettes_use_art() -> void:
	var files := {"deer": "prop_animal_deer", "rabbit": "prop_animal_rabbit", "critter": "prop_animal_coati",
		"tail_deer": "prop_tail_deer", "tail_rabbit": "prop_tail_rabbit", "corn": "prop_food_corn", "beans": "prop_food_beans", "cacao": "prop_cacao_bean"}
	for k in files:
		var sil = Silhouette.new()
		sil.kind = k
		add_child(sil)
		check(sil.texture != null and sil.texture.resource_path == "res://art/prop/%s.png" % files[k], k + " 畫正式圖 " + files[k])
		var animal: bool = k in ["deer", "rabbit", "critter"]
		var night = load("res://world/cutscene/silhouette.gd").get_script_constant_map().get("ANIMAL_NIGHT")
		check(night != null and sil.modulate.is_equal_approx(night if animal else Color.WHITE), k + (" 夜色" if animal else " 原色"))
		sil.free()


func test_dusk_plants_and_chops() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	var seen: Dictionary = await watch(s)
	check(any_anim(seen, "plant"), "收工時兄弟倆播 plant（%s）" % [seen.anims.keys()])
	check(seen.particles, "工具揮砍時掉碎屑（CPUParticles2D）")
	await teardown(s)


func test_dusk_skip_leaves_no_particles() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	await clear_field(s)
	await watch(s, true)
	var r = s[0].current
	check(r.find_children("*", "CPUParticles2D", true, false).is_empty(), "跳過收工後沒有留下碎屑粒子")
	await teardown(s)


func test_tail_follows_hand() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared"])
	var seen: Dictionary = await watch(s, false, 4.0)
	check(any_anim(seen, "grab"), "撲完播 grab")
	check(seen.held.has("tail_deer") and seen.held.has("tail_rabbit"), "兄弟倆手上握著鹿尾與兔尾（%s）" % [seen.held])
	var moved := false
	var follows := true
	var tp: Array = seen.tail_pos
	if tp.size() >= 2:
		moved = (tp[-1][0] - tp[0][0]).length() > 50.0
		follows = tp.all(func(e): return e[1] < 2.0)
	check(moved and follows, "兄弟倆後退時尾巴跟著手走（%s 筆、移動 %s、最大距離 %.1f）" % [tp.size(), moved, tp.map(func(e): return e[1]).max() if tp.size() > 0 else -1.0])
	var left: Array = s[0].current.find_children("*", "", true, false).filter(func(n): return n.get("kind") in ["tail_deer", "tail_rabbit"])
	check(left.is_empty(), "交還後尾巴不在場上")
	await teardown(s)


func test_rat_talks_in_deal() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])
	var rat = props_of(s, "rat")[0]
	var p = s[0].current.player
	p.position = Vector2(rat.position.x + 200, 900)
	p.intent.move_x = -1.0
	await wait_until(func(): return s[1].cutscene_running(), 600)
	p.intent.move_x = 0.0
	var seen: Dictionary = await watch(s)
	check(seen.anims.has("rat:talk"), "老鼠開口時播 talk（%s）" % [seen.anims.keys()])
	await teardown(s)


func test_rope_climb_and_gnaw() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	var seen: Dictionary = await watch(s)
	check(seen.anims.has("rat:climb") and seen.anims.has("rat:gnaw"), "咬繩時播 climb、gnaw（%s）" % [seen.anims.keys()])
	await teardown(s)


func test_gear_pickup_at_handover() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	await wait_until(func(): return s[1].cutscene_running(), 120)
	s[1].cutscene.skipped = true
	var at_handover := [false]
	await wait_until(func():
		if s[0].current.pickups.size() == 1 and s[1].cutscene_running():
			at_handover[0] = true
		return not s[1].cutscene_running(), 120)
	check(at_handover[0], "黑邊還在收的時候地上就有可撿的球具（不再空 0.4 秒）")
	await frames(5)
	check(s[0].current.pickups.size() == 1, "只有一個球具（%d）" % s[0].current.pickups.size())
	await teardown(s)


func test_grandmother_dozes_when_asleep() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	var r = s[0].current
	check(r.npc_anim.anim == "doze", "進門時祖母已經在打盹（%s）" % r.npc_anim.anim)
	await watch(s, true)
	check(r.npc_anim.anim == "doze", "咬繩後祖母還在打盹")
	var p = r.player
	p.position = r.pickups[0].position
	await frames(2)
	p.intent.interact_pressed = true
	await frames(2)
	await watch(s, true)
	await frames(3)
	check(r.npc_anim.anim == "idle", "天亮後祖母醒來（%s）" % r.npc_anim.anim)
	await teardown(s)


## 球具一落地就可撿：黑邊還在收時就撿起，天亮仍要播（不然 gear_picked 沒人接、拿不到 gear_obtained）
func test_pick_gear_during_handover_still_morning() -> void:
	var s: Array = await setup("home", ["tools_obtained", "field_cleared", "night_seen", "rat_caught"])
	var gs = s[2]
	var r = s[0].current
	await wait_until(func(): return s[1].cutscene_running(), 120)
	s[1].cutscene.skipped = true
	await wait_until(func(): return r.pickups.size() == 1, 120)
	check(s[1].cutscene_running(), "前提：撿的時候黑邊還在收")
	r.player.position = r.pickups[0].position
	r.player.intent.interact_pressed = true
	await frames(2)
	check(gs.weapons_owned.has(Weapons.Weapon.BALLGEAR), "撿到球具")
	await wait_until(func(): return not s[1].cutscene_running(), 120)  # 咬繩的黑邊收完
	var morning: bool = await wait_until(func(): return s[1].cutscene_running(), 120)
	if morning:
		s[1].cutscene.skipped = true
		await wait_until(func(): return not s[1].cutscene_running(), 120)
	check(morning and gs.has_flag("gear_obtained"), "天亮照樣播、gear_obtained")
	await teardown(s)


## 收工從門口（最遠）開始也要留 2 秒餘裕（最終審查：加了揮砍後約 27.7 秒，貼著規格的 28 秒上限，畫面慢時會偶發失敗）
func test_dusk_length_has_margin() -> void:
	var s: Array = await setup("field", ["tools_obtained"])
	var p = s[0].current.player
	p.position.x = s[0].current.data.size.x - 220.0  # 門口
	await frames(2)
	await clear_field(s)
	p.position.x = s[0].current.data.size.x - 220.0
	await wait_until(func(): return s[1].cutscene_running(), 120)
	var cs = s[1].cutscene
	var t0: float = cs._t
	var seen_night := [-1.0]
	await wait_until(func():
		if seen_night[0] < 0.0 and cs.get_node("Cast").get_children().any(func(n): return n.get("kind") == "deer"):  # 動物復原開始＝收工結束
			seen_night[0] = cs._t
		return seen_night[0] >= 0.0, 3000)
	var dusk: float = seen_night[0] - t0
	print("C3B dusk_from_door=%.2f" % dusk)
	check(dusk > 0.0 and dusk <= 26.0, "從門口開始的收工 ≤ 26 秒（%.2f）" % dusk)
	cs.skipped = true
	await wait_until(func(): return not s[1].cutscene_running(), 120)
	await teardown(s)
