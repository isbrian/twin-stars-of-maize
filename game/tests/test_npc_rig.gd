extends "res://tests/base_test.gd"
# MV-SLICE-001b2b2：NPC（祖母、老夫婦、老鼠、Chimalmat）的骨架（tools/cut_rig.py 切件）與動作。
# 遮罩、外框、疊合、關節覆蓋的工具借 test_enemy_rig.gd（只當工具物件用，不加進場景樹、不跑它的測試）。

## 角色 → [現有立繪 key, 遊戲高度]
const NPCS := {
	"xmucane": ["chr_xmucane_reference", 165.0],
	"healer_man": ["chr_healer_man_reference", 170.0],
	"healer_woman": ["chr_healer_woman_reference", 165.0],
	"rat": ["chr_rat_reference", 40.0],
	"chimalmat": ["chr_chimalmat_reference", 340.0],
}
## 角色 → {動作: 是否循環}
const ANIMS := {
	"xmucane": {"idle": true, "give": false, "doze": true},  # doze：睡著（MV-SLICE-001c3b）
	"healer_man": {"idle": true, "walk": true, "reach": false, "pick": false},  # reach、pick：宮殿演出（MV-SLICE-001c2b）
	"healer_woman": {"idle": true, "walk": true, "reach": false, "pick": false},
	"rat": {"idle": true, "run": true, "climb": true, "gnaw": true, "talk": true},  # climb、gnaw、talk：地面過場（MV-SLICE-001c3b）
	"chimalmat": {"idle": true, "collapse": false},
}
const FACES_RIGHT := ["xmucane", "healer_man", "healer_woman", "rat"]  # 基準圖面向右；其餘面向左
const MATCH_PX := 2
const MIN_IOU := 0.9


func helpers() -> Node:
	return load("res://tests/test_enemy_rig.gd").new()


func make_rig(c: String) -> Node2D:
	var r: Node2D = load("res://world/rig_view.gd").new()
	add_child(r)
	r.build(c)
	return r


func test_npc_rig_assembles() -> void:
	var h := helpers()
	for c in NPCS:
		var d: Dictionary = h.rig_json(c)
		check(not d.is_empty(), "%s：game/rig/%s_rig.json 存在" % [c, c])
		if d.is_empty():
			continue
		check(d.get("humanoid", true) == false, "%s：不是人形" % c)
		check(int(d.get("faces", 0)) == (1 if FACES_RIGHT.has(c) else -1), "%s：faces %s" % [c, d.get("faces")])
		check(d.get("anims", "") == "res://rig/%s_anims.json" % c, "%s：動作檔路徑" % c)
		var r := make_rig(c)
		for part in d.parts:
			var short: String = part.substr(("chr_%s_" % c).length())
			var s: Sprite2D = r.sprite(short)
			check(s != null and s.texture != null, "%s：分件 %s 在" % [c, short])
		r.free()
	h.free()


func test_npc_rig_rest_matches_reference() -> void:
	var h := helpers()
	for c in NPCS:
		if h.rig_json(c).is_empty():
			check(false, "%s：沒有 rig" % c)
			continue
		var r := make_rig(c)
		var got: Dictionary = h.rig_mask(r)
		r.free()
		var want: Dictionary = h.image_mask(load("res://art/chr/%s.png" % NPCS[c][0]).get_image())
		check(absi(got.w - want.w) <= MATCH_PX and absi(got.h - want.h) <= MATCH_PX,
			"%s：內容外框 %dx%d（立繪 %dx%d）" % [c, got.w, got.h, want.w, want.h])
		var a: float = h.near_share(got, want)
		var b: float = h.near_share(want, got)
		check(a == 1.0 and b == 1.0, "%s：不透明像素 2 px 內互相涵蓋（骨架→立繪 %.4f、立繪→骨架 %.4f）" % [c, a, b])
		var o: float = h.iou(got, want)
		check(o >= MIN_IOU, "%s：遮罩 IoU %.3f ≥ %.1f" % [c, o, MIN_IOU])
	h.free()


