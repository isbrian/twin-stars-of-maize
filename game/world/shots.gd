extends Node
# 截圖模式（MV-SLICE-001b1，開發版 --shots <資料夾>）：依序開每個畫面，等 30 幀後存彩色與灰階截圖，
# 再量 120 幀的平均幀時間寫進 frametimes.txt，全部拍完結束程式。每個畫面用新的 GameWorld.dev_start 進入。

const GameWorld := preload("res://world/game_world.gd")
const TitleMenu := preload("res://ui/title_menu.gd")
const SAVE := "user://shots_slot.json"  # 不碰正式存檔
const SETTLE_FRAMES := 30
const TIMED_FRAMES := 120
# [截圖名稱, 房間, 進房後的設定]
const SHOTS := [
	["home", "home", ""],
	["field", "field", ""],
	["field_night", "field", "night"],
	["yard", "yard", ""],
	["forest_1", "forest_1", ""],
	["forest_1_lock", "forest_1", "x=2050"],  # MV-SLICE-001c4b：二段跳高台
	["forest_1_mid", "forest_1", "x=2880"],
	["forest_1_right", "forest_1", "x=4800"],
	["forest_2", "forest_2", ""],
	["forest_2_mid", "forest_2", "x=2880"],
	["forest_2_right", "forest_2", "x=4800"],
	["forest_3", "forest_3", ""],
	["forest_3_mid", "forest_3", "x=2880"],
	["forest_3_right", "forest_3", "x=4800"],
	["forest_4", "forest_4", ""],
	["forest_4_mid", "forest_4", "x=2880"],
	["forest_4_right", "forest_4", "x=4800"],
	["forest_5", "forest_5", ""],
	["forest_5_mid", "forest_5", "x=2880"],
	["forest_5_beam", "forest_5", "beam"],  # MV-SLICE-001c4c2：反光型出招當下
	["forest_5_right", "forest_5", "x=4800"],
	["forest_6", "forest_6", ""],
	["forest_6_mid", "forest_6", "x=2880"],
	["forest_6_right", "forest_6", "x=4800"],
	["forest_a", "forest_a", ""],
	["forest_a_right", "forest_a", "x=3200"],
	["forest_b", "forest_b", ""],
	["forest_b_right", "forest_b", "x=3300"],
	["forest_c", "forest_c", ""],
	["forest_c_right", "forest_c", "x=2880"],
	["boss_nance", "boss", "nance"],
	# MV-SLICE-001d2a HUD 檢查：各種狀態
	["hud_full", "forest_2", "hud_full"],
	["hud_half", "forest_2", "hud_half"],
	["hud_low", "forest_2", "hud_low"],
	["hud_rich", "forest_2", "hud_rich"],
	["hud_skill", "forest_2", "hud_skill"],
	["hud_hint", "forest_2", "hud_hint"],
	["hud_boss", "boss", "hud_boss"],
	["boss_path", "boss", "path"],
	["boss_path_awake", "boss", "path_awake"],  # MV-SLICE-001c4b：覺醒後從森林回到小路（含提示）
	["boss_palace", "boss", "palace"],
]

var dir := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var times := PackedStringArray()
	var only := OS.get_environment("SHOTS_ONLY")  # 開發時只拍名稱含這段字的（MV-SLICE-001d2a）
	for s in SHOTS:
		if only != "" and not only in s[0]:
			continue
		var w = GameWorld.new()
		w.save_path = SAVE
		w.fade_time = 0.0
		add_child(w)
		w.dev_start(s[1])
		while w.flow.is_busy() or w.flow.current == null:
			await get_tree().process_frame
		_setup(w, s[2])
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(s[0] + ".png"))
		img.convert(Image.FORMAT_L8)
		img.save_png(dir.path_join(s[0] + "_gray.png"))
		var t0 := Time.get_ticks_usec()
		for i in TIMED_FRAMES:
			await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / TIMED_FRAMES
		times.append("%s\t%.2f ms" % [s[0], ms])
		print("SHOTS %s %.2f ms" % [s[0], ms])
		w.queue_free()
		await get_tree().process_frame
	if only == "" or "title" in only or "credits" in only or "book" in only:
		await _menu_shots()
	var f := FileAccess.open(dir.path_join("frametimes.txt"), FileAccess.WRITE)
	f.store_string("\n".join(times) + "\n")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


