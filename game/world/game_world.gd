extends Node2D
# 遊戲本體（MV-SLICE-001a Task 12）：房間流程、事件、HUD、按鍵提示、暫停選單（裝備頁）、祖母的兌換。
# 主選單選「新遊戲」或「繼續」後由 main.gd 建立；回主選單時整個釋放。

const RoomFlow := preload("res://world/room_flow.gd")
const EventRunner := preload("res://events/event_runner.gd")
const Index := preload("res://world/rooms/index.gd")
const Save := preload("res://state/save.gd")
const Loadout := preload("res://state/loadout.gd")
const Weapons := preload("res://core/player/weapons.gd")
const Hud := preload("res://ui/hud.gd")
const Hints := preload("res://ui/hints.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const Shop := preload("res://ui/shop.gd")

const DEV_GROUND_ROOMS := ["home", "field"]  # --room 進這些房間時不給武器
const STORY_FLAGS := ["tools_obtained", "field_cleared", "night_seen", "rat_caught", "gear_dropped", "gear_obtained"]

const MENU_LAYER := 60  # 在地面事件的文字卡（40）與換房淡出（50）之上

signal quit_to_title

var gs  # state/game_state.gd；null 時用 autoload GameState
var save_path := Save.PATH
var fade_time := 0.25
var debug_keys := OS.is_debug_build()  # F9～F11、數字鍵 1～3（規格「除錯功能」）
var flow
var runner
var hud
var hints
var pause_menu
var shop


func _ready() -> void:
	if gs == null:
		gs = GameState
	flow = RoomFlow.new()
	flow.gs = gs
	flow.tn = gs.tn
	flow.rooms = Index.ROOMS
	flow.fade_time = fade_time
	flow.save_path = save_path
	add_child(flow)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	hud = Hud.new()
	hud.show_hint = false
	hud.gs = gs
	hints = Hints.new()
	hints.gs = gs
	pause_menu = PauseMenu.new()
	pause_menu.gs = gs
	shop = Shop.new()
	shop.visible = false
	shop.process_mode = Node.PROCESS_MODE_ALWAYS
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = MENU_LAYER
	add_child(menu_layer)
	for c in [hud, hints, pause_menu, shop]:  # 暫停選單排在兌換前面處理（見 pause_menu._process）
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		(menu_layer if c == pause_menu or c == shop else layer).add_child(c)
	runner = EventRunner.new()
	runner.flow = flow
	runner.gs = gs
	runner.hints = hints
	runner.hud = hud
	add_child(runner)
	flow.room_changed.connect(_on_room)
	flow.ended.connect(_to_title)
	pause_menu.quit_to_title.connect(_to_title)
	pause_menu.equip_opened.connect(hints.satisfy.bind("equip"))
	pause_menu.equip.closed.connect(_reapply_weapons)
	shop.closed.connect(func(): get_tree().paused = false)


func new_game() -> void:
	gs.reset_new_game()
	Save.write(gs.to_dict(), save_path)  # 主選單已確認過會蓋掉舊存檔
	flow.start("home", false)
	for h in ["move", "jump", "dart"]:
		hints.request(h)


## 讀存檔、從最後休息的地方繼續；讀不到時回傳 false
func continue_game() -> bool:
	var d := Save.read(save_path)
	if d.is_empty() or not gs.from_dict(d):
		return false
	gs.defeated = {}
	flow.start(gs.last_rest, false)
	return true


## 開發參數 --room／--boss：新遊戲後直接進該房間；地面開頭以外的房間先給齊武器、老鼠與劇情旗標
func dev_start(room: String, boss_phase := 0) -> void:
	gs.reset_new_game()
	if not DEV_GROUND_ROOMS.has(room):
		for w in [Weapons.Weapon.AXE, Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
			gs.give_weapon(w)
		gs.give_skill("rat")
		for f in STORY_FLAGS:
			gs.set_flag(f)
	flow.start(room, false)
	if boss_phase > 0 and room == "boss":
		while flow.is_busy() or flow.current_id != "boss":
			await get_tree().process_frame
		flow.current.start_at(boss_phase)


func _on_room(_id: String) -> void:
	var r = flow.current
	var p = r.get("player")
	hud.visible = r.get("pickups") != null  # Boss 段落有自己的 HUD
	hints.visible = p != null
	if p == null:
		return
	hud.player = p
	p.swung.connect(hints.satisfy.bind("attack"))
	p.dart_fired.connect(hints.satisfy.bind("dart"))
	p.swapped.connect(hints.satisfy.bind("swap"))
	p.healed.connect(hints.satisfy.bind("heal"))
	p.interacted.connect(hints.satisfy.bind("interact"))
	p.hurt_taken.connect(hints.request.bind("heal"))
	var su = p.get_node_or_null("SkillUser")
	if su != null:
		su.used.connect(func(_slot): hints.satisfy("skill"))
		var target_hud = r.get("hud") if r.get("hud") != null else hud
		su.denied.connect(target_hud.flash_skill)
	if r.has_signal("interacted"):
		r.interacted.connect(_on_interacted)


func _on_interacted(kind: String) -> void:
	if kind == "npc":
		shop.open(gs)
		get_tree().paused = true


## 裝備頁關掉後把新的裝備套到角色（Boss 段落要再疊斷臂規則）
func _reapply_weapons() -> void:
	var r = flow.current
	if r == null or r.get("player") == null:
		return
	if r.has_method("begin_at_rest"):
		r._apply_loadout()
	else:
		Loadout.apply_weapons(r.player, gs)


func _process(_delta: float) -> void:
	var r = flow.current
	hints.visible = r != null and r.get("player") != null and not runner.card.visible and not runner.cutscene_running()  # 不疊在文字卡的「攻擊鍵繼續」上，地面過場中也不顯示（c3a）
	if r == null or flow.is_busy():
		return
	var p = r.get("player")
	if p == null or p.intent == null:
		return
	if p.intent.move_x != 0.0:
		hints.satisfy("move")
	if p.velocity.y < 0.0 and not p.is_on_floor():
		hints.satisfy("jump")
	if r.has_method("interact_target") and r.interact_target() != "":
		hints.request("interact")


const DEBUG_ACTIONS: Array[StringName] = [&"debug_save", &"debug_reset", &"debug_gauge", &"debug_weapon_1", &"debug_weapon_2", &"debug_weapon_3"]


func _unhandled_input(event: InputEvent) -> void:
	if not debug_keys:
		return
	for a in DEBUG_ACTIONS:
		if event.is_action_pressed(a):
			debug_action(a)
			get_viewport().set_input_as_handled()
			return


## 除錯鍵（照原型 main.gd）：F9 存回數值並印出數值表、招架紀錄、Boss 日誌摘要；F10 重來目前的房間或 Boss 場地；
## F11 Boss 破綻加滿；1～3 換武器
func debug_action(action: StringName) -> void:
	var r = flow.current
	if not debug_keys or r == null or flow.is_busy() or r.get("player") == null:
		return
	var p = r.player
	var boss: bool = r.has_method("begin_at_rest")
	match action:
		&"debug_save":
			print("TUNING saved err=%d" % Tune.save())
			print(Tune.table())
			print(p.parry_stats.report())
			if boss:
				print(r.log.summary_markdown(r.now()))
		&"debug_reset":
			if boss:
				r.reset_area()
			else:
				flow.start(flow.current_id)
		&"debug_gauge":
			if boss:
				r.debug_fill_gauge()
		&"debug_weapon_1":
			p.set_weapon(Weapons.Weapon.AXE)
		&"debug_weapon_2":
			p.set_weapon(Weapons.Weapon.STICK)
		&"debug_weapon_3":
			p.set_weapon(Weapons.Weapon.BALLGEAR)


func _exit_tree() -> void:
	Audio.stop_all()  # 回主選單、讀檔重建：環境音與配樂不殘留（MV-SLICE-001d1a）


func _to_title() -> void:
	get_tree().paused = false
	quit_to_title.emit()