## 立繪的對齊是「圖寬一半、腳底」在原點：骨架的內容中心要和立繪擺上後的內容中心（Alpha > 0.5）一致，換成骨架時 NPC 不會跳
## （老鼠的鬍鬚在 40 px 時幾乎透明，立繪的圖寬一半不等於內容中心）
func test_npc_rest_centred_on_feet() -> void:
	var h := helpers()
	for c in NPCS:
		if h.rig_json(c).is_empty():
			check(false, "%s：沒有 rig" % c)
			continue
		var img: Image = load("res://art/chr/%s.png" % NPCS[c][0]).get_image()
		var lo := img.get_width()
		var hi := -1
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					lo = mini(lo, x)
					hi = maxi(hi, x)
		var want := (lo + hi + 1) / 2.0 - img.get_width() / 2.0
		var r := make_rig(c)
		var b: Rect2 = h.visible_bounds(r)
		check(absf(b.get_center().x - want) <= 1.0, "%s：內容中心 x=%.2f，立繪 %.2f（±1）" % [c, b.get_center().x, want])
		check(absf(b.end.y) <= 1.0, "%s：腳底 y=0±1（%.2f）" % [c, b.end.y])
		check(absf(b.size.y - NPCS[c][1]) <= NPCS[c][1] * 0.05, "%s：高 %d±5%%（%.1f）" % [c, NPCS[c][1], b.size.y])
		r.free()
	h.free()


func test_npc_anims_present() -> void:
	var h := helpers()
	for c in NPCS:
		var d: Dictionary = h.anims_of(c)
		check(not d.is_empty(), "%s：動作檔存在" % c)
		if d.is_empty():
			continue
		check(int(d.get("fps", 0)) == 12, "%s：12 fps" % c)
		var want: Dictionary = ANIMS[c]
		check(d.anims.size() == want.size(), "%s：只有 %s（%s）" % [c, want.keys(), d.anims.keys()])
		var bones: Array = h.rig_json(c).get("bones", []).map(func(x): return x[0])
		for n in want:
			var a: Dictionary = d.anims.get(n, {})
			check(a.get("frames", []).size() >= 1, "%s：有 %s 動作" % [c, n])
			check(a.get("loop", false) == want[n], "%s：%s %s" % [c, n, "循環" if want[n] else "不循環"])
			for f in a.get("frames", []):
				for bn in f.get("bones", {}):
					check(bones.has(bn), "%s：%s 的骨頭 %s 存在" % [c, n, bn])
	h.free()


## 靜止姿勢蓋得住的關節取樣點，每個動作每一格都還蓋得住（同 test_macaw_joints_covered_in_every_frame）
func test_npc_joints_covered_in_every_frame() -> void:
	var h := helpers()
	for c in NPCS:
		var d: Dictionary = h.anims_of(c)
		var rj: Dictionary = h.rig_json(c)
		if d.is_empty() or rj.is_empty():
			check(false, "%s：沒有動作檔或 rig" % c)
			continue
		var r := make_rig(c)
		var images := {}
		for b in rj.bones:
			var s: Sprite2D = r.sprite(b[0])
			if s != null:
				images[b[0]] = s.texture.get_image()
		var rest := {}
		for b in rj.bones:
			if b[1] != "" and images.has(b[0]) and images.has(b[1]):
				rest[b[0]] = h.bone_coverage(r, b, rj.scale, images)
		var gaps := []
		for n in d.anims:
			for f in d.anims[n].frames:
				r.pose(n, f.t)
				for b in rj.bones:
					if not rest.has(b[0]):
						continue
					var cov: Array = h.bone_coverage(r, b, rj.scale, images)
					var lost := 0
					for i in 16:
						if rest[b[0]][i] and not cov[i]:
							lost += 1
					if lost > 0:
						gaps.append("%s@%s %s 露出 %d 點" % [n, f.t, b[2] + "/" + b[0], lost])
		check(gaps.is_empty(), "%s 關節露縫：%s" % [c, ", ".join(gaps)])
		r.free()
	h.free()


# ---- Task 5：共用 animator；祖母、老夫婦、Chimalmat ----

