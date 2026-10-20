extends "res://tests/base_test.gd"
# MV-SLICE-001b1：場景圖層（主題表、四層視差、地表對位）。

const GameStateScr := preload("res://state/game_state.gd")
const RoomFlow := preload("res://world/room_flow.gd")
const EventRunner := preload("res://events/event_runner.gd")
const Index := preload("res://world/rooms/index.gd")
const Scenery := preload("res://world/scenery.gd")
const TEST_SAVE := "user://test_scenery_slot.json"
const SCREEN_W := 1920.0


## 房間流程＋事件；回傳 [flow, runner, gs]
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
	return [flow, runner, gs]


func teardown(s: Array) -> void:
	s[1].queue_free()
	s[0].queue_free()
	await frames(2)
	s[2].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func ground_rooms() -> Array:
	var out: Array = []
	for id in Index.ROOMS:
		if Index.ROOMS[id].data().get("kind", "") == "":
			out.append(id)
	return out


## 圖片第一列「超過一半不透明」的列（地面上緣）
func first_solid_row(path: String) -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	for y in img.get_height():
		var n := 0
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
		if n * 4 > img.get_width() / 2:
			return y
	return -1


func test_every_room_has_theme_and_files() -> void:
	for id in ground_rooms():
		var d: Dictionary = Index.ROOMS[id].data()
		check(d.get("theme", "") != "", "%s 有主題" % id)
		var layers: Dictionary = Scenery.layers(d.get("theme", ""), d.get("variant", 0))
		for k in ["far", "mid", "ground", "fore"]:
			var p: String = layers.get(k, "")
			check(p == "" or ResourceLoader.exists(p), "%s 的 %s 圖層存在：%s" % [id, k, p])
		check(layers.get("ground", "") != "" and layers.get("mid", "") != "", "%s 至少有中景與地表" % id)


func test_ground_top_aligns_with_floor() -> void:
	for id in ["home", "field", "yard", "forest_1"]:
		var s: Array = await setup(id)
		var sc = s[0].current.scenery
		var tile: Sprite2D = sc.layers.ground.get_child(0)
		var row := first_solid_row(tile.texture.resource_path)
		var top := tile.global_position.y + row * tile.scale.y
		check(absf(top - 900.0) <= 1.0, "%s 的地表上緣在 900（是 %.1f）" % [id, top])
		await teardown(s)


## Review Focus 3：兩個畫面寬的房間，鏡頭在左右兩端時每一層都蓋滿畫面
func test_layers_cover_room_at_camera_limits() -> void:
	var s: Array = await setup("forest_1")
	var r = s[0].current
	var sc = r.scenery
	for cam in [0.0, r.data.size.x - SCREEN_W]:
		sc.update(cam)
		for name in sc.layers:
			var layer: Node2D = sc.layers[name]
			var lo := INF
			var hi := -INF
			for t in layer.get_children():
				if t is Sprite2D:
					var x0: float = t.global_position.x - cam
					lo = minf(lo, x0)
					hi = maxf(hi, x0 + t.texture.get_width() * t.scale.x)
			check(lo <= 0.0 and hi >= SCREEN_W, "鏡頭 %.0f：%s 層蓋住畫面（%.0f～%.0f）" % [cam, name, lo, hi])
	await teardown(s)


## 前景不擋戰鬥（規格「自測」、ART_SPEC 第 5 節）：前景圖中央寬、高各 2/3 的範圍全透明
func test_fore_center_is_clear() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(Scenery.BG % Scenery.THEMES.forest.fore))
	var w := img.get_width()
	var h := img.get_height()
	var opaque := 0
	for y in range(h / 6, h - h / 6, 2):
		for x in range(w / 6, w - w / 6, 2):
			if img.get_pixel(x, y).a > 0.0:
				opaque += 1
	check(opaque == 0, "前景中央全透明（不透明取樣點 %d）" % opaque)


