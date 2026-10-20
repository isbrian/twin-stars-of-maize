extends "res://tests/base_test.gd"
# MV-TUNE-004：支路 A 的下劈水晶好連一點（縮間距、中途安全地面）；地上荊棘看得清楚（Brian 2026-10-16 試玩）。

const Index := preload("res://world/rooms/index.gd")
const RoomCheck := preload("res://world/room_check.gd")
const SceneryView := preload("res://world/scenery_view.gd")


func test_branch_a_has_rest_stop() -> void:
	var d: Dictionary = Index.ROOMS["forest_a"].data()
	var hz: Array = d.hazards.duplicate()
	hz.sort_custom(func(a, b): return a.position.x < b.position.x)
	check(hz.size() >= 2, "荊棘分成至少兩段（%d）" % hz.size())
	var gaps := []
	for i in hz.size() - 1:
		gaps.append(hz[i + 1].position.x - hz[i].end.x)
	check(gaps.all(func(g): return g >= 250.0), "兩段荊棘之間有 ≥ 250 的安全地面（%s）" % [gaps])
	for h in hz:
		var over: Array = d.crystals.filter(func(c): return c.x > h.position.x and c.x < h.end.x)
		check(over.size() <= 3, "每段荊棘上方最多 3 顆水晶（%s：%d）" % [h, over.size()])
	var xs: Array = d.crystals.map(func(c): return c.x)
	xs.sort()
	for i in xs.size() - 1:
		var gap: float = xs[i + 1] - xs[i]
		if gap < 500.0:  # 同一段裡相鄰的水晶
			check(gap <= 400.0, "相鄰水晶間距 ≤ 400（%d）" % gap)
	check(not RoomCheck.walk_errors(d, d.doors[0].spawn, d.fragment.pos).is_empty(), "仍然要靠下劈才拿得到碎片")


func test_hazard_art_stands_out() -> void:
	var d: Dictionary = Index.ROOMS["forest_1"].data()
	var s = SceneryView.new()
	add_child(s)
	s.build(d.theme, d.get("variant", 0), d.size)
	s.place_terrain(d)
	var sprites: Array = s.terrain.get_children().filter(func(n): return n is Sprite2D and n.region_enabled)
	check(not sprites.is_empty(), "荊棘有外觀")
	check(sprites.all(func(sp): return sp.modulate.get_luminance() > 1.0 or String(sp.texture.resource_path).ends_with("prop_thorns_ground.png")), "荊棘調亮或換成地上荊棘的圖")
	s.queue_free()
	await frames(1)


