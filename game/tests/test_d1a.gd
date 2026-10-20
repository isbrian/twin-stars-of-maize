extends "res://tests/base_test.gd"
# MV-SLICE-001d1a 聲音系統：匯流排、資料表、變體、回退、環境音、距離層、前兆、配樂。
# headless 用 dummy audio driver：只驗 Audio 自己記下的狀態（播了什麼、音量多少），聽感由影片與手把驗收。

const Sound := preload("res://core/audio/sound_table.gd")
const BUSES := ["Music", "Amb", "Sfx", "Tell"]
const Index := preload("res://world/rooms/index.gd")
const GameStateScr := preload("res://state/game_state.gd")
const GameWorld := preload("res://world/game_world.gd")
const TEST_SAVE := "user://test_d1a_slot.json"


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## 測試結束時把 Audio 收乾淨（環境音、層的來源、listener）
func reset_audio() -> void:
	Audio.set_ambience(&"")
	Audio.listener = null
	await seconds(Sound.AMB_FADE + 0.2)


func test_audio_buses() -> void:
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		check(i >= 0, "缺匯流排 %s" % b)
		if i < 0:
			continue
		check(AudioServer.get_bus_send(i) == &"Master", "%s 要送往 Master" % b)
		check(is_equal_approx(AudioServer.get_bus_volume_db(i), Sound.BUS_DB[b]), "%s 音量 %s" % [b, AudioServer.get_bus_volume_db(i)])
	for b in ["Music", "Amb"]:
		var i := AudioServer.get_bus_index(b)
		var fx = AudioServer.get_bus_effect(i, 0) if i >= 0 and AudioServer.get_bus_effect_count(i) > 0 else null
		check(fx is AudioEffectCompressor, "%s 第 0 個效果要是壓縮器" % b)
		if fx is AudioEffectCompressor:
			check(fx.sidechain == &"Tell", "%s 的 sidechain 要是 Tell" % b)


func test_master_has_limiter() -> void:
	var lim = null
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			lim = AudioServer.get_bus_effect(0, i)
	check(lim != null, "Master 要有 HardLimiter（Boss 戰音效疊加時不削峰）")
	if lim != null:
		check(lim.ceiling_db <= -1.0, "上限 ≤ -1 dB（%s）" % lim.ceiling_db)


func test_sound_table_files_load() -> void:
	for id in Sound.SOUNDS:
		var e: Dictionary = Sound.SOUNDS[id]
		check(e.bus in BUSES, "%s 的匯流排 %s" % [id, e.bus])
		check(not e.files.is_empty(), "%s 沒有檔案" % id)
		for f in e.files:
			check(ResourceLoader.exists(f) and load(f) != null, "%s 載不到 %s" % [id, f])


func test_variants_do_not_repeat() -> void:
	for id in Sound.SOUNDS:
		if Sound.SOUNDS[id].files.size() < 2 or Sound.SOUNDS[id].get("loop", false):
			continue
		var prev := ""
		for i in 20:
			var f: String = Audio.play(id)
			check(f != prev, "%s 連續兩次選到 %s" % [id, f])
			prev = f


func test_loop_flags() -> void:
	for id in [&"amb_01", &"mus_b01", &"voc_danger_loop"]:
		var s = Audio._load(Sound.SOUNDS[id].files[0], true)
		check(s != null and s.loop, "%s 要循環" % id)
	var s1 = Audio._load(Sound.SOUNDS[&"mus_s01"].files[0], false)
	check(s1 != null and not s1.loop, "mus_s01 不循環")


func test_feedback_falls_back_to_synth() -> void:
	var fb = Feedback.new()
	add_child(fb)
	var before: int = Audio.play_count.get(&"shatter", 0)
	fb.play(&"swing")
	check(not Audio.play_count.has(&"swing"), "swing 還沒有正式檔，要走合成")
	check(fb._players.any(func(p): return p.playing), "合成佔位要在播")
	fb.play(&"shatter")
	check(Audio.play_count.get(&"shatter", 0) == before + 1, "shatter 要交給 Audio")
	fb.queue_free()


# ---- Task 2：環境音與距離層 ----

func test_every_room_has_ambience() -> void:
	for id in Index.ROOMS:
		var theme: String = Index.ROOMS[id].data().get("theme", "")
		check(Sound.THEME_AMBIENCE.has(theme), "%s 的 theme「%s」沒有環境音" % [id, theme])