## Review Focus 1：來回換房、休息很多次，每個房間只有一組場景圖層
func test_scenery_rebuilt_once_per_room() -> void:
	var s: Array = await setup("home")
	var flow = s[0]
	var old: Array = []
	for i in 5:
		old.append(flow.current)
		flow.goto("field", "to_home")
		await wait_until(func(): return flow.current_id == "field" and not flow.is_busy(), 60)
		old.append(flow.current)
		flow.goto("home", "to_field")
		await wait_until(func(): return flow.current_id == "home" and not flow.is_busy(), 60)
	for i in 2:
		flow.rest_here()
		await wait_until(func(): return not flow.is_busy(), 60)
	await frames(2)
	var n := 0
	for c in flow.current.get_children():
		if c == flow.current.scenery:
			n += 1
	check(n == 1 and flow.get_child_count() <= 2, "目前房間恰好一組場景（%d），流程底下只剩目前房間與淡出層（%d）" % [n, flow.get_child_count()])
	var alive := 0
	for r in old:
		if is_instance_valid(r):
			alive += 1
	check(alive == 0, "舊房間都已釋放（還剩 %d）" % alive)
	await teardown(s)


func test_night_tints_scenery() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared", "night_seen"])  # 入夜的過場另有測試（test_c3a）
	await frames(3)
	var sc = s[0].current.scenery
	check(sc.night and sc.modulate.is_equal_approx(Color(0.45, 0.5, 0.75)), "入夜：場景調成夜色")
	await teardown(s)


# ---- Task 4：地形與物件素材 ----

func pieces(r, kind: String) -> Array:
	var out: Array = []
	for p in r.scenery.piece_rects():
		if p.kind == kind:
			out.append(p.rect)
	return out


## Art 子節點底下所有貼圖的世界座標外框
func art_rect(art: Node2D) -> Rect2:
	var box := Rect2()
	var first := true
	for t in art.get_children():
		if t is Sprite2D:
			var rr := Rect2(t.global_position, Vector2(t.texture.get_size()) * t.scale.abs())
			box = rr if first else box.merge(rr)
			first = false
	return box


func test_platform_art_covers_collision() -> void:
	for id in ["forest_1", "forest_3"]:
		var s: Array = await setup(id)
		var r = s[0].current
		var arts := pieces(r, "platform")
		for p in r.data.platforms:
			var ok := false
			for a in arts:
				if a.position.x <= p.position.x + 1 and a.end.x >= p.end.x - 1 and absf(a.position.y - p.position.y) <= 4.0:
					ok = true
			check(ok, "%s 的平台 %s 被倒木蓋住" % [id, p])
		await teardown(s)


func test_thorns_art_covers_gate() -> void:
	var s: Array = await setup("yard")
	var g = s[0].current.gates[0]
	var art = g.get_node_or_null("Art")
	var rect: Rect2 = s[0].current.data.gates[0].rect
	check(art != null and art_rect(art).encloses(rect.grow(-1)), "荊棘素材蓋住閘門 %s（素材 %s）" % [rect, art_rect(art) if art != null else Rect2()])
	await teardown(s)
	s = await setup("yard", ["gear_obtained"])
	check(s[0].current.gates.is_empty(), "拿到球具後沒有荊棘")
	await teardown(s)


func test_every_door_has_waymark() -> void:
	for id in ground_rooms():
		var s: Array = await setup(id)
		var r = s[0].current
		var marks := pieces(r, "waymark")
		for door in r.data.doors:
			var ok := false
			for m in marks:
				var dx := absf(m.get_center().x - door.rect.get_center().x)
				if dx <= 200.0 and absf(m.end.y - 900.0) <= 2.0:
					ok = true
			check(ok, "%s 的門 %s 旁有路標" % [id, door.id])
		await teardown(s)


func test_props_use_textures() -> void:
	var s: Array = await setup("field", ["tools_obtained", "field_cleared"])
	var r = s[0].current
	var Prop = load("res://world/prop.gd")
	for kind in ["bush", "clod", "net", "gear", "rat"]:
		var p = Prop.new()
		p.kind = kind
		r.add_child(p)
		if kind == "rat":  # MV-SLICE-001b2b2：老鼠換成骨架
			check(p.texture == null and p.get_node_or_null("NpcAnimator") != null, "rat 是骨架、沒有貼圖")
		else:
			check(p.texture != null, "%s 有貼圖" % kind)
		p.queue_free()
	for item in ["axe", "stick", "gear"]:
		r.add_pickup("t_" + item, item, Vector2(500, 900))
	for pk in r.pickups:
		check(pk.texture != null, "拾取物 %s 有貼圖" % pk.item)
	await teardown(s)
	s = await setup("forest_3")
	check(s[0].current.stash != null and s[0].current.stash.texture != null, "藏點有貼圖")
	await teardown(s)
	s = await setup("home")
	check(s[0].current.rest.texture != null, "篝火有貼圖")
	await teardown(s)


