extends "res://tests/base_test.gd"
# MV-SLICE-001d1b 新音效進遊戲：資料表、前兆專用播放器、距離衰減播放、腳步、戰鬥、敵人、拾取、介面、過場。
# 同 test_d1a：headless 只驗 Audio 記下的狀態（play_count、播放器），聽感由影片與手把驗收。

const Sound := preload("res://core/audio/sound_table.gd")
const NEW_IDS := [
	"mov_step_dirt_hunahpu", "mov_step_dirt_xbalanque", "mov_step_hard_hunahpu", "mov_step_hard_xbalanque",
	"mov_jump", "mov_land", "mov_double_jump", "mov_roll",
	"wpn_axe_swing", "wpn_axe_hit", "wpn_stick_swing", "wpn_stick_hit", "wpn_parry_ok", "wpn_parry_miss",
	"wpn_dart_fire", "wpn_dart_hit", "wpn_dart_weak",
	"cmb_hurt", "cmb_heal", "cmb_swap_hunahpu", "cmb_swap_xbalanque",
	"enm_crawler_move", "enm_crawler_attack", "enm_flyer_move", "enm_flyer_attack", "enm_reflector_move", "enm_reflector_block",
	"abl_tool_chop", "abl_tool_dig", "abl_rat_burrow", "abl_rat_emerge",
	"pick_cacao", "pick_fragment", "pick_item", "lvl_barrier_break", "lvl_barrier_thud", "lvl_pogo_crystal", "npc_exchange", "lvl_thorn_hurt",
	"cs_grass_crouch", "cs_macaw_fall", "cs_wing_wrench", "cs_sit_fall", "cs_animals_run", "cs_bush_regrow", "cs_lunge", "cs_net_drop",
	"cs_food_place", "cs_rat_climb", "cs_rat_gnaw", "cs_rope_snap", "cs_teeth_swap", "cs_gem_pluck", "cs_jewels_gather", "cs_arm_restore",
	"ui_move", "ui_confirm", "ui_back", "ui_skill_switch", "ui_page_open", "ui_page_close",
	# 取代合成的別名與反光型光束
	"double_jump", "dart", "hurt", "heal", "pogo", "barrier_break", "parry", "chop", "interrupt", "tool_out",
	"enm_reflector_beam_charge", "enm_reflector_beam_fire",
]
# 原始碼裡呼叫音效的寫法：feedback.play(&"x")、Audio.play(&"x")、Audio.play_at(&"x"、feedback.play.bind(&"x")、sfx(&"x")
const CALL_RE := "(?:feedback\\.play(?:\\.bind)?|Audio\\.play(?:_at)?|\\bsfx)\\(&\"([a-z0-9_]+)\""


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func count(id: StringName) -> int:
	return Audio.play_count.get(id, 0)


func _gd_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d != "tests" and not d.begins_with("."):
			out += _gd_files(dir.path_join(d))
	return out


func test_new_sounds_load() -> void:
	for id in NEW_IDS:
		check(Sound.SOUNDS.has(StringName(id)), "資料表缺 %s" % id)
		if Sound.SOUNDS.has(StringName(id)):
			for f in Sound.SOUNDS[StringName(id)].files:
				check(ResourceLoader.exists(f) and load(f) != null, "%s 載不到 %s" % [id, f])


func test_every_used_id_is_in_table() -> void:
	var re := RegEx.create_from_string(CALL_RE)
	var missing := {}
	for path in _gd_files("res://"):
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var id := m.get_string(1)
			if not Sound.SOUNDS.has(StringName(id)):
				missing[id] = path.get_file()
	check(missing.is_empty(), "程式用到、資料表沒有的 id：%s" % [missing])


