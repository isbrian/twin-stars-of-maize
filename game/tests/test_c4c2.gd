extends "res://tests/base_test.gd"
# MV-SLICE-001c4c2：反光型的骨架與動作（8 根骨頭、轉身中途翻面、擋下一震、光點、Boss 光束特效）。

const BONES := ["body", "head", "arm", "mirror", "thigh_near", "shin_near", "thigh_far", "shin_far"]


func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ---- Task 1：分件、骨架與動作檔 ----

func test_reflector_rig_bones() -> void:
	var d := read_json("res://rig/reflector_rig.json")
	check(not d.is_empty(), "game/rig/reflector_rig.json 存在")
	if d.is_empty():
		return
	var names: Array = d.bones.map(func(b): return b[0])
	var sorted_names := names.duplicate()
	sorted_names.sort()
	var want := BONES.duplicate()
	want.sort()
	check(sorted_names == want, "正好 8 根骨頭（%s）" % [names])
	var mirror: Array = d.bones.filter(func(b): return b[0] == "mirror")
	check(not mirror.is_empty() and mirror[0][1] == "arm", "反光面的父骨頭是手臂")
	check(d.get("points", {}).has("glow") and d.points.glow.bone == "mirror", "光點 glow 掛在反光面")


func test_reflector_turn_anim() -> void:
	var d := read_json("res://rig/reflector_anims.json")
	var t: Dictionary = d.get("anims", {}).get("turn", {})
	check(not t.is_empty() and not t.get("loop", true), "有 turn 動作、不循環")
	if t.is_empty():
		return
	var last: float = t.frames[-1].t
	check(last >= 0.6 and last <= 0.8, "turn 最後一格在 0.6～0.8 秒（%.2f）" % last)


# ---- Task 2：動作接上遊戲 ----

const Reflector := preload("res://core/enemies/reflector.gd")
const BeamFx := preload("res://world/fx/beam_fx.gd")
const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const Index := preload("res://world/rooms/index.gd")
const TestB := preload("res://world/rooms/_test_b.gd")


func animator():
	return load("res://world/enemy_animator.gd")


## [世界, 反光型（面向右）, animator]
func rigged(target: Node2D = null) -> Array:
	var w := make_world()
	var e = await make_enemy(w, Reflector, Vector2.ZERO, target)
	e.facing = 1
	e.turn_left = 0.0
	e.state_time = 0.0
	var a = animator().attach(e, "reflector")
	return [w, e, a]


func dummy(w: Node2D, at: Vector2) -> Node2D:
	var d := Node2D.new()
	d.position = at
	w.add_child(d)
	return d


## 畫面朝右？（基準圖面向左，朝右時 scale.x < 0）
func shows_right(e) -> bool:
	return e.get_node("Rig").scale.x < 0.0


func test_reflector_anim_states() -> void:
	var s: Array = await rigged()
	var e = s[1]
	var a = s[2]
	for pair in [[Reflector.State.TELEGRAPH, "telegraph"], [Reflector.State.ATTACK, "attack"], [Reflector.State.RECOVER, "recover"], [Reflector.State.STAGGER, "stagger"]]:
		e.state = pair[0]
		e.state_time = 0.2
		check(a.choose(e)[0] == pair[1], "狀態 %d → %s（%s）" % [pair[0], pair[1], a.choose(e)[0]])
	e.state = Reflector.State.IDLE
	e.turn_left = 0.5
	var c: Array = a.choose(e)
	check(c[0] == "turn" and is_equal_approx(c[1], 0.3), "轉身中 → turn、時間 0.3（%s）" % [c])
	e.turn_left = 0.0
	check(a.choose(e)[0] == "idle", "待機 → idle")
	await free_world(s[0])


