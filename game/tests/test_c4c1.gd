extends "res://tests/base_test.gd"
# MV-SLICE-001c4c1：反光型（遠程貼地光束＋反光面正面擋；吹箭打斷蓄力、繞背）。

const Reflector := preload("res://core/enemies/reflector.gd")


## 測試世界＋反光型（面向右，facing = 1）；target 省略時給遠處的假人
func make_reflector(w: Node2D, target: Node2D = null) -> Node:
	var e = await make_enemy(w, Reflector, Vector2.ZERO, target)
	e.facing = 1
	e.turn_left = 0.0  # 生成時預設面向左，可能已經開始轉身
	e.state_time = 0.0
	return e


## 從 at 打一下（來源節點放在 at）
func hit_from(w: Node2D, e, at: Vector2, amount: int, kind: StringName) -> void:
	var src := Node2D.new()
	src.position = at
	w.add_child(src)
	e.hurtbox.receive(amount, src, kind)
	src.queue_free()


func counter(sig: Signal) -> Array:
	var n := [0]
	sig.connect(func(_a = null): n[0] += 1)
	return n


func test_reflector_numbers() -> void:
	var w := make_world()
	var e = await make_reflector(w)
	check(e.health.hp == 24 and not e.parryable and e.size == Vector2(250, 150), "血 24、不可招架、250×150（c4c2 從骨架量）（%d、%s、%s）" % [e.health.hp, e.parryable, e.size])
	await free_world(w)


func test_front_blocks_back_hurts() -> void:
	var w := make_world()
	var e = await make_reflector(w)
	var thuds := counter(e.thudded)
	hit_from(w, e, Vector2(300, -60), 5, &"melee")
	check(e.health.hp == 24 and thuds[0] == 1, "正面：不扣血、悶響（%d、%d）" % [e.health.hp, thuds[0]])
	hit_from(w, e, Vector2(-300, -60), 5, &"melee")
	check(e.health.hp == 19, "背後：扣血（%d）" % e.health.hp)
	await free_world(w)


func test_from_above_hurts_without_turn_jitter() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(10, -150))
	var e = await make_reflector(w, p)
	var flips := [0]
	var last: int = e.facing
	for i in 60:
		p.position = Vector2(10, -150)
		p.velocity = Vector2.ZERO
		await frames(1)
		if e.facing != last:
			flips[0] += 1
			last = e.facing
	check(flips[0] == 0, "玩家在正上方：不來回轉身（%d 次）" % flips[0])
	hit_from(w, e, Vector2(10, -150), 5, &"melee")
	check(e.health.hp == 19, "正上方算背後：扣血（%d）" % e.health.hp)
	await free_world(w)


func test_front_dart_interrupts_in_telegraph() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(500, 0))
	var e = await make_reflector(w, p)
	var got: bool = await wait_until(func(): return e.state == Reflector.State.TELEGRAPH, 60)
	var ints := counter(e.interrupted)
	hit_from(w, e, Vector2(400, -100), 3, &"dart")
	check(got and e.state == Reflector.State.STAGGER and e.health.hp == 24 and ints[0] == 1, "前搖中正面吹箭：打斷、不扣血（state %d、hp %d）" % [e.state, e.health.hp])
	await free_world(w)


func test_front_dart_during_cooldown_thuds() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(500, 0))
	var e = await make_reflector(w, p)
	await wait_until(func(): return e.state == Reflector.State.TELEGRAPH, 60)
	hit_from(w, e, Vector2(400, -100), 3, &"dart")
	var again: bool = await wait_until(func(): return e.state == Reflector.State.TELEGRAPH, 90)
	var thuds := counter(e.thudded)
	hit_from(w, e, Vector2(400, -100), 3, &"dart")
	check(again and e.interrupt_cooldown_left > 0.0, "前提：冷卻中又在前搖")
	check(e.state == Reflector.State.TELEGRAPH and e.health.hp == 24 and thuds[0] == 1, "冷卻中正面吹箭：不打斷、不扣血、悶響（state %d、hp %d、悶響 %d）" % [e.state, e.health.hp, thuds[0]])
	await free_world(w)


