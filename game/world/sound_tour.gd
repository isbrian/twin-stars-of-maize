extends Node
# 聲音展示（MV-SLICE-001d1a，開發版 --sound-tour）：依序跑各段，配 --write-movie 錄成有音軌的影片給 Brian 試聽。
# 角色用腳本擺位（scripted），不靠手動輸入；角色血量每幀補滿，免得中途死掉、房間重建。每段左上角寫「這段聽什麼」。
# MV-SLICE-001d1b：加腳步（土、硬地、兩兄弟）、戰鬥、拾取、老鼠、選單、地面與 Boss 過場。

const GameWorld := preload("res://world/game_world.gd")
const SAVE := "user://sound_tour_slot.json"  # 不碰正式存檔
const Weapons := preload("res://core/player/weapons.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Enemy := preload("res://core/enemies/enemy.gd")
const PogoCrystal := preload("res://core/level/pogo_crystal.gd")

var world
var _label: Label
var _god := true


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(40, 30)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	# 開發時只跑部分段落：SOUNDTOUR_ONLY=menus,moves（逗號分隔；錄影一律全跑）
	var only := OS.get_environment("SOUNDTOUR_ONLY").split(",", false)
	for part in ["ground", "moves", "menus", "pickups", "forest", "reflector", "ground_cutscenes", "boss"]:
		if only.is_empty() or part in only:
			if world == null and part != "ground":
				await _open("home")
			await call("_" + part)
	print("SOUNDTOUR counts ", Audio.play_count)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


func _process(_delta: float) -> void:
	if _god and world != null and is_instance_valid(world.flow.current) and world.flow.current.get("player") != null:
		var p = world.flow.current.player
		p.health.hp = p.health.max_hp


var _sections: Array = []


## text 開頭的代號（第一個空白前）只用來分段；畫面上依出現順序重新編號
func _say(text: String) -> void:
	var key := text.get_slice(" ", 0)
	if not key in _sections:
		_sections.append(key)
	text = "%d %s" % [_sections.find(key) + 1, text.substr(key.length() + 1)]
	_label.text = text
	print("SOUNDTOUR ", text)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _open(room: String, phase := 0) -> Node:
	if world != null:
		world.queue_free()
		await get_tree().process_frame
	world = GameWorld.new()
	world.save_path = SAVE
	world.fade_time = 0.3
	add_child(world)
	world.gs.set_flag("intro_seen")
	world.dev_start(room, phase)
	await _settle()
	return world.flow.current


func _settle() -> void:
	while world.flow.is_busy() or world.flow.current == null:
		await get_tree().process_frame
	await get_tree().process_frame
	if world.runner.card.visible:
		world.runner.card.min_time = 0.0
		world.runner.card.confirm()


func _goto(room: String, door: String) -> Node:
	world.flow.goto(room, door)
	await get_tree().process_frame
	await _settle()
	return world.flow.current


## 角色在 secs 秒內從 from 走到 to（直接改位置；這支影片只聽聲音）
func _walk(r, from: float, to: float, secs: float) -> void:
	r.player.scripted = true
	var t := 0.0
	while t < secs:
		t += get_process_delta_time()
		r.player.position.x = lerpf(from, to, clampf(t / secs, 0.0, 1.0))
		await get_tree().process_frame


## 按一下選單鍵（同 MenuInput：每幀輪詢 just_pressed）
func _press(action: StringName) -> void:
	await get_tree().process_frame  # 在一幀的開頭按：計時器喚醒時那一幀的 _process 已經跑完，選單會讀不到
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await _wait(0.35)


## 用按鍵意圖跑 secs 秒（真的移動，跑步動作才會放腳步）
func _run(r, dir: float, secs: float) -> void:
	r.player.scripted = true
	r.player.intent.move_x = dir
	await _wait(secs)
	r.player.intent.move_x = 0.0
	await _wait(0.3)


func _tap(r, field: String) -> void:
	r.player.scripted = true  # 不然真實輸入每幀會蓋掉
	r.player.intent.set(field, true)
	await get_tree().physics_frame
	await _wait(0.6)


## 等過場開始再等它結束（最多 max_secs 秒）
func _wait_cutscene(max_secs := 60.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not world.runner.cutscene_running() and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	while world.runner.cutscene_running() and Time.get_ticks_msec() - t0 < max_secs * 1000.0:
		await get_tree().process_frame
	await _wait(1.0)


func _ground() -> void:
	var r = await _open("home")
	_say("1 祖母家：環境音 AMB-02（家）；屋內跑步＝硬地腳步")
	await _run(r, 1.0, 1.5)
	await _run(r, -1.0, 1.5)
	_say("1 祖母家：篝火休息＝真實")
	r.player.scripted = true
	r.player.position = r.rest.position
	await get_tree().physics_frame
	r._on_interact()
	await _wait(3.0)
	r = world.flow.current
	r.player.scripted = true
	_say("1 祖母家：跟祖母互動＝活物")
	r.player.position.x = r.data.npc.pos.x
	await get_tree().physics_frame
	r._on_interact()
	await _wait(2.5)
	world.shop.visible = false
	world.shop.closed.emit()
	get_tree().paused = false
	_say("2 田地：同一個環境音，換房不重啟")
	await _goto("field", "to_home")
	await _wait(4.0)
	await _goto("home", "to_field")
	_say("3 家前空地：交叉淡化到 AMB-03（球場）")
	await _goto("yard", "to_home")
	await _wait(5.0)


func _menus() -> void:
	_say("2b 暫停選單：移動、確認；裝備頁：開、換裝備、關；返回")
	world.pause_menu.open()
	await _wait(0.4)
	await _press(&"look_down")
	await _press(&"look_up")
	await _press(&"attack")  # 裝備
	await _press(&"look_down")
	await _press(&"attack")  # 換裝備
	await _press(&"pause")  # 關裝備頁
	await _press(&"pause")  # 關暫停選單
	get_tree().paused = false
	await _wait(1.0)


func _moves() -> void:
	var r = await _open("forest_2")
	var p = r.player
	for x in r.enemies.duplicate():  # 示範動作時不被打斷（受擊硬直會吃掉按鍵）
		x.queue_free()
	r.enemies.clear()
	p.abilities_enabled = true  # 二段跳是覺醒後的能力；展示直接開
	_say("10 森林 2：土地腳步（胡納普）→ 換人（縫鼓）→ 土地腳步（希巴拉克）")
	await _run(r, 1.0, 2.0)
	if p.twin_index == 0:
		p.swap_twin()
	else:
		p.swap_twin()
		await _wait(0.6)
		p.swap_twin()
	await _wait(0.6)
	await _run(r, 1.0, 2.0)
	_say("10 跳、落地、二段跳（胡納普）、翻滾")
	if p.twin_index != 0:
		p.swap_twin()
		await _wait(0.6)
	p.intent.jump_held = true
	p.intent.jump_pressed = true
	await _wait(0.3)  # 還在空中
	p.intent.jump_pressed = true  # 二段跳
	await _wait(0.8)
	p.intent.jump_held = false
	await _wait(1.0)
	await _tap(r, "roll_pressed")
	_say("10 森林 2：打木障（悶敲）→ 木障打破；下劈水晶彈起")
	if not r.barriers.is_empty():
		var bar = r.barriers[0]
		p.set_weapon(Weapons.Weapon.AXE)
		p.position = Vector2(bar.global_position.x - 120.0, p.position.y)
		p.facing = 1
		await _tap(r, "attack_pressed")
		await _wait(0.4)
		if is_instance_valid(bar):
			bar.break_apart()
		await _wait(1.0)
	var crystals: Array = r.get_children().filter(func(c): return c is PogoCrystal)
	if not crystals.is_empty():
		var c: Node2D = crystals[0]
		p.position = c.global_position + Vector2(0, -160)
		p.velocity = Vector2.ZERO
		p.intent.down = true
		await _tap(r, "attack_pressed")
		p.intent.down = false
		await _wait(1.0)
	_say("10 揮擊：斧頭、掘棒；吹箭打地面；球具招架落空；喝熱湯")
	for w in [Weapons.Weapon.AXE, Weapons.Weapon.STICK]:
		p.set_weapon(w)
		await _tap(r, "attack_pressed")
		await _wait(0.4)  # 等收招完
	p.intent.aim = Vector2(1, 1).normalized()
	await _tap(r, "dart_pressed")
	p.intent.aim = Vector2.ZERO
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	await _tap(r, "attack_pressed")
	await _wait(0.6)
	_god = false  # 滿血不能喝湯：先扣血
	p.health.hp = 1
	world.gs.soup = 2
	await _tap(r, "heal_pressed")
	await _wait(1.2)
	_god = true
	r = await _open("forest_1")
	p = r.player
	p.scripted = true
	var e = r.enemies[0] if not r.enemies.is_empty() else null
	if e != null:
		_say("10 打爬行型：命中、前兆、受擊；老鼠鑽地突襲")
		p.set_weapon(Weapons.Weapon.AXE)
		e.stun(4.0)  # 先暈住：不然一靠近就被撲、受擊硬直吃掉按鍵
		p.position.x = e.position.x - 140.0
		p.facing = 1
		await _wait(0.3)
		for i in 2:
			await _tap(r, "attack_pressed")
		await _wait(2.5)
		p.position.x = e.position.x - 500.0 if is_instance_valid(e) else p.position.x
		p.facing = 1
		if is_instance_valid(e):
			e.stun(4.0)
		await _tap(r, "skill_1_pressed")
		await _wait(2.0)
	var e2 = null
	for x in r.enemies:
		if is_instance_valid(x) and x != e and x.get_script().resource_path.ends_with("crawler.gd"):
			e2 = x
	if e2 != null:
		_say("10 球具招架爬行型的撲咬＝招架成功")
		p.set_weapon(Weapons.Weapon.BALLGEAR)
		p.position.x = e2.position.x - 320.0
		p.facing = 1
		var t0 := Time.get_ticks_msec()
		while is_instance_valid(e2) and e2.state != Enemy.State.ATTACK and Time.get_ticks_msec() - t0 < 6000:
			await get_tree().physics_frame
		while is_instance_valid(e2) and absf(e2.global_position.x - p.global_position.x) > 200.0 and Time.get_ticks_msec() - t0 < 7000:
			await get_tree().physics_frame
		p.intent.attack_pressed = true
		await _wait(1.5)


func _pickups() -> void:
	var r = await _open("forest_3")
	_say("11 森林 3：撿可可豆藏點")
	if r.stash != null:
		r.player.scripted = true
		r.player.position = r.stash.global_position
		await _wait(1.5)
	r = await _open("forest_a")
	_say("11 支路 A：撿血量碎片")
	if r.fragment_pickup != null:
		r.player.scripted = true
		r.player.position = r.fragment_pickup.global_position
		await _wait(1.5)


func _ground_cutscenes() -> void:
	_say("12 收工：工具自己砍、翻土 → 動物復原：動物跑過、灌木長回、撲")
	var r = await _open("field")
	world.gs.set_flag("tools_obtained")
	r = await _goto("field", "to_home")
	var p = r.player
	for c in r.get_children():
		if (c.get("kind") == "bush" and c.get("decor") != true) or c.get("kind") == "clod":
			p.attack_weapon = Weapons.Weapon.AXE if c.get("kind") == "bush" else Weapons.Weapon.STICK
			c.hurtbox.receive(4, p, &"melee")
			await get_tree().physics_frame
	await _wait_cutscene()
	await _wait_cutscene()
	_say("12 交換：網子罩住、老鼠開口、放下玉米豆子可可")
	r = world.flow.current
	var rats: Array = r.get_children().filter(func(c): return c.get("kind") == "rat")
	if not rats.is_empty():
		r.player.scripted = true
		r.player.position = Vector2(rats[0].position.x + 200.0, r.player.position.y)
		r.player.intent.move_x = -1.0
		await _wait_cutscene()
		r.player.intent.move_x = 0.0
	_say("12 咬繩：老鼠爬繩、啃咬、繩斷球具落地")
	for f in ["intro_seen", "field_cleared", "night_seen", "rat_caught"]:  # dev_start 會重設旗標（含 intro_seen）
		world.gs.set_flag(f)
	await _goto("home", "to_field")
	await _wait_cutscene()
	_say("12 撿起球具 → 天亮；跟祖母兌換熱湯")
	world.runner._on_interact("pickup:gear")
	await _wait_cutscene()
	r = world.flow.current
	world.gs.add_cacao(40)
	world.shop.open(world.gs)
	await _wait(0.5)
	world.shop.confirm()
	await _wait(1.0)
	world.shop.visible = false
	world.shop.closed.emit()
	get_tree().paused = false


func _forest() -> void:
	var r = await _open("forest_1")
	_say("4 森林 1：交叉淡化到 AMB-01；走近荊棘＝危險嗡聲由小變大再變小")
	await _walk(r, 1900.0, 3300.0, 8.0)
	_say("4 森林 1：爬行型前搖＝可招架前兆；附近有假光造物＝玻璃顫音")
	var e = r.enemies[0] if not r.enemies.is_empty() else null
	if e != null:
		r.player.position.x = e.position.x + 260.0
		await _wait(5.0)
		_say("4 森林 1：打碎＝碎裂（虛假）；全部打完玻璃層消失")
		for x in r.enemies.duplicate():
			if is_instance_valid(x):
				x.kill()
				await _wait(0.8)
	await _wait(3.0)


func _reflector() -> void:
	var r = await _open("forest_5")
	var e = null
	for x in r.enemies:
		if x.has_method("blocks"):
			e = x
	_say("5 森林 5：從遠處走近反光型＝玻璃顫音隨距離變大")
	if e != null:
		await _walk(r, e.position.x - 1400.0, e.position.x - 450.0, 6.0)
		_say("5 森林 5：反光型前搖＝不可招架前兆（配樂與環境音被壓低）；光束")
		await _wait(7.0)
		if is_instance_valid(e):
			_say("5 森林 5：從正面砍反光型＝擋下（鏘）")
			e.stun(0.0)
			r.player.scripted = true
			r.player.set_weapon(Weapons.Weapon.AXE)
			r.player.position.x = e.position.x - 130.0
			r.player.facing = 1
			for i in 2:
				await _tap(r, "attack_pressed")
				await _wait(0.4)
	await _wait(1.0)


func _boss() -> void:
	var r = await _open("boss")
	_say("6 Boss 開場：蹲進草叢、Seven Macaw 吃果子")
	r.intro_seen = false
	r.player.position = Vector2(Nance.ENTRY_X + 60.0, Nance.GROUND_Y)
	await get_tree().physics_frame
	await get_tree().process_frame
	while r.cutscene != null and r.cutscene.running:
		await get_tree().process_frame
	await _wait(1.0)
	r = await _open("boss", 1)
	_say("6a 斷臂：摔落、翅膀猛拍、跌坐")
	r.boss.cycle_enabled = false
	r._on_setup(1)
	await get_tree().process_frame
	while r.cutscene != null and r.cutscene.running:
		await get_tree().process_frame
	await _wait(1.0)
	r = await _open("boss", 2)
	_say("7a 換牙：老夫婦遮擋、玉米牙")
	r.boss.cycle_enabled = false
	r._on_setup(2)
	await get_tree().process_frame
	while r.cutscene != null and r.cutscene.running:
		await get_tree().process_frame
	await _wait(1.0)
	r = await _open("boss", 1)
	r.boss.cycle_enabled = true
	_say("6 Boss 第 1 段：MUS-B01 淡入；振翅、擲果、俯衝、假光閃耀、召喚")
	await _wait(25.0)
	r = await _open("boss", 2)
	r.boss.cycle_enabled = true
	_say("7 Boss 第 2 段：亂揮、撞寶座、反光柱、哀嚎")
	await _wait(25.0)
	r = await _open("boss", 3)
	r.boss.cycle_enabled = true
	_say("8 Boss 第 3 段：光束、失衡撲擊")
	await _wait(18.0)
	_say("9 設局成功 → 死亡（跪下、光熄滅）→ 覺醒 MUS-S01；配樂淡出")
	r.debug_fill_gauge()
	await get_tree().physics_frame
	r._on_setup(3)
	await get_tree().process_frame
	while r.cutscene != null and r.cutscene.running:
		await get_tree().process_frame
	await _wait(3.0)