func test_turn_display_matches_final_facing() -> void:
	var w := make_world()
	var d := dummy(w, Vector2(-500, 0))
	var e = await make_enemy(w, Reflector, Vector2.ZERO, d)
	e.facing = 1
	e.turn_left = 0.0
	var a = animator().attach(e, "reflector")
	e.turn_left = 0.5
	a._apply()
	check(shows_right(e), "轉身前半（剩 0.5）：畫面仍朝右")
	e.turn_left = 0.3
	a._apply()
	check(not shows_right(e), "轉身後半（剩 0.3）：畫面朝玩家（左）")
	d.position = Vector2(500, 0)  # 轉到一半玩家繞回右邊
	a._apply()
	check(shows_right(e), "玩家繞回右邊：後半畫面朝右")
	var last: bool = shows_right(e)
	while e.turn_left > 0.0:
		await frames(1)
		if e.turn_left > 0.0:
			last = shows_right(e)
	await frames(1)
	check(e.facing == 1 and shows_right(e) == last and last, "轉完：邏輯朝向＝畫面朝向（facing %d）" % e.facing)
	await free_world(w)


func test_thud_shake_no_drift() -> void:
	var s: Array = await rigged()
	var e = s[1]
	var a = s[2]
	var r = e.get_node("Rig")
	e.spark_left = 0.0
	a._apply()
	var base: float = r.bone("mirror").rotation
	for i in 5:
		e.spark_left = 0.15
		a._apply()
		a._apply()
		var shaken: float = r.bone("mirror").rotation
		check(absf(absf(shaken - base) - deg_to_rad(8.0)) < 0.01, "第 %d 次一震：偏 8 度（%.2f 度）" % [i + 1, rad_to_deg(shaken - base)])
	e.spark_left = 0.0
	a._apply()
	check(absf(r.bone("mirror").rotation - base) < deg_to_rad(0.5), "一震結束：回到動作角度、不累積")
	await free_world(s[0])


func test_glow_follows_mirror() -> void:
	var s: Array = await rigged()
	var e = s[1]
	var a = s[2]
	var r = e.get_node("Rig")
	a._apply()
	var idle_y: float = e.glow_at.y
	e.state = Reflector.State.TELEGRAPH
	e.state_time = 0.9
	a._apply()
	var want: Vector2 = r.transform * r.point("glow")
	check(e.glow_at.distance_to(want) <= 1.0, "前搖：光點＝反光面上的 glow（%s vs %s）" % [e.glow_at, want])
	check(e.glow_at.y < idle_y - 5.0, "前搖時光點比待機高（%.1f vs %.1f）" % [e.glow_at.y, idle_y])
	await free_world(s[0])


func test_beam_fx_on_reflector() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(600, 0))
	var e = await make_enemy(w, Reflector, Vector2.ZERO, p)
	e.facing = 1
	e.turn_left = 0.0
	animator().attach(e, "reflector")
	var fx = BeamFx.attach(e)
	check(fx.core_rect() == Rect2() and fx.aim_line().is_empty(), "待機：沒有光束、沒有虛線")
	await wait_until(func(): return e.state == Reflector.State.TELEGRAPH, 60)
	var ln: PackedVector2Array = fx.aim_line()
	check(ln.size() == 2 and is_equal_approx(minf(ln[0].x, ln[1].x), e.beam_rect.position.x) and is_equal_approx(maxf(ln[0].x, ln[1].x), e.beam_rect.end.x), "前搖：虛線範圍＝光束（%s vs %s）" % [ln, e.beam_rect])
	await wait_until(func(): return e.state == Reflector.State.ATTACK, 90)
	check(fx.core_rect() == e.beam_rect, "光束：特效範圍＝判定（%s vs %s）" % [fx.core_rect(), e.beam_rect])
	await free_world(w)


func test_beam_fx_freed_with_reflector() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(600, 0))
	var e = await make_enemy(w, Reflector, Vector2.ZERO, p)
	e.facing = 1
	e.turn_left = 0.0
	var fx = BeamFx.attach(e)
	var ref: WeakRef = weakref(fx)
	await wait_until(func(): return e.state == Reflector.State.ATTACK, 150)
	e.kill()
	await frames(2)
	check(ref.get_ref() == null, "光束中被打倒：特效跟著釋放")
	await free_world(w)