func test_recover_and_turn_take_front_hits() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(500, 0))
	var e = await make_reflector(w, p)
	var rec: bool = await wait_until(func(): return e.state == Reflector.State.RECOVER, 150)
	hit_from(w, e, Vector2(300, -60), 2, &"melee")
	check(rec and e.health.hp == 22, "收招中正面扣血（%d）" % e.health.hp)
	p.position = Vector2(-500, 0)
	var turning: bool = await wait_until(func(): return e.turn_left > 0.0, 90)
	hit_from(w, e, Vector2(300, -60), 2, &"melee")
	check(turning and e.health.hp == 20, "轉身中正面扣血（%d）" % e.health.hp)
	await frames(int(0.9 * 60))
	check(e.facing == -1, "0.8 秒後轉向玩家（facing %d）" % e.facing)
	await free_world(w)


func test_telegraph_conditions() -> void:
	for case in [[Vector2(900, 0), true], [Vector2(1000, 0), false], [Vector2(-300, 0), false], [Vector2(300, -300), false]]:
		var w := make_world()
		var dummy := Node2D.new()
		dummy.position = case[0]
		w.add_child(dummy)
		var e = await make_reflector(w, dummy)
		var started := false
		for i in 90:
			await frames(1)
			e.facing = 1  # 只測「在不在正面」，不讓背後的情況轉身
			e.turn_left = 0.0
			if e.state == Reflector.State.TELEGRAPH:
				started = true
				break
		check(started == case[1], "玩家在 %s：%s" % [case[0], "前搖" if case[1] else "不前搖"])
		await free_world(w)


func test_beam_hits_ground_not_jumper() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(600, 0))
	var e = await make_reflector(w, p)
	var hp0: int = p.health.hp
	await wait_until(func(): return e.state == Reflector.State.RECOVER, 150)
	check(p.health.hp == hp0 - 1, "站在地上被光束打到（%d → %d）" % [hp0, p.health.hp])
	await free_world(w)
	w = make_world()
	p = await make_player(w, Vector2(600, 0))
	e = await make_reflector(w, p)
	hp0 = p.health.hp
	await wait_until(func(): return e.state == Reflector.State.TELEGRAPH, 60)
	for i in 150:
		if e.state == Reflector.State.ATTACK or (e.state == Reflector.State.TELEGRAPH and e.state_time > 0.8):  # 看到蓄力先跳
			p.position = Vector2(600, -150)
			p.velocity = Vector2.ZERO
		if e.state == Reflector.State.RECOVER:
			break
		await frames(1)
	check(p.health.hp == hp0, "跳在空中（離地 150）不被打到（%d → %d）" % [hp0, p.health.hp])
	await free_world(w)


func test_beam_length_and_time() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(600, 0))
	var e = await make_reflector(w, p)
	await wait_until(func(): return e.state == Reflector.State.ATTACK, 120)
	check(is_equal_approx(e.beam_rect.size.x, e.size.x / 2.0 + 960.0), "前方沒有牆：從身體中心起、反光面前緣往前 960（%.0f）" % e.beam_rect.size.x)
	var t := 0
	while e.state == Reflector.State.ATTACK and t < 120:
		await frames(1)
		t += 1
	check(t >= 26 and t <= 34, "光束約 0.5 秒（%d 幀）" % t)
	check(e.state == Reflector.State.RECOVER and e.hitbox.rect.size.is_equal_approx(e.size * 1.1), "收招：判定恢復成身體大小（%s）" % e.hitbox.rect.size)
	await free_world(w)