const NpcAnimatorPath := "res://world/npc_animator.gd"
const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const Index := preload("res://world/rooms/index.gd")
const TEST_SAVE := "user://test_npc_rig_slot.json"


func npc_animator():
	return load(NpcAnimatorPath) if ResourceLoader.exists(NpcAnimatorPath) else null


## 掛在場景樹裡的空節點上；沒有 animator 腳本時 null
func attached(c: String):
	var scr = npc_animator()
	if scr == null:
		check(false, "world/npc_animator.gd 存在")
		return null
	var n := Node2D.new()
	add_child(n)
	return scr.attach(n, c)


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


## 有 GameState 的 Boss 戰（同 test_macaw_rig.macaw_fight）
func boss_fight() -> Array:
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


func test_npc_animator_plays_then() -> void:
	var a = attached("xmucane")
	if a == null:
		return
	check(a.anim == "idle", "預設播 idle（%s）" % a.anim)
	a.play("give", "idle")
	check(a.anim == "give", "play(give) 後是 give")
	a._process(2.0)
	check(a.anim == "idle", "give 播完接 idle（%s）" % a.anim)
	a.get_parent().free()


func test_npc_give_not_restarted() -> void:
	var a = attached("xmucane")
	if a == null:
		return
	a.play("give", "idle")
	a._process(0.2)
	a.play("give", "idle")
	check(a.t >= 0.2, "播放中再 play 同一個動作不重來（t=%.2f）" % a.t)
	a.get_parent().free()


func test_npc_facing_flips_rig() -> void:
	var a = attached("healer_man")
	if a == null:
		return
	a.facing = -1
	a._process(0.0)
	check(a.rig.scale.x == -a.rig.faces, "面向 −1：rig.scale.x＝−faces（%s）" % a.rig.scale.x)
	a.get_parent().free()


func test_grandma_rig_in_room_and_gives() -> void:
	var s: Array = await room_setup("home")
	var flow = s[0]
	var room = flow.current
	var npc: Node2D = room.get_node_or_null("Npc")
	check(npc != null, "home 有祖母節點")
	if npc == null:
		flow.free()
		return
	var a = npc.get_node_or_null("NpcAnimator")
	check(a != null and npc.get_node_or_null("Portrait") == null, "祖母是骨架、不是立繪")
	if a != null:
		room.player.global_position = npc.global_position
		room._on_interact()
		check(a.anim == "give", "互動後播 give（%s）" % a.anim)
	flow.free()


func test_npc_single_rig() -> void:
	var s: Array = await room_setup("home")
	var flow = s[0]
	flow.start("home")
	await wait_until(func(): return not flow.is_busy(), 30)
	await frames(2)
	var npc: Node2D = flow.current.get_node_or_null("Npc")
	var rigs := 0
	if npc != null:
		for ch in npc.get_children():
			if ch.name.begins_with("Rig"):
				rigs += 1
	check(rigs == 1, "重新進房後祖母底下剛好一副骨架（%d）" % rigs)
	flow.free()


func test_couple_walks_only_when_moving() -> void:
	var s: Array = await boss_fight()
	var f = s[0]
	var anims := []
	for n in f.couple:
		anims.append(n.get_node_or_null("NpcAnimator"))
	var missing := anims.any(func(a): return a == null)
	check(f.couple.size() == 2 and not missing, "老夫婦是兩副骨架")
	if f.couple.size() != 2 or missing:
		f.free()
		return
	f.couple_following = true
	f.couple_x = 100.0
	f._update_couple()
	f.couple_x = 110.0
	f._update_couple()
	check(anims.all(func(a): return a.anim == "walk" and a.facing == 1), "跟隨中往右移動：walk、面向右")
	f._update_couple()
	check(anims.all(func(a): return a.anim == "idle"), "跟隨中但沒移動：idle")
	f.couple_following = false
	f.palace.couple_static = true
	f._update_couple()
	check(anims.all(func(a): return a.anim == "idle"), "宮殿站著：idle")
	f.free()