## Brian 試玩 2026-10-16：支路 B 掉進荊棘後一直掉、一直扣血。站在單向平台（原木）上之後掉下去，放回原木後要站得住
func test_thorn_return_onto_one_way_platform_holds() -> void:
	var GameStateScr = load("res://state/game_state.gd")
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var r = load("res://world/room.gd").new()
	add_child(r)
	r.build(Index.ROOMS["forest_b"].data(), gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	r.player.position = Vector2(1350, 600)  # 原木 Rect2(1250, 600, 200, 30) 上
	r.player.velocity = Vector2.ZERO
	await frames(30)
	check(r.player.is_on_floor() and r.safe_ground.distance_to(Vector2(1350, 600)) < 4.0, "前提：站在原木上、記成安全點（%s）" % r.safe_ground)
	r.player.position = Vector2(1500, 880)  # 掉進荊棘
	await frames(60)
	var hp_after_first: int = r.player.health.hp
	await frames(60)
	check(r.player.is_on_floor() and absf(r.player.position.y - 600.0) < 4.0, "放回原木後站得住（%s）" % r.player.position)
	check(r.player.health.hp == hp_after_first, "放回後不再扣血（%d → %d）" % [hp_after_first, r.player.health.hp])
	r.queue_free()
	await frames(1)
	gs.free()


## 放回的安全點離原木邊緣至少 SAFE_EDGE（站在邊上被記下來，放回後也不會一放就站在邊上）
func test_thorn_return_inside_platform() -> void:
	var GameStateScr = load("res://state/game_state.gd")
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var d: Dictionary = Index.ROOMS["forest_b"].data()
	var log_rect: Rect2 = d.platforms[1]
	var r = load("res://world/room.gd").new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	r.player.position = Vector2(log_rect.end.x + 25.0, log_rect.position.y)  # 站在原木右邊緣：腳底點已經在原木外、身體還壓著一半
	r.player.velocity = Vector2.ZERO
	await frames(20)
	var edge: float = r.SAFE_EDGE if "SAFE_EDGE" in r else 0.0
	check(edge >= 60.0, "SAFE_EDGE ≥ 60（%d）" % edge)
	check(r.safe_ground.x >= log_rect.position.x + edge - 0.5 and r.safe_ground.x <= log_rect.end.x - edge + 0.5, "安全點在原木內側（%s，原木 %s）" % [r.safe_ground, log_rect])
	r.queue_free()
	await frames(1)
	gs.free()


## 支路 B：原木加寬、間距縮短（Brian 試玩 2026-10-16：失手就一直掉進荊棘）
func test_branch_b_forgiving() -> void:
	var d: Dictionary = Index.ROOMS["forest_b"].data()
	var logs: Array = d.platforms.duplicate()
	logs.sort_custom(func(a, b): return a.position.x < b.position.x)
	check(logs.all(func(p): return p.size.x >= 280.0), "每段原木寬 ≥ 280")
	for i in logs.size() - 1:
		var gap: float = logs[i + 1].position.x - logs[i].end.x
		check(gap <= 260.0, "原木間距 ≤ 260（%d）" % gap)
	check(RoomCheck.walk_errors(d, d.doors[0].spawn, d.fragment.pos).is_empty(), "只靠單跳走得到碎片")


## Brian 試玩 2026-10-16（第三輪）：掉進荊棘時還按著方向，放回原木後馬上照著方向走出去、又掉進荊棘，連續到死
func test_thorn_return_ignores_held_direction() -> void:
	var GameStateScr = load("res://state/game_state.gd")
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var d: Dictionary = Index.ROOMS["forest_b"].data()
	var log_rect: Rect2 = d.platforms[1]
	var r = load("res://world/room.gd").new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	r.player.position = Vector2(log_rect.get_center().x, log_rect.position.y)
	r.player.velocity = Vector2.ZERO
	await frames(20)
	r.player.scripted = false
	Input.action_press("move_right")
	r.player.position = Vector2(log_rect.end.x + 150.0, 880)  # 往右跳失手，掉進荊棘
	await frames(int(0.9 * 60))
	var on_log: bool = r.player.is_on_floor() and absf(r.player.position.y - log_rect.position.y) < 4.0
	Input.action_release("move_right")
	check(on_log, "還按著右：放回原木後不會馬上走出去（%s）" % r.player.position)
	check(r.player.health.hp == r.player.health.max_hp - 1, "只扣 1 格（%d／%d）" % [r.player.health.hp, r.player.health.max_hp])
	await frames(2)
	var x0: float = r.player.position.x
	Input.action_press("move_left")
	await frames(10)
	Input.action_release("move_left")
	check(r.player.position.x < x0 - 20.0, "放開後再按方向就能走（%.0f → %.0f）" % [x0, r.player.position.x])
	r.queue_free()
	await frames(1)
	gs.free()


## Brian 試玩 2026-10-16（第四輪）：真實操作——按著右走過原木、跳下去掉進荊棘；放回後要站在原木上，不再垂直掉下去
func test_natural_fall_returns_onto_log() -> void:
	var GameStateScr = load("res://state/game_state.gd")
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var d: Dictionary = Index.ROOMS["forest_b"].data()
	var r = load("res://world/room.gd").new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	r.player.position = Vector2(1300, 600)
	await frames(20)
	r.player.scripted = false
	Input.action_press("move_right")
	await frames(14)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var hit: bool = await wait_until(func(): return r._respawning, 150)
	await wait_until(func(): return not r._respawning, 60)
	await frames(30)
	var p = r.player
	var on_log: bool = p.is_on_floor() and d.platforms.any(func(pl): return p.position.x >= pl.position.x and p.position.x <= pl.end.x and absf(p.position.y - pl.position.y) < 4.0)
	Input.action_release("move_right")
	check(hit, "前提：掉進荊棘")
	check(on_log, "放回後站在原木上（%s，安全點 %s）" % [p.position, r.safe_ground])
	await frames(60)
	check(p.health.hp == p.health.max_hp - 1, "只扣 1 格（%d／%d）" % [p.health.hp, p.health.max_hp])
	r.queue_free()
	await frames(1)
	gs.free()