func test_ambience_same_id_keeps_playing() -> void:
	Audio.set_ambience(&"amb_01")
	await seconds(0.3)
	var p: AudioStreamPlayer = Audio.ambience_player()
	Audio.set_ambience(&"amb_01")
	await frames(2)
	check(Audio.ambience_player() == p and p.playing, "同 id 不換播放器、不停")
	await reset_audio()


func test_ambience_crossfade() -> void:
	Audio.set_ambience(&"amb_02")
	await seconds(0.2)
	Audio.set_ambience(&"amb_01")
	await seconds(Sound.AMB_FADE + 0.2)
	check(Audio.ambience == &"amb_01", "目前是 amb_01（%s）" % Audio.ambience)
	check(Audio.ambience_players_playing() == 1, "淡化完只剩一個在播（%d）" % Audio.ambience_players_playing())
	await reset_audio()


func test_ambience_double_switch_settles() -> void:
	Audio.set_ambience(&"amb_02")
	await seconds(0.2)
	Audio.set_ambience(&"amb_01")
	await seconds(0.3)
	Audio.set_ambience(&"amb_03")
	await seconds(Sound.AMB_FADE + 0.2)
	check(Audio.ambience == &"amb_03" and Audio.ambience_players_playing() == 1, "快速換兩次：只剩 amb_03（%s、%d）" % [Audio.ambience, Audio.ambience_players_playing()])
	await reset_audio()


func test_ambience_stops_on_title() -> void:
	Audio.set_ambience(&"amb_01")
	await seconds(0.2)
	Audio.stop_all()
	await seconds(Sound.AMB_FADE + 0.2)
	check(Audio.ambience_players_playing() == 0, "回主選單：環境音停（%d）" % Audio.ambience_players_playing())
	check(Audio.music == &"", "回主選單：沒有配樂")


func test_audio_fades_while_paused() -> void:
	Audio.set_ambience(&"amb_02")
	await seconds(0.2)
	get_tree().paused = true
	Audio.set_ambience(&"amb_01")
	await seconds(Sound.AMB_FADE + 0.2)
	get_tree().paused = false
	check(Audio.ambience_players_playing() == 1, "暫停中淡化照樣完成（%d）" % Audio.ambience_players_playing())
	await reset_audio()


func _layer_case(group: StringName, layer: StringName, near: float, mid: float, far: float) -> void:
	var w := make_world()
	var lis := Node2D.new()
	w.add_child(lis)
	var src := Node2D.new()
	w.add_child(src)
	src.add_to_group(group)
	Audio.listener = lis
	src.position = Vector2(near, 0)
	await frames(2)
	check(absf(Audio.layer_db(layer) - Sound.LAYER_MAX_DB) < 0.1, "%s 近：最大（%s）" % [layer, Audio.layer_db(layer)])
	src.position = Vector2(mid, 0)
	await frames(2)
	var m := Audio.layer_db(layer)
	check(m < Sound.LAYER_MAX_DB - 0.1 and m > -80.0, "%s 中距離：介於兩者（%s）" % [layer, m])
	src.position = Vector2(far, 0)
	await frames(2)
	check(Audio.layer_db(layer) <= -80.0, "%s 遠：0（%s）" % [layer, Audio.layer_db(layer)])
	free_world(w)
	Audio.listener = null


func test_glass_layer_by_distance() -> void:
	await _layer_case(Audio.GROUP_GLASS, &"glass", 200.0, 600.0, 1000.0)


func test_danger_layer_by_distance() -> void:
	await _layer_case(Audio.GROUP_DANGER, &"danger", 100.0, 400.0, 700.0)


func test_glass_layer_survives_freed_source() -> void:
	var w := make_world()
	var lis := Node2D.new()
	w.add_child(lis)
	var src := Node2D.new()
	w.add_child(src)
	src.add_to_group(Audio.GROUP_GLASS)
	src.position = Vector2(100, 0)
	Audio.listener = lis
	await frames(2)
	src.queue_free()
	await frames(2)
	check(Audio.layer_db(&"glass") <= -80.0, "來源釋放後回到 0（%s）" % Audio.layer_db(&"glass"))
	free_world(w)
	Audio.listener = null