func test_chimalmat_rig_in_palace() -> void:
	var s: Array = await boss_fight()
	var f = s[0]
	var ch: Node = f.find_child("Chimalmat", true, false)
	var a = ch.get_node_or_null("NpcAnimator") if ch != null else null
	check(a != null and a.anim == "idle", "宮殿的 Chimalmat 是骨架、播 idle")
	f.free()


func test_no_portrait_left() -> void:
	check(not ResourceLoader.exists("res://world/portrait.gd"), "world/portrait.gd 已移除")


# ---- Task 6：老鼠的事件與技能 ----

const EventRunner := preload("res://events/event_runner.gd")
const Loadout := preload("res://state/loadout.gd")
const Rat := preload("res://core/player/rat.gd")


## 地面房間＋事件（同 test_events.setup）；回傳 [flow, runner, gs]
func event_setup(room: String, flags := []) -> Array:
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


func event_teardown(s: Array) -> void:
	s[1].queue_free()
	s[0].queue_free()
	await frames(2)
	s[2].free()


func pass_card(s: Array) -> void:
	await wait_until(func(): return s[1].card.visible, 30)
	s[1].card.confirm()
	await frames(2)


func night_rat(s: Array):
	for c in s[0].current.get_children():
		if c.get("kind") == "rat" and not c.is_queued_for_deletion():
			return c
	return null


func test_night_rat_runs_and_idles() -> void:
	var s: Array = await event_setup("field", ["tools_obtained", "field_cleared", "night_seen"])  # 動物復原的過場另有測試（test_c3a）
	await frames(3)
	var rat = night_rat(s)
	var a = rat.get_node_or_null("NpcAnimator") if rat != null else null
	check(a != null, "田裡的老鼠是骨架")
	if a == null:
		await event_teardown(s)
		return
	var p = s[0].current.player
	p.position = Vector2(rat.position.x + 600, 900)
	await frames(3)
	check(a.anim == "idle", "角色在 300 px 外：idle（%s）" % a.anim)
	p.position = Vector2(rat.position.x + 200, 900)
	p.intent.move_x = -1.0
	await frames(3)
	check(a.anim == "run" and a.facing == -1, "角色從右邊靠近：往左逃、run（%s, %d）" % [a.anim, a.facing])
	p.scripted = true  # 同 test_events：等之前重新設定腳本輸入
	p.intent.move_x = -1.0
	var caught: bool = await wait_until(func(): return s[1].cutscene_running(), 400)  # 交換的過場（MV-SLICE-001c3a）
	await frames(2)
	check(caught and a.anim == "idle", "網子罩住後 idle（%s）" % a.anim)
	await event_teardown(s)


## 夜晚只調場景圖層：老鼠骨架與它到房間為止的祖先顏色照舊
func test_night_rat_keeps_colour() -> void:
	var s: Array = await event_setup("field", ["tools_obtained", "field_cleared", "night_seen"])  # 動物復原的過場另有測試（test_c3a）
	await frames(3)
	var rat = night_rat(s)
	var white := true
	var n: Node = rat.get_node_or_null("Rig") if rat != null else null
	check(n != null, "老鼠底下有骨架")
	while n != null and n != s[0]:
		if n is CanvasItem and (n.modulate != Color.WHITE or n.self_modulate != Color.WHITE):
			white = false
		n = n.get_parent()
	check(white, "夜晚時老鼠骨架沒有被調暗")
	await event_teardown(s)


func test_rat_skill_uses_rig() -> void:
	check(not Rat.new().get_script().get_script_method_list().any(func(m): return m.name == "_draw"), "rat.gd 不再畫梯形（沒有 _draw）")
	var w := make_world()
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.give_skill("rat")
	var p = Loadout.make_player(gs, gs.tn)
	p.scripted = true
	w.add_child(p)
	await frames(3)
	var e = await make_enemy(w, Crawler, Vector2(600, 0))
	e.set_physics_process(false)
	p.intent.skill_1_pressed = true
	var got: bool = await wait_until(func(): return count_of(w, Rat) == 1, 30)
	var rat = find_of(w, Rat) if got else null
	var a = rat.get_node_or_null("NpcAnimator") if rat != null else null
	check(a != null and a.anim == "run" and a.facing == 1, "技能的老鼠是骨架、往右跑")
	await free_world(w)
	gs.free()