# ---- Task 6：Boss 段落 ----

## 垂直切片模式的 Boss 段落（有 gs → 場景素材）
func boss_gs() -> Array:
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


func free_boss(s: Array) -> void:
	await free_fight(s[0])
	s[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_boss_regions_switch_with_camera() -> void:
	var s: Array = await boss_gs()
	var sc = s[0].scenery
	var want := {"boss_nance": Nance.REST.x, "boss_path": Palace.PATH_START.x + 500.0, "boss_palace": Palace.HOME.x}
	for name in want:
		sc.update_region(want[name])
		var shown: Array = []
		for r in sc.regions:
			if sc.regions[r].visible:
				shown.append(r)
		check(shown == [name], "鏡頭在 %.0f：只顯示 %s（實際 %s）" % [want[name], name, shown])
	await free_boss(s)


## 素材蓋住碰撞框：x 方向整段蓋住、上緣差 4 px 內（平台類）；直條類整個包住
func covers_top(arts: Array, r: Rect2) -> bool:
	for a in arts:
		if a.position.x <= r.position.x + 1 and a.end.x >= r.end.x - 1 and absf(a.position.y - r.position.y) <= 4.0:
			return true
	return false


func test_boss_pieces_cover_collision() -> void:
	var s: Array = await boss_gs()
	var f = s[0]
	var kinds := {}
	for p in f.scenery.piece_rects():
		if not kinds.has(p.kind):
			kinds[p.kind] = []
		kinds[p.kind].append(p.rect)
	check(kinds.get("branch", []).size() == 1, "nance 樹枝平台有素材（位置見 test_nance_branch_art_on_platform）")
	for r in Palace.PLATFORMS:
		check(covers_top(kinds.get("platform", []), r), "宮殿低台 %s 有素材" % r)
	var ledge := Rect2(Palace.EXIT_LEDGE.position, Vector2(Palace.EXIT_LEDGE.size.x, 900.0 - Palace.EXIT_LEDGE.position.y))
	check(covers_top(kinds.get("ledge", []), ledge) and kinds.ledge[0].end.y >= 900.0, "出口高台地面以上被素材蓋住")
	check(kinds.get("throne", []).size() == 1 and absf(kinds.throne[0].end.y - 900.0) <= 2.0, "寶座立在地板上")
	check(kinds.get("waymark", []).size() == 1 and kinds.waymark[0].get_center().x < Nance.REST.x, "Boss 段落左端有路標")
	f.nance.close_gate()
	f.palace.close_gate()
	for a in [f.nance, f.palace]:
		var g = a.gate_art
		check(g != null and g.visible and art_rect(g).encloses(a.GATE.grow(-1)), "%s 的閘門關上時素材蓋住 %s" % [a.name, a.GATE])
	var b = f.palace.barrier.get_node_or_null("Art")
	check(b != null and art_rect(b).encloses(Palace.BARRIER.grow(-1)), "障壁素材蓋住 %s" % Palace.BARRIER)
	f.nance.open_gate()
	check(not f.nance.gate_art.visible, "閘門打開時素材隱藏")
	f.palace.barrier.break_apart()
	check(not f.palace.barrier.visible, "障壁破了素材跟著隱藏")
	await free_boss(s)


func test_palace_floor_aligns() -> void:
	var s: Array = await boss_gs()
	var layer: Node2D = s[0].scenery.regions.boss_palace.get_child(0)
	var back: Sprite2D = layer.get_child(0)
	var img := back.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var dark := func(y: int) -> bool:  # 整列很暗（牆上的方塊帶輪廓也是，地板線是最低的一條）
		var sum := 0.0
		var n := 0
		for x in range(0, img.get_width(), 8):
			sum += img.get_pixel(x, y).get_luminance()
			n += 1
		return sum / n < 0.15
	var row := -1
	for y in range(img.get_height() - 1, 0, -1):  # 由下往上找到地板線，再往上走到線的上緣
		if dark.call(y):
			row = y
			while dark.call(row - 1):
				row -= 1
			break
	var top := back.global_position.y + row * back.scale.y
	check(row > 0 and absf(top - 900.0) <= 2.0, "宮殿後牆的地板線在 900（列 %d → %.1f）" % [row, top])
	await free_boss(s)


## Review Focus 4：每拔掉一個光源暗一階
func test_boss_darkness_follows_lights() -> void:
	var s: Array = await boss_gs()
	var f = s[0]
	check(f.scenery.modulate.is_equal_approx(Color.WHITE), "開場不暗")
	f.begin_at_rest("palace_camp")
	await frames(2)
	check(f.scenery.modulate.is_equal_approx(Color(0.75, 0.75, 0.75)), "宮殿篝火（拔掉 1 個）＝0.75，實際 %s" % f.scenery.modulate)
	f.start_at(3)
	await frames(2)
	check(f.scenery.modulate.is_equal_approx(Color(0.5, 0.5, 0.5)), "第 3 段＝0.5，實際 %s" % f.scenery.modulate)
	f.start_at(4)
	await frames(2)
	check(f.scenery.modulate.is_equal_approx(Color(0.3, 0.3, 0.3)), "覺醒後出口＝0.3，實際 %s" % f.scenery.modulate)
	await free_boss(s)


## 走近宮殿入口時，小路前景剛好鋪到入口線：不留空、也不蓋到宮殿裡
func test_path_fore_stops_at_palace_gate() -> void:
	var s: Array = await boss_gs()
	var sc = s[0].scenery
	var fore: Node2D = sc.regions.boss_path.get_child(3)
	for cam in [Palace.LEFT - SCREEN_W + 100.0, 13000.0, Palace.LEFT - 300.0]:
		sc.update(cam)
		var lo := INF
		var hi := -INF
		for t in fore.get_children():
			if t is Sprite2D and t.visible:
				var w: float = t.region_rect.size.x if t.region_enabled else t.texture.get_width()
				lo = minf(lo, t.global_position.x)
				hi = maxf(hi, t.global_position.x + w)
		check(lo <= cam and absf(hi - Palace.LEFT) <= 1.0, "鏡頭 %.0f：小路前景 %.0f～%.0f，右端在入口 %.0f" % [cam, lo, hi, Palace.LEFT])
	await free_boss(s)


# ---- Task 8：截圖模式 ----

func test_launch_args_shots() -> void:
	var a := LaunchArgs.parse(PackedStringArray(["--shots", "/tmp/x"]))
	check(a.mode == "shots" and a.get("shots_dir", "") == "/tmp/x", "--shots /tmp/x → 截圖模式（%s）" % a)
	check(LaunchArgs.parse(PackedStringArray(["--shots"])).mode == "title", "沒給資料夾 → 主選單")


# ---- 最終審查的修正 ----

## nance 樹場地：前景的樹冠邊不可以蓋到樹冠上的 Boss 與他的出招訊號（腳底 CANOPY.y 以上全透明）
func test_nance_fore_clears_canopy() -> void:
	var s: Array = await boss_gs()
	var fore: Node2D = s[0].scenery.regions.boss_nance.get_child(3)
	var hits := 0
	for sp in fore.get_children():
		var img: Image = sp.texture.get_image()
		var r0 := int(sp.region_rect.position.y) if sp.region_enabled else 0
		var top: float = sp.global_position.y + r0
		for y in range(int(top), int(Nance.CANOPY.y)):
			var row := r0 + y - int(top)
			for x in range(0, img.get_width(), 8):
				if img.get_pixel(x, row).a > 0.0:
					hits += 1
	check(hits == 0, "樹冠高度以上沒有前景像素（%d 個取樣點不透明）" % hits)
	await free_boss(s)


## 死亡回點等瞬移：下一幀的場景區段就跟上新的鏡頭（不晚一幀、不閃空白）
## 只等「一次完整的 process」：process_frame 在各節點 _process 之前發出，等兩次＝中間跑完一輪（frames() 等的是物理幀，一個慢的 process 幀可能跑好幾個物理幀）
func one_process_pass() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_boss_regions_follow_teleport() -> void:
	var s: Array = await boss_gs()
	var f = s[0]
	f.start_at(3)
	await one_process_pass()
	check(f.scenery.regions.boss_palace.visible and not f.scenery.regions.boss_nance.visible, "瞬移到宮殿後的第一輪就顯示宮殿")
	f._retry(2)
	await one_process_pass()
	check(f.scenery.regions.boss_path.visible and not f.scenery.regions.boss_palace.visible, "回宮殿篝火後的第一輪就顯示小路、不顯示宮殿")
	await free_boss(s)


## 畫面震動（camera.offset ±shake_strength，在鏡頭邊界之後才加）不露出空白：上緣與區段交界多鋪一點
func test_shake_does_not_reveal_edges() -> void:
	var pad: float = fresh_tuning().shake_strength
	var s: Array = await setup("home")
	var far: Node2D = s[0].current.scenery.layers.far
	check(far.get_child(0).global_position.y <= -pad, "地面房間的遠景上緣在 −%.0f 以上（是 %.0f）" % [pad, far.get_child(0).global_position.y])
	await teardown(s)
	s = await boss_gs()
	var sc = s[0].scenery
	for name in sc.regions:
		var top := INF
		for layer in sc.regions[name].get_children():
			for c in layer.get_children():
				if c is Sprite2D or c is ColorRect:
					top = minf(top, c.global_position.y)
		check(top <= Nance.VIEW.position.y - pad, "%s 的圖蓋到畫面上緣再往上 %.0f（最高 %.0f）" % [name, pad, top])
	sc.update_region(Palace.LEFT + SCREEN_W / 2.0)  # 宮殿戰鬥：鏡頭左緣正好在入口
	check(sc.regions.boss_path.visible, "鏡頭左緣在宮殿入口時小路也顯示（往左震才不露空白）")
	await free_boss(s)


# ---- MV-ASSET-015（Brian 試玩 b1，2026-10-11）----

## 這塊素材在世界座標 x 的那一欄，最上面的不透明像素的 y（沒有回傳 INF）
func art_top_at(sp: Sprite2D, wx: float) -> float:
	var img := sp.texture.get_image()
	var ix := int((wx - sp.global_position.x) / sp.scale.x)
	if ix < 0 or ix >= img.get_width():
		return INF
	for y in img.get_height():
		if img.get_pixel(ix, y).a > 0.5:
			return sp.global_position.y + y * sp.scale.y
	return INF


func boss_piece(sc, kind: String) -> Sprite2D:
	for p in sc.piece_rects():
		if p.kind == kind:
			return _piece_sprite(sc, p.rect)
	return null


func _piece_sprite(sc, r: Rect2) -> Sprite2D:
	for c in sc.terrain.get_children():
		if c is Sprite2D and c.global_position.is_equal_approx(r.position):
			return c
	return null


## nance 粗枝：整段平台上，樹枝的上緣（可站的面）在平台上緣 ±8 px
func test_nance_branch_art_on_platform() -> void:
	var s: Array = await boss_gs()
	var sp := boss_piece(s[0].scenery, "branch")
	check(sp != null and sp.texture.resource_path.ends_with("prop_nance_branch.png"), "樹枝平台用 nance 粗枝素材（是 %s）" % (sp.texture.resource_path if sp else "null"))
	if sp != null:
		var x := Nance.BRANCH.position.x
		while x <= Nance.BRANCH.end.x:
			var top := art_top_at(sp, x)
			check(absf(top - Nance.BRANCH.position.y) <= 8.0, "x＝%.0f：樹枝上緣 %.0f，平台上緣 %.0f" % [x, top, Nance.BRANCH.position.y])
			x += 20.0
	await free_boss(s)


## 宮殿入口：外牆立在地面上、右柱蓋住入口閘門，閘門左邊是走得過去的門洞
func test_palace_entrance_at_gate() -> void:
	var s: Array = await boss_gs()
	var sp := boss_piece(s[0].scenery, "palace_entrance")
	check(sp != null, "小路盡頭有宮殿入口外牆")
	if sp != null:
		var r := Rect2(sp.global_position, Vector2(sp.texture.get_size()) * sp.scale)
		check(absf(r.end.y - 900.0) <= 2.0 and absf(r.end.x - Palace.GATE.end.x) <= 2.0, "外牆底邊在地面、右緣在閘門右緣（%s）" % r)
		check(art_top_at(sp, Palace.GATE.get_center().x) < 900.0, "閘門的位置有外牆的柱子")
		var img := sp.texture.get_image()
		var row := int((850.0 - sp.global_position.y) / sp.scale.y)
		var solid := func(wx: float) -> bool: return img.get_pixel(int((wx - r.position.x) / sp.scale.x), row).a >= 0.5
		var x := Palace.GATE.position.x - 1.0
		while x > r.position.x and solid.call(x) and Palace.GATE.position.x - x < 200.0:  # 先跨過閘門所在的右柱
			x -= 1.0
		var open := 0
		while x > r.position.x and not solid.call(x):
			open += 1
			x -= 1.0
		check(open >= 200, "閘門那根柱子左邊的門洞寬 ≥ 200 px（是 %d）" % open)
	await free_boss(s)