func test_beam_stops_at_wall() -> void:
	var w := make_world()
	var wall := StaticBody2D.new()
	wall.collision_layer = L.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 400)
	cs.shape = r
	cs.position = Vector2(420, -200)  # 左緣在 x 400
	wall.add_child(cs)
	w.add_child(wall)
	var p = await make_player(w, Vector2(300, 0))
	var e = await make_reflector(w, p)
	await wait_until(func(): return e.state == Reflector.State.ATTACK, 120)
	check(absf(e.beam_rect.size.x - 400.0) <= 10.0, "光束停在牆前（%.0f，應約 400：從身體中心到牆）" % e.beam_rect.size.x)
	await free_world(w)


func test_beam_locked_forward() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(500, 0))
	var e = await make_reflector(w, p)
	await wait_until(func(): return e.state == Reflector.State.TELEGRAPH, 60)
	p.position = Vector2(-300, 0)
	var hp0: int = p.health.hp
	await wait_until(func(): return e.state == Reflector.State.ATTACK, 90)
	var facing_at_fire: int = e.facing
	var beam_x: float = e.beam_rect.position.x  # 光束從身體中心（0）往右延伸
	await wait_until(func(): return e.state == Reflector.State.RECOVER, 60)
	check(facing_at_fire == 1 and beam_x >= 0.0 and p.health.hp == hp0, "前搖後玩家繞到背後：光束仍向右、打不到（facing %d、hp %d → %d）" % [facing_at_fire, hp0, p.health.hp])
	await free_world(w)


func test_reflector_dies_at_24() -> void:
	var w := make_world()
	var e = await make_reflector(w)
	var deaths := counter(e.died)
	for i in 4:
		hit_from(w, e, Vector2(-300, -60), 6, &"melee")
	check(deaths[0] == 1, "背後累計 24：擊倒")
	await free_world(w)


# ---- Task 2：放進房間 ----

const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const TestB := preload("res://world/rooms/_test_b.gd")
const Index := preload("res://world/rooms/index.gd")
const RoomCheck := preload("res://world/room_check.gd")
const Kit := preload("res://world/rooms/kit.gd")
const MAIN := ["forest_1", "forest_2", "forest_3", "forest_4", "forest_5", "forest_6"]


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func build_room(d: Dictionary, gs) -> Node:
	var r = RoomScr.new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	return r


func kinds(d: Dictionary) -> Array:
	return d.enemies.map(func(e): return e.kind)


func test_rooms_spawn_reflector() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.gates = []
	d.theme = "forest"
	d.enemies = [{"kind": "reflector", "pos": Vector2(1400, 900)}]
	var r = await build_room(d, gs)
	var e = r.enemies[0] if not r.enemies.is_empty() else null
	check(e is Reflector and e.portrait_drawn, "生成反光型、有骨架（MV-SLICE-001c4c2 起森林房間掛骨架）")
	if e is Reflector:
		check(e.thudded.get_connections().any(func(c): return c.callable.get_object() == r.feedback), "悶響接到房間的回饋音")
	r.queue_free()
	await frames(1)
	gs.free()


func test_reflector_placement() -> void:
	var total := 0
	for id in Index.ROOMS:
		if not String(id).begins_with("forest"):
			continue
		var d: Dictionary = Index.ROOMS[id].data()
		var n: int = kinds(d).count("reflector")
		var want := 1 if id in ["forest_3", "forest_5", "forest_6"] else 0
		check(n == want, "%s 有 %d 隻反光型（應 %d）" % [id, n, want])
		if id in MAIN:
			total += d.enemies.size()
	check(total == 22, "主路合計 22 隻（%d）" % total)
	var waves: Array = Index.ROOMS["forest_c"].data().arena.waves
	check(waves[2].size() == 4 and waves[2].map(func(e): return e.kind).count("reflector") == 1, "關門戰第 3 波 4 隻、其中 1 隻反光型")