func test_tell_not_cut_by_sfx() -> void:
	await seconds(Sound.TELL_THROTTLE + 0.05)
	for i in 20:
		Audio.play(&"wpn_axe_swing")
	Audio.play_tell(false)
	for i in 20:
		Audio.play(&"wpn_axe_swing")
	var heavy: Array = Sound.SOUNDS[&"tell_heavy"].files
	var ok := Audio._tell_players.any(func(p): return p.playing and p.stream != null and p.stream.resource_path in heavy)
	check(ok, "前兆在專用播放器上照播、沒被一般音效截斷")


func test_fade_ignores_hitstop() -> void:
	Audio.set_ambience(&"amb_02")
	await seconds(0.2)
	Engine.time_scale = 0.0
	Audio.set_ambience(&"amb_01")
	await seconds(Sound.AMB_FADE + 0.2)
	Engine.time_scale = 1.0
	check(Audio.ambience_players_playing() == 1, "命中停頓中淡化照樣完成（%d）" % Audio.ambience_players_playing())
	Audio.set_ambience(&"")
	await seconds(Sound.AMB_FADE + 0.2)


func test_one_shot_music_clears() -> void:
	Audio.play_music(&"mus_s01")
	await seconds(4.6)
	check(Audio.music == &"", "MUS-S01 放完：music 清空（%s）" % Audio.music)


func test_play_at_takes_position_only() -> void:
	await seconds(0.15)
	var f := Audio.play_at(&"enm_crawler_move", Vector2(100, 0))
	check(f != "", "放得出來")
	check(Audio._players_2d.any(func(p): return p.playing and p.global_position == Vector2(100, 0)), "2D 播放器在 (100, 0)")
	check(Audio.play_at(&"enm_crawler_move", Vector2(120, 0)) == "", "同一種移動聲 0.1 秒內不重播")


# ---- Task 2：角色與戰鬥 ----

## 角色＋接好音效的 Feedback（room 與 boss_fight 共用 Feedback.wire_moves）
func wired_player() -> Array:
	var w := make_world()
	var p = await make_player(w)
	var fb = Feedback.new()
	fb.tn = p.tn
	w.add_child(fb)
	fb.wire_moves(p)
	return [w, p, fb]


func test_sound_ids_by_weapon_and_twin() -> void:
	check(Sound.swing_id(Weapons.Weapon.AXE) == &"wpn_axe_swing", "斧頭揮擊")
	check(Sound.swing_id(Weapons.Weapon.STICK) == &"wpn_stick_swing", "掘棒揮擊")
	check(Sound.hit_id(Weapons.Weapon.AXE) == &"wpn_axe_hit" and Sound.hit_id(Weapons.Weapon.STICK) == &"wpn_stick_hit", "命中依武器")
	check(Sound.swap_id(0) == &"cmb_swap_hunahpu" and Sound.swap_id(1) == &"cmb_swap_xbalanque", "換人依兄弟")


func test_swing_uses_weapon_at_swing() -> void:
	var s: Array = await wired_player()
	var p = s[1]
	p.set_weapon(Weapons.Weapon.AXE)
	await frames(2)
	var axe := count(&"wpn_axe_swing")
	var stick := count(&"wpn_stick_swing")
	p.intent.attack_pressed = true
	await frames(1)
	p.set_weapon(Weapons.Weapon.STICK)  # 出招後同一幀換武器
	await frames(2)
	check(count(&"wpn_axe_swing") == axe + 1 and count(&"wpn_stick_swing") == stick, "記出招當下的武器（斧頭）")
	free_world(s[0])


func test_swap_plays_twin_cue() -> void:
	var s: Array = await wired_player()
	var p = s[1]
	var xb := count(&"cmb_swap_xbalanque")
	p.swap_twin()
	check(p.twin_index == 1 and count(&"cmb_swap_xbalanque") == xb + 1, "切到希巴拉克：縫鼓")
	free_world(s[0])