## 跳過開場卡；田地調成夜晚；Boss 段落停住 Boss、擺到要拍的區段
func _setup(w, how: String) -> void:
	w.gs.set_flag("intro_seen")
	if w.runner.card.visible:
		w.runner.card.min_time = 0.0
		w.runner.card.confirm()
	var r = w.flow.current
	if how.begins_with("x="):  # 3 個畫面寬的房間：把角色放到 x，拍中段、右段（MV-SLICE-001c4a）
		r.player.scripted = true
		r.player.position = Vector2(float(how.substr(2)), r.data.ground_y)
		r.camera.reset_smoothing()
		return
	if how.begins_with("hud_"):
		_hud_state(w, r, how)
		return
	match how:
		"beam":  # 角色站在反光型正面，前搖剩 0.2 秒：拍攝時（SETTLE_FRAMES 後）正在射光束
			r.player.scripted = true
			r.player.position = Vector2(2880, r.data.ground_y)
			r.camera.reset_smoothing()
			for e in r.enemies:
				if e.has_method("blocks"):
					e.facing = -1
					e.turn_left = 0.0
					e.start_telegraph()
					e.state_time = e.tn.reflector_telegraph - 0.2
		"night":
			r.scenery.night = true
		"nance":
			r.boss.cycle_enabled = false
			r.start_at(1)
		"path":
			r.boss.cycle_enabled = false
			r.begin_at_rest("palace_camp")
		"path_awake":
			w.gs.awakened = true
			r.boss.cycle_enabled = false
			r.begin_from_forest()
		"palace":
			r.boss.cycle_enabled = false
			r.start_at(2)


## HUD 檢查（MV-SLICE-001d2a）：同一間房擺出不同狀態
func _hud_state(w, r, how: String) -> void:
	var p = r.get("player")
	var gs = w.gs
	match how:
		"hud_half":
			gs.stashes_taken["frag_a"] = true
			p.health.hp = maxi(p.health.max_hp - 2, 1)
		"hud_low":
			p.health.hp = 1
			p.health.heal_charges = 0
			gs.soup = 0
		"hud_rich":
			gs.cacao = 123
			gs.soup = 2
		"hud_skill":
			gs.skill_res = 1
			w.hud.flash_skill()
		"hud_hint":
			w.hints.request_now("attack")
		"hud_boss":
			r.boss.cycle_enabled = false
			r.start_at(1)
			r.hud.boss_gauge = 0.5
			r.hud.boss_name = "七金剛鸚鵡"


## 標題畫面與製作說明（MV-SLICE-001d2a）
func _menu_shots() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var t = TitleMenu.new()
	t.save_path = SAVE
	layer.add_child(t)
	for i in SETTLE_FRAMES * 2:
		await get_tree().process_frame
	await _snap("title")
	t.choose_item("製作說明")
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _snap("credits")
	t.credits.queue_free()
	t.credits = null
	# 繪本前篇 8 頁＋新遊戲詢問（MV-SLICE-001d2b）；直接跳頁，不拍到轉場
	t.choose_item("繪本")
	for n in range(1, 9):
		t.book.open(n)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		await _snap("book_front_%02d" % n)
	t.book.queue_free()
	t.book = null
	t.book_asked_path = "user://shots_book_asked.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(t.book_asked_path))
	t.choose_item("新遊戲")
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _snap("title_book_ask")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(t.book_asked_path))
	layer.queue_free()
	await get_tree().process_frame


func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))
	print("SHOTS ", n)
