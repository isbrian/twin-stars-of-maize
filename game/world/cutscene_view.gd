extends Node
# Boss 戰演出的開發畫面（MV-SLICE-001c2a，開發版 --cutscene <名稱>）：1920×1080 的 SubViewport 裝一個 GameWorld，
# 擺好該段的前置狀態後播那段演出，結束 0.5 秒後關閉程式。
# opening：進 Boss 段落、角色越過 nance 入口；arm：第 1 段開打後直接設局成功（斷臂接轉場）；couple：套用斷臂的結束狀態後只播轉場。
# MV-SLICE-001c2b：toothache：從宮殿篝火出發、越過宮殿入口；teeth：第 2 段開打後直接設局成功；death：第 3 段開打後直接設局成功（接著播覺醒，c2c）。
# MV-SLICE-001c2c：awaken：第 3 段開打後套用死亡的結束狀態，只播覺醒；finale：覺醒後的出口，站上高台播結尾。
# MV-SLICE-001c3a：地面段落 field（清完田地：收工＋動物復原）、deal（把老鼠趕到牆角：交換）、rope（抓到老鼠後進祖母家：咬繩）、morning（撿起球具：天亮）。
# 錄驗收影片：godot --path game --fixed-fps 30 -- --cutscene <名稱> --frames <資料夾> → 每格存 JPG（同 fx_showcase.gd）。

const GameWorld := preload("res://world/game_world.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const Arm := preload("res://world/cutscene/arm.gd")
const Couple := preload("res://world/cutscene/couple.gd")
const Death := preload("res://world/cutscene/death.gd")
const Awaken := preload("res://world/cutscene/awaken.gd")

const NAMES := ["opening", "arm", "couple", "toothache", "teeth", "death", "awaken", "finale", "field", "deal", "rope", "morning"]
const GROUND := {  # 地面段落：房間、前置旗標
	"field": ["field", ["intro_seen", "tools_obtained"]],
	"deal": ["field", ["intro_seen", "tools_obtained", "field_cleared", "night_seen"]],
	"rope": ["home", ["intro_seen", "tools_obtained", "field_cleared", "night_seen", "rat_caught"]],
	"morning": ["home", ["intro_seen", "tools_obtained", "field_cleared", "night_seen", "rat_caught", "gear_dropped"]],
}
const Weapons := preload("res://core/player/weapons.gd")
const SIZE := Vector2i(1920, 1080)
const SAVE := "user://cutscene_view_slot.json"  # 不碰正式存檔

var scene_name := ""
var frames_dir := ""
var viewport: SubViewport
var _done := false


func _ready() -> void:
	if not NAMES.has(scene_name):
		push_error("--cutscene 只接受 %s" % [NAMES])
		get_tree().quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen := TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.size = Vector2(SIZE)
	add_child(screen)
	var w = GameWorld.new()
	w.save_path = SAVE
	w.fade_time = 0.0
	viewport.add_child(w)
	if GROUND.has(scene_name):
		await _ground(w)
		return
	w.dev_start("boss", {"opening": 0, "toothache": 0, "teeth": 2, "death": 3, "awaken": 3, "finale": 3}.get(scene_name, 1))
	while w.flow.is_busy() or w.flow.current_id != "boss" or (not scene_name in ["opening", "toothache"] and w.flow.current.stage != w.flow.current.Stage.FIGHT):
		await get_tree().process_frame
	var f = w.flow.current
	f.boss.cycle_enabled = false
	if frames_dir != "":
		_dump_frames()
	match scene_name:
		"opening":
			f.player.position = Vector2(Nance.ENTRY_X + 60.0, Nance.GROUND_Y)
			await get_tree().process_frame
		"arm":
			f._on_setup(1)
		"teeth":
			f._on_setup(2)
		"death":
			f._on_setup(3)
		"toothache":
			f.begin_at_rest("palace_camp")
			await get_tree().process_frame
			f.player.position = Vector2(Palace.ENTRY_X + 60.0, Palace.GROUND_Y)
			await get_tree().process_frame
		"couple":
			Arm.new().end_state(f)
			f.cutscene.run([Couple.new()])
		"finale":  # 覺醒後的出口：直接站上高台
			f.start_at(4)
			await get_tree().process_frame
			f.player.velocity = Vector2.ZERO
			f.player.position = Vector2(Palace.EXIT_LEDGE.position.x + 200.0, Palace.EXIT_LEDGE.position.y)
		"awaken":  # 只播覺醒（death 會接著播覺醒）
			Death.new().end_state(f)
			f.stage = f.Stage.CARD
			f.cutscene.run([Awaken.new()])
	await get_tree().process_frame
	while f.cutscene.running:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_done = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


## 地面段落：擺好前置旗標進房間，觸發那段過場，等它播完
func _ground(w) -> void:
	var gs = w.gs
	gs.reset_new_game()
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.give_weapon(Weapons.Weapon.STICK)
	for f in GROUND[scene_name][1]:
		gs.set_flag(f)
	w.flow.start(GROUND[scene_name][0], false)
	while w.flow.is_busy() or w.flow.current == null:
		await get_tree().process_frame
	await get_tree().process_frame
	var r = w.flow.current
	r.player.scripted = true
	if frames_dir != "":
		_dump_frames()
	match scene_name:
		"field":
			await get_tree().create_timer(0.5).timeout
			for c in r.get_children():
				if (c.get("kind") == "bush" or c.get("kind") == "clod") and c.hurtbox != null:
					r.player.attack_weapon = Weapons.Weapon.AXE if c.kind == "bush" else Weapons.Weapon.STICK
					c.hurtbox.receive(4, r.player, &"melee")
		"deal":
			for c in r.get_children():
				if c.get("kind") == "rat":
					c.position.x = 130.0
					r.player.position = Vector2(330.0, r.data.ground_y)
		"morning":
			while r.pickups.is_empty():
				await get_tree().process_frame
			await get_tree().create_timer(0.5).timeout
			w.runner._on_interact("pickup:gear")
	while not w.runner.cutscene_running():
		await get_tree().process_frame
	while w.runner.cutscene_running():
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_done = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


## 逐格輸出：每畫完一格存 JPG，直到演出結束
func _dump_frames() -> void:
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var i := 0
	while not _done:
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_jpg(frames_dir.path_join("%05d.jpg" % i), 0.92)
		i += 1
	print("CUTSCENE frames=%d" % i)