func test_jump_land_roll_sounds() -> void:
	var s: Array = await wired_player()
	var p = s[1]
	var j := count(&"mov_jump")
	var l := count(&"mov_land")
	await drive(p, [{"frames": 1, "jump": true, "hold": true}, {"frames": 20, "hold": true}])
	check(count(&"mov_jump") == j + 1, "起跳 +1")
	await wait_until(func(): return p.is_on_floor(), 120)
	await frames(2)
	check(count(&"mov_land") == l + 1, "落地 +1")
	var r := count(&"mov_roll")
	p.intent.roll_pressed = true
	await frames(2)
	check(count(&"mov_roll") == r + 1, "翻滾 +1")
	# 二段跳不放 mov_jump
	await wait_until(func(): return p.state == p.State.FREE and p.is_on_floor(), 120)
	await drive(p, [{"frames": 1, "jump": true, "hold": true}, {"frames": 20, "hold": true}])
	var j2 := count(&"mov_jump")
	await drive(p, [{"frames": 1, "jump": true, "hold": true}])
	check(count(&"mov_jump") == j2, "二段跳不算起跳")
	free_world(s[0])


func test_parry_whiff_sound() -> void:
	var s: Array = await wired_player()
	var p = s[1]
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	await frames(2)
	var m := count(&"wpn_parry_miss")
	p.intent.attack_pressed = true
	await wait_until(func(): return count(&"wpn_parry_miss") > m, 90)
	check(count(&"wpn_parry_miss") == m + 1, "招架落空 +1")
	free_world(s[0])


func test_dart_hits_wall_and_light() -> void:
	var w := make_world()
	var p = await make_player(w)
	var hit := count(&"wpn_dart_hit")
	p.intent.dart_pressed = true
	p.intent.aim = Vector2(1, 1).normalized()  # 斜下打地面
	await frames(30)
	check(count(&"wpn_dart_hit") == hit + 1, "吹箭打到地形：dart_hit +1")
	free_world(w)
	var w2 := make_world()
	var p2 = await make_player(w2)
	var a := make_fake_boss(w2, 600.0)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	var weak := count(&"wpn_dart_weak")
	p2.intent.dart_pressed = true
	await frames(25)
	check(count(&"wpn_dart_weak") == weak + 1, "吹箭打到微亮光源：dart_weak +1")
	free_world(w2)


# ---- Task 3：腳步 ----

const TwinAnimator := preload("res://world/twin_animator.gd")
const Actor := preload("res://world/cutscene/actor.gd")
const RoomScr := preload("res://world/room.gd")
const GameStateScr := preload("res://state/game_state.gd")
const Index := preload("res://world/rooms/index.gd")


func steps_total() -> int:
	var n := 0
	for id in [&"mov_step_dirt_hunahpu", &"mov_step_dirt_xbalanque", &"mov_step_hard_hunahpu", &"mov_step_hard_xbalanque"]:
		n += count(id)
	return n


func test_run_has_steps() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://rig/twin_anims.json"))
	var anims: Dictionary = d.get("anims", d)
	for n in ["run", "walk"]:
		var s: Array = anims[n].get("steps", [])
		check(s.size() == 2, "%s 有 2 個著地格（%s）" % [n, s])


func test_steps_crossed() -> void:
	var a := {"frames": [{"t": 0.0}, {"t": 0.1}, {"t": 0.2}, {"t": 0.3}], "steps": [1, 3]}
	check(TwinAnimator.steps_crossed(a, 12.0, 0.05, 0.15) == 1, "跨過第 1 格")
	check(TwinAnimator.steps_crossed(a, 12.0, 0.15, 0.25) == 0, "沒跨過著地格")
	check(TwinAnimator.steps_crossed(a, 12.0, 0.35, 0.50) == 1, "繞回循環開頭後跨過第 1 格（長度 0.3833，下一次在 0.4833）")


func test_step_id_by_twin_and_floor() -> void:
	check(Audio.step_id("hunahpu", &"dirt") == &"mov_step_dirt_hunahpu", "胡納普土地")
	check(Audio.step_id("xbalanque", &"hard") == &"mov_step_hard_xbalanque", "希巴拉克硬地")