func test_reflector_on_terrain_checked() -> void:
	var d := Kit.room("_t", 1, {"enemies": [{"kind": "reflector", "pos": Vector2(900, 500)}]})
	check(Array(RoomCheck.errors(d)).any(func(e): return "反光型" in e or "reflector" in e or "不在地形上" in e), "懸空的反光型要報錯：%s" % RoomCheck.errors(d))


func test_arena_wave3_with_reflector_clears() -> void:
	var gs = make_gs()
	var d: Dictionary = Index.ROOMS["forest_c"].data()
	var r = await build_room(d, gs)
	r.player.position = Vector2(d.arena.rect.get_center().x, Kit.GROUND_Y)
	await frames(3)
	var saw_reflector := false
	for w in 3:
		await wait_until(func(): return r.enemies.any(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion()), 120)
		for e in r.enemies.duplicate():
			if is_instance_valid(e):
				if e is Reflector:
					saw_reflector = true
				e.kill()
		await frames(2)
		r.player.position = Vector2(d.arena.rect.get_center().x, Kit.GROUND_Y)
		await frames(int(1.2 * 60))
	check(saw_reflector, "第 3 波出現反光型")
	check(r.gates.is_empty() and r.fragment_pickup != null, "清完：開門、碎片出現")
	r.queue_free()
	await frames(1)
	gs.free()


# ---- 最終審查修正 ----

## I1：貼在身體裡（地面、水平距離 < 30）不能安全輸出——正面照樣擋，而且它會出招、光束打得到
func test_hugging_body_not_safe() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(10, 0))
	var e = await make_reflector(w, p)
	var thuds := counter(e.thudded)
	hit_from(w, e, Vector2(10, 0), 5, &"melee")
	check(e.health.hp == 24 and thuds[0] == 1, "貼身在正面那半邊：擋下（hp %d）" % e.health.hp)
	var hp0: int = p.health.hp
	for i in 150:
		p.position = Vector2(10, 0)
		await frames(1)
		if e.state == Reflector.State.RECOVER:
			break
	check(p.health.hp == hp0 - 1, "貼身也會被光束打到（%d → %d）" % [hp0, p.health.hp])
	await free_world(w)


## I3：正上方（在身體上方、水平距離 < 半個身寬 80）全額扣血（規格「風險與退路」）
func test_from_above_within_half_width_hurts() -> void:
	var w := make_world()
	var e = await make_reflector(w)
	hit_from(w, e, Vector2(70, -170), 5, &"melee")
	check(e.health.hp == 19, "正上方偏前 70：扣血（%d）" % e.health.hp)
	await free_world(w)


## Minor 1 → 修：轉身結束時面向玩家（不是單純翻面）
func test_turn_ends_facing_player() -> void:
	var w := make_world()
	var dummy := Node2D.new()
	dummy.position = Vector2(-500, 0)
	w.add_child(dummy)
	var e = await make_reflector(w, dummy)
	await wait_until(func(): return e.turn_left > 0.0, 30)
	dummy.position = Vector2(500, 0)  # 轉到一半玩家又繞回正面
	await frames(int(0.9 * 60))
	check(e.facing == 1, "轉完面向玩家（facing %d）" % e.facing)
	await free_world(w)


## I2：真實玩家從正面揮擊被擋下——不扣血、悶響，玩家沒有命中回饋（不發 hit_landed、不累積技能量）
func test_blocked_melee_gives_no_hit_feedback() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(170, 0))
	p.facing = -1
	var e = await make_reflector(w)
	var hits := counter(p.hit_landed)
	var thuds := counter(e.thudded)
	p.intent.attack_pressed = true
	await frames(1)
	p.intent.attack_pressed = false
	await frames(30)
	check(thuds[0] >= 1 and e.health.hp == 24, "正面揮擊：悶響、不扣血（悶響 %d、hp %d）" % [thuds[0], e.health.hp])
	check(hits[0] == 0, "玩家沒有命中回饋（hit_landed %d）" % hits[0])
	await free_world(w)