func test_rat_skill_rig_freed_on_bite() -> void:
	var w := make_world()
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	gs.give_skill("rat")
	var p = Loadout.make_player(gs, gs.tn)
	p.scripted = true
	w.add_child(p)
	await frames(3)
	var e = await make_enemy(w, Crawler, Vector2(400, 0))
	p.intent.skill_1_pressed = true
	var hit: bool = await wait_until(func(): return e.health.hp == e.tn.crawler_hp - gs.tn.rat_damage, 60)
	await frames(2)
	check(hit and e.state == Enemy.State.STAGGER, "咬一口：傷害與硬直照舊")
	check(count_of(w, Rat) == 0 and find_of(w, load(NpcAnimatorPath)) == null, "咬完老鼠與牠的骨架一起消失")
	await free_world(w)
	gs.free()


func find_of(w: Node, scr) -> Node:
	for n in w.find_children("*", "", true, false):
		if n.get_script() == scr:
			return n
	return null


## 原本的立繪沒有翻面：Chimalmat 照基準圖面向左（rig.scale.x＝1）
func test_chimalmat_faces_left_as_before() -> void:
	var s: Array = await boss_fight()
	var f = s[0]
	var ch: Node = f.find_child("Chimalmat", true, false)
	var a = ch.get_node_or_null("NpcAnimator") if ch != null else null
	await frames(1)
	check(a != null and a.facing == -1 and a.rig.scale.x == 1.0, "Chimalmat 面向左，同原本的立繪（scale.x %s）" % (a.rig.scale.x if a != null else "?"))
	f.free()


# ---- 最終審查修正 ----

## 被追的老鼠：事件規則下每約 11 個物理幀會停 1 幀（距離剛超過 300）；run 不能每次都從頭播
func test_chased_rat_keeps_running() -> void:
	var w := make_world()
	var Prop = load("res://world/prop.gd")
	var rat = Prop.new()
	rat.kind = "rat"
	w.add_child(rat)
	await frames(1)
	var a = rat.get_node_or_null("NpcAnimator")
	var max_t := 0.0
	for i in 60:
		if i % 11 != 10:
			rat.position.x -= 12.8
		await get_tree().physics_frame
		if a != null:
			max_t = maxf(max_t, a.t if a.anim == "run" else 0.0)
	check(a != null and a.anim == "run" and max_t > 0.34, "被追時一直是 run、播得超過一輪（%s, max t %.2f）" % [a.anim if a != null else "?", max_t])
	await free_world(w)


## 卡片「couple」後才開始跟隨：位置從宮殿入口跳到小路起點，不算走路、不翻面
func test_couple_start_following_faces_right() -> void:
	var s: Array = await boss_fight()
	var f = s[0]
	f.couple_following = false
	f._update_couple()
	f.couple_following = true
	f.couple_x = Palace.PATH_START.x - 160.0
	f._update_couple()
	var anims: Array = f.couple.map(func(n): return n.get_node_or_null("NpcAnimator"))
	check(anims.all(func(a): return a != null and a.anim == "idle" and a.facing == 1), "開始跟隨那一幀：idle、面向右")
	f.free()


## 兌換時遊戲暫停：祖母的 give 照樣播
func test_grandma_gives_while_paused() -> void:
	var s: Array = await room_setup("home")
	var flow = s[0]
	var room = flow.current
	var npc: Node2D = room.get_node_or_null("Npc")
	var a = npc.get_node_or_null("NpcAnimator") if npc != null else null
	if a == null:
		check(false, "祖母有骨架")
		flow.free()
		return
	room.player.global_position = npc.global_position
	room._on_interact()
	get_tree().paused = true
	await frames(4)
	var t: float = a.t
	get_tree().paused = false
	check(a.anim == "give" and t > 0.0, "暫停中 give 照樣播（%s, t %.3f）" % [a.anim, t])
	flow.free()