func test_floor_material() -> void:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var home = RoomScr.new()
	add_child(home)
	home.build(Index.ROOMS["home"].data(), gs, gs.tn)
	check(home.floor_material_at(Vector2(700, home.data.ground_y)) == &"hard", "祖母家是硬地")
	home.queue_free()
	var f1 = RoomScr.new()
	add_child(f1)
	f1.build(Index.ROOMS["forest_1"].data(), gs, gs.tn)
	check(f1.floor_material_at(Vector2(1000, f1.data.ground_y)) == &"dirt", "森林地面是土")
	if not f1.data.platforms.is_empty():
		var r: Rect2 = f1.data.platforms[0]
		check(f1.floor_material_at(Vector2(r.get_center().x, r.position.y)) == &"hard", "站在平台上是硬地")
	f1.queue_free()
	await frames(2)
	gs.free()


func test_run_cycle_plays_two_steps() -> void:
	var w := make_world()
	var p = await make_player(w)
	TwinAnimator.attach(p)
	await frames(3)
	var before := steps_total()
	p.intent.move_x = 1.0
	await seconds(0.4167 * 3 + 0.05)  # 跑 3 個循環
	p.intent.move_x = 0.0
	var n := steps_total() - before
	check(n >= 5 and n <= 7, "跑 3 個循環約 6 步（%d）" % n)
	free_world(w)


func test_no_step_when_leaving_ground() -> void:
	var w := make_world()
	var p = await make_player(w)
	TwinAnimator.attach(p)
	p.intent.move_x = 1.0
	await seconds(0.3)
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(2)
	var before := steps_total()
	await seconds(0.3)  # 空中
	check(steps_total() == before, "空中不放腳步")
	p.intent.move_x = 0.0
	free_world(w)


func test_cutscene_twin_walk_steps() -> void:
	var w := make_world()
	var hu = Actor.make("hunahpu")
	var elder = Actor.make("healer_man")
	w.add_child(hu)
	w.add_child(elder)
	var before := steps_total()
	hu.play("walk")
	await wait_until(func(): return hu.t >= 0.9, 600)  # 一個循環 0.8333 秒：跨過第 2、0 格（看動作時間，不看真實時間）
	var after_hu := steps_total()
	check(after_hu - before >= 2, "過場的胡納普走路有腳步（%d）" % (after_hu - before))
	hu.play(hu.idle_anim())
	elder.play("walk")
	await wait_until(func(): return elder.t >= 0.9, 600)
	check(steps_total() == after_hu, "老人走路沒有腳步")
	free_world(w)


# ---- Task 4：敵人、能力、拾取、兌換、介面 ----

const Reflector := preload("res://core/enemies/reflector.gd")
const Rat := preload("res://core/player/rat.gd")
const Pickup := preload("res://world/pickup.gd")
const Shop := preload("res://ui/shop.gd")
const TitleMenu := preload("res://ui/title_menu.gd")
const EquipPage := preload("res://ui/equip_page.gd")
const GameWorld := preload("res://world/game_world.gd")


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func played_2d(id: StringName) -> bool:
	var files: Array = Sound.SOUNDS[id].files
	return Audio._players_2d.any(func(p): return p.stream != null and p.stream.resource_path in files)


func press(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func test_enemy_move_and_attack_positional() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(300, 0))  # 目標在遠處：只巡邏
	var m := count(&"enm_crawler_move")
	await wait_until(func(): return count(&"enm_crawler_move") > m, 120)
	check(count(&"enm_crawler_move") > m and played_2d(&"enm_crawler_move"), "巡邏中有移動聲、走 2D 播放器")
	free_world(w)
	var w2 := make_world()
	var p = await make_player(w2)
	var e2 = await make_enemy(w2, Crawler, Vector2(250, 0), p)
	var a := count(&"enm_crawler_attack")
	await wait_until(func(): return e2.state == Enemy.State.ATTACK, 180)
	await frames(1)
	check(count(&"enm_crawler_attack") == a + 1 and played_2d(&"enm_crawler_attack"), "撲咬出招：攻擊聲 +1、走 2D 播放器")
	free_world(w2)


