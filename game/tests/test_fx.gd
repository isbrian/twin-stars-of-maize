extends "res://tests/base_test.gd"
# MV-SLICE-001c1：Boss 特效（world/fx/，程式繪製的光暈、加亮混合）。
# 特效只在遊戲模式（有 GameState）掛；原型模式照舊畫灰盒。

const GameStateScr := preload("res://state/game_state.gd")
const Scenery := preload("res://world/scenery.gd")
const FxKitPath := "res://world/fx/fx_kit.gd"
const TEST_SAVE := "user://test_fx_slot.json"


## 有 GameState 的 Boss 戰（同 test_npc_rig.boss_fight）：回傳 [f, gs]
func fx_fight() -> Array:
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


## 原型模式（gs == null）的 Boss 戰
func proto_fight() -> Node:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.boss.cycle_enabled = false
	return f


## 直接把 Boss 放進某招的某一步（同 test_macaw_rig.set_move）
func set_move(b, mv: String, step: int, t := 0.0) -> void:
	var m = Macaw.MOVES[mv].new()
	m.boss = b
	m.step = step
	m.t = t
	b.move = m
	b.move_name = mv
	b.state = Macaw.State.MOVE


func end_fx_fight(s: Array) -> void:
	await free_fight(s[0])
	s[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## 貼圖的平均灰階亮度（每 4 px 取一點）
func mean_luma(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var sum := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			sum += luma(img.get_pixel(x, y))
			n += 1
	return sum / maxf(n, 1)


# ---- Task 1：基底與光源 ----

func test_light_fx_in_game_mode() -> void:
	var s: Array = await fx_fight()
	var light = s[0].boss.light
	check(light.get_node_or_null("LightFx") != null, "遊戲模式：光源底下有 LightFx")
	check(light.fx_drawn, "遊戲模式：光源的 fx_drawn 為 true（不畫灰盒）")
	await end_fx_fight(s)
	var p = await proto_fight()
	check(p.boss.light.get_node_or_null("LightFx") == null, "原型模式：沒有 LightFx")
	check(not p.boss.light.fx_drawn, "原型模式：fx_drawn 為 false（照舊畫灰盒）")
	await free_fight(p)


func test_light_fx_follows_light_after_head_swap() -> void:
	var s: Array = await fx_fight()
	var b = s[0].boss
	b.set_appearance(2)  # 受傷頭（失去玉牙）
	await frames(2)
	var fx = b.light.get_node_or_null("LightFx")
	check(fx != null, "有 LightFx")
	if fx != null:
		var d: float = fx.global_position.distance_to(b.light.global_position)
		check(d <= 0.5, "換頭後 LightFx 跟著光源（差 %.2f px）" % d)
	await end_fx_fight(s)


## 最暗（拔掉 3 個光源，灰階 0.3 倍）時光暈中心仍比宮殿背景亮得多
func test_light_glow_readable_in_darkest() -> void:
	if not ResourceLoader.exists(FxKitPath):
		check(false, "缺 %s" % FxKitPath)
		return
	var kit = load(FxKitPath)
	var img: Image = kit.glow_texture(64).get_image()
	check(img != null, "光暈貼圖讀得到像素（先被畫過也一樣）")
	if img == null:
		return
	var center := luma(img.get_pixel(32, 32))
	var bg := mean_luma(load(Scenery.BG % Scenery.BOSS["palace"]))
	var dark: float = Scenery.DARKNESS[3]
	check(center - bg * dark >= 0.4, "光暈中心 %.2f − 宮殿背景 %.2f × %.1f ≥ 0.4" % [center, bg, dark])


# ---- Task 2：反光柱與光束 ----

func add_pillar(f) -> Node2D:
	var pl = Pillar.new()
	pl.tn = f.tn
	pl.position = Vector2(Palace.HOME.x, Palace.GROUND_Y)
	f.world.add_child(pl)
	return pl


func test_pillar_fx_matches_hitbox() -> void:
	var s: Array = await fx_fight()
	var pl := add_pillar(s[0])
	await frames(1)
	var fx = pl.get_node_or_null("PillarFx")
	check(fx != null and pl.fx_drawn, "遊戲模式：光柱底下有 PillarFx、fx_drawn 為 true")
	if fx != null:
		var r: Rect2 = fx.core_rect()
		var hb := Rect2(pl.hitbox.position - Pillar.SIZE / 2.0, Pillar.SIZE)  # 判定框（pillar 本地座標）
		check(is_equal_approx(r.size.x, Pillar.SIZE.x), "實心寬＝柱寬（%s）" % r)
		check(is_equal_approx(r.position.x, hb.position.x) and is_equal_approx(r.end.x, hb.end.x), "實心 x 範圍＝判定 x 範圍（%s vs %s）" % [r, hb])
		check(fx.SOFT <= 8.0, "柔光每邊 ≤ 8 px（%s）" % fx.SOFT)
	pl.free()
	await end_fx_fight(s)


func test_pillar_fx_freed_with_pillar() -> void:
	var s: Array = await fx_fight()
	var f = s[0]
	var pl := add_pillar(f)
	await frames(1)
	check(pl.get_node_or_null("PillarFx") != null, "釋放前光柱底下有 PillarFx")
	pl.queue_free()
	await frames(2)
	check(f.world.find_children("PillarFx", "", true, false).is_empty(), "光柱釋放後 world 裡沒有 PillarFx")
	await end_fx_fight(s)


func test_beam_fx_matches_hitbox_both_facings() -> void:
	var s: Array = await fx_fight()
	var b = s[0].boss
	var fx = b.get_node_or_null("BeamFx")
	check(fx != null, "遊戲模式：Boss 底下有 BeamFx")
	if fx != null:
		for fc in [1, -1]:
			b.facing = fc
			set_move(b, "beam", 0)
			b.move.begin()
			var a: Rect2 = b.move.area()
			check(fx.core_rect() == a, "面向 %d：光束實心＝判定（%s vs %s）" % [fc, fx.core_rect(), a])
			var ln: PackedVector2Array = fx.aim_line()
			var cy := a.get_center().y
			check(ln.size() == 2 and is_equal_approx(ln[0].y, cy) and is_equal_approx(ln[1].y, cy), "面向 %d：瞄準虛線在判定中線（%s）" % [fc, ln])
			if ln.size() == 2:
				check(is_equal_approx(minf(ln[0].x, ln[1].x), a.position.x) and is_equal_approx(maxf(ln[0].x, ln[1].x), a.end.x), "面向 %d：瞄準虛線 x 範圍＝判定（%s vs %s）" % [fc, ln, a])
	await end_fx_fight(s)


func test_beam_gray_box_off_in_game_mode() -> void:
	var s: Array = await fx_fight()
	check(s[0].boss.fx_drawn, "遊戲模式：Boss 的 fx_drawn 為 true")
	await end_fx_fight(s)
	var p = await proto_fight()
	check(not p.boss.fx_drawn, "原型模式：Boss 的 fx_drawn 為 false")
	await free_fight(p)


# ---- Task 3：假光閃耀（聚光與白茫）----

const SCREEN := Vector2(1920, 1080)


## 還沒有的特效腳本：載入失敗時記一筆失敗、回傳 null（不讓整個測試檔無法載入）
func fx_script(file: String):
	var path := "res://world/fx/%s.gd" % file
	if not ResourceLoader.exists(path):
		check(false, "缺 %s" % path)
		return null
	return load(path)


## 畫面 3×3 取樣點
func screen_points() -> Array:
	var out := []
	for j in 3:
		for i in 3:
			out.append(Vector2(SCREEN.x * (0.1 + 0.4 * i), SCREEN.y * (0.1 + 0.4 * j)))
	return out


## 淡入、維持、淡出各 3 個時刻
func whiteout_times(tn) -> Array:
	var out := []
	var starts: Array = [0.0, tn.whiteout_in, tn.whiteout_in + tn.whiteout_hold]
	var lens: Array = [tn.whiteout_in, tn.whiteout_hold, tn.whiteout_out]
	for k in 3:
		for f in [0.25, 0.5, 0.75]:
			out.append(starts[k] + lens[k] * f)
	return out


func test_whiteout_never_clearer() -> void:
	var W = fx_script("whiteout_fx")
	if W == null:
		return
	var tn := fresh_tuning()
	var src := Vector2(960, 300)
	var times := whiteout_times(tn)
	for i in times.size():
		var s: float = times[i]
		var base := Whiteout.alpha_at(s, tn)
		for p in screen_points():
			var a: float = W.alpha_at_point(s, p, src, tn)
			check(a >= base - 0.0001, "s=%.2f %s：%.3f ≥ %.3f" % [s, p, a, base])
			if i >= 3 and i < 6:
				check(is_equal_approx(a, Whiteout.MAX_ALPHA), "維持段 s=%.2f %s：%.3f＝0.9" % [s, p, a])


func test_whiteout_source_offscreen() -> void:
	var W = fx_script("whiteout_fx")
	if W == null:
		return
	var tn := fresh_tuning()
	var s := tn.whiteout_in * 0.5
	for p in screen_points():
		var a: float = W.alpha_at_point(s, p, Vector2(960, -600), tn)
		check(a >= Whiteout.alpha_at(s, tn) - 0.0001, "光源在畫面外、淡入中途 %s：%.3f" % [p, a])


func test_flash_telegraph_strength_rises() -> void:
	var s: Array = await fx_fight()
	var b = s[0].boss
	var fx = b.get_node_or_null("FlashFx")
	check(fx != null, "遊戲模式：Boss 底下有 FlashFx")
	if fx != null:
		var st = b.state
		var last := 0.0
		for t in [0.1, 0.5, 0.9]:
			set_move(b, "false_flash", FalseFlash.Step.TELEGRAPH, t)
			var k: float = fx.strength()
			check(k > last and k <= 1.0, "t=%.1f：聚光強度 %.2f 嚴格遞增、≤ 1" % [t, k])
			last = k
		b.move = null
		b.move_name = ""
		b.state = st
		check(fx.strength() == 0.0, "沒有出招時強度 0")
	await end_fx_fight(s)


func test_whiteout_gray_box_off_in_game_mode() -> void:
	var s: Array = await fx_fight()
	var w = s[0].whiteout
	check(w.fx_drawn and w.get_parent().get_node_or_null("WhiteoutFx") != null, "遊戲模式：白茫 fx_drawn、同一層有 WhiteoutFx")
	await end_fx_fight(s)
	var p = await proto_fight()
	check(not p.whiteout.fx_drawn and p.whiteout.get_parent().get_node_or_null("WhiteoutFx") == null, "原型模式：沒有 WhiteoutFx、照舊畫灰盒")
	await free_fight(p)


# ---- Task 4：宮殿假光逐段熄滅 ----

func palace_lights(f):
	var pl = f.scenery.get("palace_lights")
	check(pl != null, "遊戲模式：場景有 PalaceLights")
	return pl


func test_palace_lights_follow_lights_removed() -> void:
	var s: Array = await fx_fight()
	var f = s[0]
	var pl = palace_lights(f)
	if pl != null:
		for i in 4:
			f.lights_removed = i
			f._apply_lights(true)  # 段落進行中拔掉光源：淡出中的組算熄了
			check(pl.lit_groups() == 3 - i, "lights_removed=%d → 亮著 %d 組（%d）" % [i, 3 - i, pl.lit_groups()])
	await end_fx_fight(s)


func test_palace_lights_jump_to_phase() -> void:
	var s: Array = await fx_fight()
	var f = s[0]
	var pl = palace_lights(f)
	if pl != null:
		f.start_at(3)
		check(pl.lit_groups() == 1, "start_at(3)：亮著 1 組（%d）" % pl.lit_groups())
		check(pl.alpha[0] == 0.0 and pl.alpha[1] == 0.0 and pl.alpha[2] == 1.0, "直接對應、沒有淡出中的組（%s）" % pl.alpha)
	await end_fx_fight(s)


func test_palace_fire_untouched() -> void:
	var s: Array = await fx_fight()
	var f = s[0]
	f.lights_removed = 3
	f._apply_lights()
	check(not f.rests.is_empty(), "有篝火")
	for id in f.rests:
		check(f.rests[id].modulate == Color.WHITE and f.rests[id].self_modulate == Color.WHITE, "篝火 %s 不受場地變暗影響" % id)
	await end_fx_fight(s)


# ---- Task 5：身上光點與熄滅 ----

## 遊戲模式的 MacawGlints 與 MacawAnimator（animator 停住：姿勢固定，測試自己擺）
func glints_of(f) -> Array:
	var b = f.boss
	var g = b.get_node_or_null("MacawGlints")
	check(g != null, "遊戲模式：Boss 底下有 MacawGlints")
	var a = b.get_node("MacawAnimator")
	a.set_physics_process(false)
	return [g, a, b.get_node("Rig")]


func test_glints_follow_rig() -> void:
	var s: Array = await fx_fight()
	var x := glints_of(s[0])
	var g = x[0]
	if g != null:
		check(g.NAMES.size() >= 8 and g.lit_count() == g.NAMES.size(), "至少 8 個光點、全亮（%d/%d）" % [g.lit_count(), g.NAMES.size()])
		x[1].pose_at("fly", 0.0)
		g.place()
		var r = x[2]
		for n in g.NAMES:
			var want: Vector2 = r.transform * r.point(n)
			check(g.glint_pos(n).distance_to(want) <= 1.0, "fly 第 0 格：%s 在骨架的光點上（%s vs %s）" % [n, g.glint_pos(n), want])
	await end_fx_fight(s)


func test_glints_survive_head_swap() -> void:
	var s: Array = await fx_fight()
	var x := glints_of(s[0])
	var g = x[0]
	if g != null:
		for st in [1, 2, 3]:
			s[0].boss.set_appearance(st)
			x[1].pose_at("idle_perch", 0.0)
			await frames(1)
			check(g.lit_count() == g.NAMES.size(), "外觀 %d：光點全亮（%d）" % [st, g.lit_count()])
		for n in g.NAMES:
			check(x[2].points.has(n) and x[2].points[n].bone != "head", "%s 在骨架資料、不掛在頭上" % n)
	await end_fx_fight(s)


func test_extinguish_far_to_near() -> void:
	var s: Array = await fx_fight()
	var x := glints_of(s[0])
	var g = x[0]
	if g != null:
		var r = x[2]
		var chest: Vector2 = r.to_local(r.joint_global("hip"))  # 胸口＝torso 骨頭起點
		var dist := func(n): return r.point(n).distance_to(chest)
		var got := [false]
		g.extinguished.connect(func(): got[0] = true)
		g.extinguish(1.0)
		var batches: Array = []  # 每次取樣新熄的光點
		var out := {}
		var counts: Array = []
		for wait in [12, 18, 18]:  # 0.2／0.5／0.8 秒
			await frames(wait)
			var now: Array = g.NAMES.filter(func(n): return not g.is_lit(n) and not out.has(n))
			for n in now:
				out[n] = true
			batches.append(now)
			counts.append(g.lit_count())
		batches.append(g.NAMES.filter(func(n): return not out.has(n)))
		check(counts[0] > counts[1] and counts[1] > counts[2], "亮著的數量遞減（%s）" % [counts])
		for i in batches.size():
			for j in range(i + 1, batches.size()):
				for a in batches[i]:
					for b2 in batches[j]:
						check(dist.call(a) >= dist.call(b2) - 0.5, "先熄的 %s（%.0f）比後熄的 %s（%.0f）離胸口遠" % [a, dist.call(a), b2, dist.call(b2)])
		await frames(14)
		check(g.lit_count() == 0 and g.aura() == 0.0, "1 秒後全熄、光暈 0（%d、%.2f）" % [g.lit_count(), g.aura()])
		check(got[0], "發出 extinguished")
	await end_fx_fight(s)


func test_glints_not_on_head_and_smaller_than_light() -> void:
	var G = fx_script("macaw_glints")
	var LightFx = fx_script("light_fx")
	if G == null or LightFx == null:
		return
	check(G.GLINT_D < LightFx.GLOW_D, "光點直徑 %.0f < 光源微亮光暈 %.0f" % [G.GLINT_D, LightFx.GLOW_D])
	for n in G.NAMES:
		check(n.begins_with("glint_"), "%s 是 glint_*" % n)


# ---- Task 6：--fx-view 展示 ----

func test_fx_showcase_playlist() -> void:
	var path := "res://world/fx_showcase.gd"
	check(ResourceLoader.exists(path), "有 %s" % path)
	if ResourceLoader.exists(path):
		var list: Array = load(path).playlist()
		var names := list.map(func(it): return it.name)
		check(names == ["light_off", "light_glow", "light_bright", "flash", "pillars", "beam", "palace_dark", "glints", "extinguish"], "播放順序（%s）" % [names])
		check(list.all(func(it): return it.secs > 0.0), "每項秒數 > 0")
	var o := LaunchArgs.parse(PackedStringArray(["--fx-view", "--frames", "/tmp/x"]))
	check(o.mode == "fx_view" and o.frames_dir == "/tmp/x", "--fx-view --frames 解析（%s）" % o)


# ---- 最終審查的修正 ----

## 實戰位置（樹冠，腳底 y=100、畫面上緣 −60）：聚光收攏到中心時的光點都在畫面內；在低枝時中心不被移動
func test_flash_gather_on_screen_at_canopy() -> void:
	var s: Array = await fx_fight()
	var b = s[0].boss
	var fx = b.get_node_or_null("FlashFx")
	check(fx != null, "有 FlashFx")
	if fx != null:
		b.facing = -1
		for at in [Nance.CANOPY, Nance.PERCH]:
			b.position = at
			set_move(b, "false_flash", FalseFlash.Step.TELEGRAPH, 0.9)
			await frames(2)
			var body: Rect2 = b.faced_body()
			var natural := Vector2(body.get_center().x, body.end.y - body.size.y * 0.55)
			var c: Vector2 = fx.center()
			var on_screen: Vector2 = fx.get_global_transform_with_canvas() * c
			check(on_screen.y - fx.NEAR >= 0.0, "%s：收攏的光點在畫面內（中心畫面 y %.0f）" % [at, on_screen.y])
			if at == Nance.PERCH:
				check(c.distance_to(natural) < 0.5, "低枝：中心不動（%s vs %s）" % [c, natural])
		b.move = null
		b.move_name = ""
		b.state = Macaw.State.DOWN
	await end_fx_fight(s)