func test_room_registers_sources() -> void:
	var gs = make_gs()
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	w.dev_start("forest_4")
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var r = w.flow.current
	await frames(2)
	check(get_tree().get_nodes_in_group(Audio.GROUP_GLASS).size() == r.enemies.size() and r.enemies.size() > 0, "假光造物都在 glass 群組（%d／%d）" % [get_tree().get_nodes_in_group(Audio.GROUP_GLASS).size(), r.enemies.size()])
	check(get_tree().get_nodes_in_group(Audio.GROUP_DANGER).size() == r.hazards.size(), "荊棘都在 danger 群組")
	check(Audio.listener == r.player, "listener 是角色")
	check(Audio.ambience == &"amb_01", "森林是 amb_01（%s）" % Audio.ambience)
	w.queue_free()
	await seconds(Sound.AMB_FADE + 0.2)
	check(Audio.ambience == &"" and Audio.ambience_players_playing() == 0, "GameWorld 釋放（回主選單）：環境音停（%s、%d）" % [Audio.ambience, Audio.ambience_players_playing()])
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	await reset_audio()


# ---- Task 3：前兆與其他聲音語彙 ----

func count(id: StringName) -> int:
	return Audio.play_count.get(id, 0)


func test_crawler_telegraph_plays_parry_tell() -> void:
	await seconds(Sound.TELL_THROTTLE + 0.05)
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	var before := count(&"tell_parry")
	e.start_telegraph()
	check(count(&"tell_parry") == before + 1, "爬行型前搖：可招架前兆 +1")
	free_world(w)


func test_heavy_telegraph_plays_heavy_tell() -> void:
	await seconds(Sound.TELL_THROTTLE + 0.05)
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(300, 0))
	e.parryable = false
	var before := count(&"tell_heavy")
	e.start_telegraph()
	check(count(&"tell_heavy") == before + 1, "不可招架的前搖：不可招架前兆 +1")
	free_world(w)


func test_tell_throttled_same_frame() -> void:
	await seconds(Sound.TELL_THROTTLE + 0.05)
	var w := make_world()
	var es := []
	for i in 4:
		es.append(await make_enemy(w, Crawler, Vector2(300 + i * 200, 0)))
	var before := count(&"tell_parry")
	for i in 3:
		es[i].start_telegraph()
	check(count(&"tell_parry") == before + 1, "同一幀 3 隻前搖只播一次（+%d）" % (count(&"tell_parry") - before))
	await seconds(Sound.TELL_THROTTLE + 0.05)
	es[3].start_telegraph()
	check(count(&"tell_parry") == before + 2, "過了節流時間再一隻 → 再播")
	free_world(w)


func test_macaw_signal_plays_tell() -> void:
	await seconds(Sound.TELL_THROTTLE + 0.05)
	var s: Array = await boss_setup(1)
	var b = s[2]
	var before := count(&"tell_parry")
	b.start_move("throw_fruit")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 60)
	await frames(2)
	check(count(&"tell_parry") == before + 1, "擲果前搖：可招架前兆 +1（+%d）" % (count(&"tell_parry") - before))
	await frames(10)
	check(count(&"tell_parry") == before + 1, "前搖持續中不重播")
	await free_world(s[0])


func test_rest_and_npc_vocab() -> void:
	var gs = make_gs()
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	w.dev_start("home")
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	var r = w.flow.current
	r.player.scripted = true
	var real := count(&"voc_real")
	r.player.position = r.rest.position
	await frames(2)
	r._on_interact()
	check(count(&"voc_real") == real + 1, "篝火休息：真實 +1")
	get_tree().paused = false
	await wait_until(func(): return not w.flow.is_busy() and is_instance_valid(w.flow.current), 120)
	r = w.flow.current  # 休息會重建房間
	r.player.scripted = true
	var alive := count(&"voc_alive")
	r.player.position = Vector2(r.data.npc.pos.x, r.player.position.y)
	await frames(2)
	r._on_interact()
	check(count(&"voc_alive") == alive + 1, "跟祖母互動：活物 +1")
	get_tree().paused = false
	w.queue_free()
	await frames(2)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	await reset_audio()


# ---- Task 4：Seven Macaw 的音效與配樂 ----

func d1a_fight() -> Array:
	var gs = make_gs()
	gs.tn.card_min_time = 0.0
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