func test_enemy_move_silent_when_still() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	e.stun(10.0)
	await frames(5)
	var m := count(&"enm_crawler_move")
	await frames(60)
	check(count(&"enm_crawler_move") == m, "沒在移動時不放移動聲")
	free_world(w)


func test_reflector_beam_sounds() -> void:
	var w := make_world()
	var e = await make_enemy(w, Reflector, Vector2(300, 0))
	var c := count(&"enm_reflector_beam_charge")
	var f := count(&"enm_reflector_beam_fire")
	e.turn_left = 0.0
	e.start_telegraph()
	await frames(1)
	check(count(&"enm_reflector_beam_charge") == c + 1, "前搖：光束蓄力 +1")
	await wait_until(func(): return e.state == Enemy.State.ATTACK, 180)
	await frames(1)
	check(count(&"enm_reflector_beam_fire") == f + 1, "發射：光束 +1")
	check(count(&"enm_reflector_attack") == 0, "反光型沒有另外的攻擊聲")
	free_world(w)


func test_rat_burrow_emerge() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(400, 0))
	e.stun(10.0)
	var b := count(&"abl_rat_burrow")
	var em := count(&"abl_rat_emerge")
	var r = Rat.new()
	r.tn = fresh_tuning()
	w.add_child(r)
	r.launch(Vector2(0, 0), 1, e)
	check(count(&"abl_rat_burrow") == b + 1, "鑽地 +1")
	var ref: WeakRef = weakref(r)  # lambda 直接抓 r，r 釋放後 Godot 會警告「Lambda capture was freed」
	await wait_until(func(): return ref.get_ref() == null, 240)
	check(count(&"abl_rat_emerge") == em + 1, "竄出咬一口 +1")
	free_world(w)


func test_pickup_sounds() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(-300, 0))
	var cacao = Pickup.new()
	cacao.position = Vector2(0, 0)
	w.add_child(cacao)
	var frag = Pickup.new()
	frag.fragment = true
	frag.position = Vector2(200, 0)
	w.add_child(frag)
	var c := count(&"pick_cacao")
	var f := count(&"pick_fragment")
	p.position = Vector2(0, 0)
	await frames(3)
	check(count(&"pick_cacao") == c + 1, "碰到可可豆 +1")
	p.position = Vector2(200, 0)
	await frames(3)
	check(count(&"pick_fragment") == f + 1, "碰到血量碎片 +1")
	free_world(w)