func visible_bounds(r: Node2D) -> Rect2:
	var box := Rect2()
	var first := true
	for s in r.find_children("*", "Sprite2D", true, false):
		if not s.is_visible_in_tree():
			continue
		var img: Image = s.texture.get_image()
		var xf: Transform2D = s.global_transform
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y).a <= 0.5:
					continue
				var pt: Vector2 = xf * (Vector2(x + 0.5, y + 0.5) + s.offset)
				if first:
					box = Rect2(pt, Vector2.ZERO)
					first = false
				else:
					box = box.expand(pt)
	return box


func test_reflector_size_vs_rig() -> void:
	var s: Array = await rigged()
	var e = s[1]
	var b := visible_bounds(e.get_node("Rig"))
	check(absf(b.size.x - e.size.x) <= e.size.x * 0.2 and absf(b.size.y - e.size.y) <= e.size.y * 0.2, "骨架靜止範圍 %s 和判定 %s 差 ≤ 20%%" % [b.size, e.size])
	await free_world(s[0])


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func test_room_reflector_has_rig() -> void:
	var gs = make_gs()
	var r = RoomScr.new()
	add_child(r)
	r.build(Index.ROOMS["forest_3"].data(), gs, gs.tn)
	await frames(3)
	var refl: Array = r.enemies.filter(func(e): return e is Reflector)
	check(refl.size() == 1, "森林 3 有一隻反光型")
	if refl.size() == 1:
		var e = refl[0]
		check(e.get_node_or_null("Rig") != null and e.get_node_or_null("EnemyAnimator") != null and e.get_node_or_null("BeamFx") != null and e.portrait_drawn, "森林房間的反光型：骨架、animator、光束特效")
	r.queue_free()
	await frames(1)
	var d: Dictionary = TestB.data()
	d.gates = []
	d.enemies = [{"kind": "reflector", "pos": Vector2(1400, 900)}]
	r = RoomScr.new()
	add_child(r)
	r.build(d, gs, gs.tn)
	await frames(3)
	check(not r.enemies[0].portrait_drawn, "沒有場景的測試房間：仍畫佔位")
	r.queue_free()
	await frames(1)
	gs.free()


# ---- 最終審查修正 ----

## Critical：擋下一震要畫面上的反光面分件真的轉（不只是骨頭），而且不累積；光點跟著分件走
func test_thud_moves_mirror_sprite() -> void:
	var s: Array = await rigged()
	var e = s[1]
	var a = s[2]
	var r = e.get_node("Rig")
	e.spark_left = 0.0
	a._apply()
	var base: float = r.sprite("mirror").global_rotation
	var glow0: Vector2 = e.glow_at
	for i in 3:
		e.spark_left = 0.15
		a._apply()
		var rot: float = r.sprite("mirror").global_rotation
		check(absf(absf(angle_difference(base, rot)) - deg_to_rad(8.0)) < 0.02, "第 %d 次：反光面分件偏 8 度（%.2f 度）" % [i + 1, rad_to_deg(angle_difference(base, rot))])
	check(e.glow_at.distance_to(glow0) > 1.0, "一震時光點跟著移動")
	e.spark_left = 0.0
	a._apply()
	check(absf(angle_difference(base, r.sprite("mirror").global_rotation)) < deg_to_rad(0.5), "一震結束：分件回到原角度")
	await free_world(s[0])


## Important：反光型的光束特效畫在本體（骨架）後面，光束從反光面前方出來、不蓋住身體
func test_beam_fx_drawn_behind_body() -> void:
	var s: Array = await rigged()
	var e = s[1]
	var fx = BeamFx.attach(e)
	var r = e.get_node("Rig")
	check(fx.show_behind_parent and fx.get_index() < r.get_index(), "光束特效在骨架後面（behind %s、%d < %d）" % [fx.show_behind_parent, fx.get_index(), r.get_index()])
	await free_world(s[0])