func end_d1a_fight(s: Array) -> void:
	Engine.time_scale = 1.0
	await free_fight(s[0])
	s[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Audio.stop_music()
	await seconds(Sound.MUSIC_OUT + 0.2)


func test_fight_starts_and_stops_music() -> void:
	var s: Array = await d1a_fight()
	var f = s[0]
	f._start_fight()
	await frames(3)
	check(Audio.music == &"mus_b01", "開打：MUS-B01（%s）" % Audio.music)
	f.stage = BossFight.Stage.CARD
	await frames(3)
	check(Audio.music == &"", "離開 FIGHT：配樂淡出（%s）" % Audio.music)
	await end_d1a_fight(s)


func test_music_stops_when_fight_node_freed() -> void:
	var s: Array = await d1a_fight()
	s[0]._start_fight()
	await frames(3)
	await free_fight(s[0])
	check(Audio.music == &"", "Boss 戰節點釋放：配樂停（%s）" % Audio.music)
	s[1].free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_gauge_full_cracks() -> void:
	var s: Array = await d1a_fight()
	s[0]._start_fight()
	await frames(2)
	var before := count(&"boss_sm_crack")
	s[0].debug_fill_gauge()
	await frames(2)
	check(count(&"boss_sm_crack") == before + 1, "破綻滿：裂紋 +1")
	await end_d1a_fight(s)


func _move_sounds(phase: int, mv: String, ids: Array) -> void:
	var s: Array = await boss_setup(phase)
	var b = s[2]
	var before := {}
	for id in ids:
		before[id] = count(id)
	b.start_move(mv)
	await wait_until(func(): return ids.all(func(id): return count(id) > before[id]), 400)
	for id in ids:
		check(count(id) > before[id], "%s：%s 有播" % [mv, id])
	await free_world(s[0])


func test_moves_play_their_sounds() -> void:
	await _move_sounds(1, "throw_fruit", [&"boss_sm_throw"])
	await _move_sounds(1, "dive", [&"boss_sm_dive"])
	await _move_sounds(1, "false_flash", [&"boss_sm_gather", &"boss_sm_flash"])
	await _move_sounds(1, "summon", [&"boss_sm_gather"])
	await _move_sounds(1, "eat_fruit", [&"boss_sm_eat"])
	await _move_sounds(2, "flail", [&"boss_sm_flail"])
	await _move_sounds(2, "throne_charge", [&"boss_sm_throne_hit", &"boss_sm_pillar_warn", &"boss_sm_pillar_strike"])
	await _move_sounds(2, "wail", [&"boss_sm_wail"])
	await _move_sounds(3, "beam", [&"boss_sm_beam_charge", &"boss_sm_beam_fire"])
	await _move_sounds(3, "stagger_pounce", [&"boss_sm_pounce"])


func test_death_and_awaken_sounds() -> void:
	var s: Array = await d1a_fight()
	var f = s[0]
	var before := {}
	for id in [&"boss_sm_kneel", &"boss_sm_light_fade", &"mus_s01"]:
		before[id] = count(id)
	f.start_at(3)
	await frames(2)
	f._on_setup(3)
	await frames(2)
	Engine.time_scale = 8.0
	while f.cutscene.running:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	for id in before:
		check(count(id) > before[id], "死亡與覺醒：%s 有播" % id)
	await end_d1a_fight(s)


func test_parried_fruit_breaks() -> void:
	var w := make_world()
	var f = Fruit.new()
	f.tn = fresh_tuning()
	w.add_child(f)
	var before := count(&"boss_sm_fruit_break")
	f.parried()
	check(count(&"boss_sm_fruit_break") == before + 1, "果子被招架擊碎：+1")
	free_world(w)


func test_ending_room_is_silent() -> void:
	var gs = make_gs()
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	w.flow.start("forest_1", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)
	check(Audio.ambience == &"amb_01", "森林有環境音（%s）" % Audio.ambience)
	w.flow.start("exit", false)
	await wait_until(func(): return not w.flow.is_busy() and w.flow.current_id == "exit", 60)
	await seconds(Sound.AMB_FADE + 0.2)
	check(Audio.ambience == &"" and Audio.ambience_players_playing() == 0, "結尾靜音（Brian 2026-10-20）（%s、%d）" % [Audio.ambience, Audio.ambience_players_playing()])
	w.queue_free()
	await frames(2)
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	await reset_audio()