func test_item_pickup_sound() -> void:
	var gs = make_gs()
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = "user://test_d1b_slot.json"
	w.fade_time = 0.0
	add_child(w)
	w.flow.start("field", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var i := count(&"pick_item")
	var ids: Array = w.flow.current.pickups.map(func(pk): return pk.id)
	if not ids.is_empty():
		w.runner._on_interact("pickup:" + ids[0])
	check(not ids.is_empty() and count(&"pick_item") == i + 1, "撿起工具 +1（%s）" % [ids])
	w.queue_free()
	await frames(2)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_d1b_slot.json"))


func test_exchange_sound() -> void:
	var gs = make_gs()
	var shop = Shop.new()
	shop.open(gs)
	var n := count(&"npc_exchange")
	shop.confirm()
	check(count(&"npc_exchange") == n, "豆子不足：沒有兌換聲")
	gs.add_cacao(40)
	shop.confirm()
	check(count(&"npc_exchange") == n + 1, "兌換成功 +1")
	shop.free()
	gs.free()


func test_menu_sounds() -> void:
	var t = TitleMenu.new()
	t.save_path = "user://test_d1b_none.json"
	t.book_asked_path = "user://test_d1b_asked_none.json"  # 不讀正式的繪本詢問記錄（MV-SLICE-001d2b）
	add_child(t)
	await frames(2)
	var mv := count(&"ui_move")
	await press(&"look_down")
	check(count(&"ui_move") == mv + 1, "主選單移動 +1")
	var ok := count(&"ui_confirm")
	t.choose_item("新遊戲")
	check(count(&"ui_confirm") == ok + 1, "主選單確認 +1")
	t.queue_free()
	await frames(2)


func test_ui_sounds_while_paused() -> void:
	var gs = make_gs()
	var page = EquipPage.new()
	page.process_mode = Node.PROCESS_MODE_ALWAYS  # 遊戲裡掛在暫停選單底下（ALWAYS）
	add_child(page)
	get_tree().paused = true
	var o := count(&"ui_page_open")
	page.open(gs)
	check(count(&"ui_page_open") == o + 1, "暫停中打開裝備頁 +1")
	var c := count(&"ui_page_close")
	await frames(2)  # 開頁那一幀的按鍵會被 MenuInput.swallow() 吞掉（防穿透）
	await press(&"pause")
	check(count(&"ui_page_close") == c + 1, "暫停中關上裝備頁 +1")
	get_tree().paused = false
	page.queue_free()
	await frames(2)
	gs.free()
	var card = TextCard.new()
	add_child(card)
	var co := count(&"ui_page_open")
	card.show_card("測試")
	check(count(&"ui_page_open") == co + 1, "文字卡打開 +1")
	var cc := count(&"ui_page_close")
	card.min_time = 0.0
	card.confirm()
	check(count(&"ui_page_close") == cc + 1, "文字卡關上 +1")
	card.queue_free()


## 展示影片裡落地聲播了 52 次（只跳兩次）：在地面上被直接移動位置時，is_on_floor 會在兩幀之間閃動
func test_no_land_while_grounded() -> void:
	var s: Array = await wired_player()
	var p = s[1]
	await frames(5)
	var l := count(&"mov_land")
	for i in 60:
		p.position.x += 12.0
		await frames(1)
	p.intent.move_x = 1.0
	await frames(30)
	p.intent.move_x = 0.0
	check(count(&"mov_land") == l, "在地面上移動不放落地聲（+%d）" % (count(&"mov_land") - l))
	free_world(s[0])


## 展示影片裡每次換房都多一聲落地：出生點略高於地面，掉下來幾幀就著地
func test_room_entry_no_land() -> void:
	var gs = make_gs()
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = "user://test_d1b_slot.json"
	w.fade_time = 0.0
	add_child(w)
	var l := count(&"mov_land")
	w.dev_start("forest_1")
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	await frames(30)
	check(count(&"mov_land") == l, "換房出生不放落地聲（+%d）" % (count(&"mov_land") - l))
	w.queue_free()
	await frames(2)
	gs.free()


## 最終審查 Important：Boss 戰中吹箭打中微亮光源，dart.gd 放 dart_weak、_on_glow_struck 又放 interrupt（同一組檔）→ 疊兩層。
## 吹箭本身放的那一次由 test_dart_hits_wall_and_light 驗；這裡驗 Boss 戰收到 glow_struck 時不再放第二次
func test_glow_hit_sounds_once() -> void:
	var f = await make_fight(1)
	var b = f.boss
	b.start_move("eat_fruit")
	await wait_until(func(): return b.light.state == Light.State.GLOW, 400)
	var hits := []
	b.glow_struck.connect(func(_n): hits.append(1))
	var before := count(&"wpn_dart_weak") + count(&"interrupt")
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")  # 同 test_boss：模擬吹箭打中（不經 dart.gd，所以不含它那一聲）
	x.free()
	await frames(2)
	check(not hits.is_empty(), "打中微亮光源（glow_struck）")
	check(count(&"wpn_dart_weak") + count(&"interrupt") == before, "Boss 戰不再另放（+%d）" % (count(&"wpn_dart_weak") + count(&"interrupt") - before))
	await free_fight(f)
