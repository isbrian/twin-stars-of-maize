extends Node
# 地面事件的排程（MV-SLICE-001a 規格「事件」、Task 10）：每次換房依旗標掛上事件；事件節點掛在房間下，換房時一起釋放。
# 也負責撿工具與球具、文字卡（旁白；顯示時鎖住角色）與相關的按鍵提示。

const TextCard := preload("res://ui/text_card.gd")
const Intent := preload("res://core/player/intent.gd")
const Loadout := preload("res://state/loadout.gd")
const Weapons := preload("res://core/player/weapons.gd")
const FieldClearing := preload("res://events/field_clearing.gd")
const NightRat := preload("res://events/night_rat.gd")
const GearDrop := preload("res://events/gear_drop.gd")
const Cutscene := preload("res://world/cutscene/cutscene.gd")
const GroundStage := preload("res://world/cutscene/ground_stage.gd")

const NIGHT_GREY := Color(0.45, 0.5, 0.75)  # 灰盒房間的夜晚（同 MV-SLICE-001a）

## 開場旁白（手把驗收第 1 輪：玩家不知道要先去田地拿工具；Brian 2026-10-09）
const TEXT_INTRO := "祖母要兄弟倆去開墾屋子左邊的田地。工具就放在田邊。"

signal gear_picked

var flow
var gs
var hints  # ui/hints.gd；null 時不出提示
var hud  # ui/hud.gd：過場時淡出（game_world 設；測試可為 null）
var cutscene  # 目前房間的過場節點（MV-SLICE-001c3a；沒有時 null）
var card: Control
var _prev_scripted := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	card = TextCard.new()
	card.min_time = gs.tn.card_min_time
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(card)
	flow.room_changed.connect(_on_room)


func _on_room(id: String) -> void:
	var r = flow.current
	if r.get("pickups") == null:  # Boss 段落、結尾不是一般房間
		return
	r.interacted.connect(_on_interact)
	if hints != null:  # 房間的提示區、下劈彈起（MV-SLICE-001c4a）
		r.hint_requested.connect(hints.request_now)
		r.player.pogo_bounced.connect(hints.satisfy.bind("pogo"))
	if hints != null and not r.pickups.is_empty():
		hints.request("interact")
	apply_night(r)
	if id == "field":
		if not gs.has_flag("field_cleared"):
			_attach(FieldClearing.new())
		elif not gs.has_flag("rat_caught"):
			_attach(NightRat.new())
	elif id == "home":
		r.npc_asleep = gs.has_flag("rat_caught") and not gs.has_flag("gear_obtained")
		if not gs.has_flag("intro_seen"):
			_intro()
		elif gs.has_flag("rat_caught") and not gs.has_flag("gear_obtained"):
			_attach(GearDrop.new())


func _intro() -> void:
	await show_card(TEXT_INTRO)
	gs.set_flag("intro_seen")


func _attach(e: Node) -> void:
	e.runner = self
	e.room = flow.current
	e.gs = gs
	flow.current.add_child(e)


## 在目前房間播過場（MV-SLICE-001c3a）：過場節點掛在房間下（換房時一起釋放），房間凍結時照常跑
func play(scenes: Array) -> void:
	# 進房間就播的過場（咬繩、再進田地的動物復原）：先跑一個物理幀再凍結房間，
	# 否則角色的物理體還沒進物理空間就被停用，引擎印 body->get_space() is null（Brian 試玩紀錄）
	await get_tree().physics_frame
	var r = flow.current
	if cutscene == null or not is_instance_valid(cutscene) or cutscene.get_parent() != r:
		cutscene = Cutscene.new()
		cutscene.name = "Cutscene"
		cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
		r.add_child(cutscene)
	cutscene.host = GroundStage.of(r, self)
	await cutscene.run(scenes)


func cutscene_running() -> bool:
	return cutscene != null and is_instance_valid(cutscene) and cutscene.running


## 田地清完後換成入夜事件；prelude＝接在動物復原前面一起播的段落（收工；MV-SLICE-001c3a）
func start_night(prelude: Array = []) -> void:
	if flow.current != null and flow.current.data.id == "field":
		var e := NightRat.new()
		e.prelude = prelude
		_attach(e)


## 夜晚（MV-SLICE-001c3a，SLICE-c3-10）：田地從清完到拿到球具前、祖母家從抓到老鼠到拿到球具前；
## 只調場景圖層（角色與戰鬥訊號保持原色），沒有場景的灰盒房間調整個房間
func apply_night(room) -> void:
	var id: String = room.data.id
	var on: bool = not gs.has_flag("gear_obtained") and ((id == "field" and gs.has_flag("field_cleared")) or (id == "home" and gs.has_flag("rat_caught")))
	if room.scenery != null:
		room.scenery.night = on
	else:
		room.modulate = NIGHT_GREY if on else Color.WHITE


## 顯示文字卡、鎖住角色，按掉後解鎖（回傳時卡已關閉）
func show_card(text: String) -> void:
	var p = flow.current.player
	_prev_scripted = p.scripted
	p.scripted = true
	p.intent = Intent.new()
	card.show_card(text)
	await card.closed
	if is_instance_valid(p):
		p.scripted = _prev_scripted


func _on_interact(kind: String) -> void:
	if not kind.begins_with("pickup:"):
		return
	var id := kind.substr(7)
	var r = flow.current
	Loadout.store(r.player, gs)
	match id:
		"axe", "stick":
			gs.give_weapon(Weapons.Weapon.AXE if id == "axe" else Weapons.Weapon.STICK)
			if gs.weapons_owned.has(Weapons.Weapon.AXE) and gs.weapons_owned.has(Weapons.Weapon.STICK):
				gs.set_flag("tools_obtained")
				if hints != null:
					hints.request("attack")
					hints.request("swap")
		"gear":
			gs.give_weapon(Weapons.Weapon.BALLGEAR)
			gs.give_skill("rat")
			if hints != null:
				hints.request("equip")
				hints.request("skill")
	if hints != null:
		hints.satisfy("interact")
	Audio.play(&"pick_item")  # 撿起工具或球具（MV-SLICE-001d1b）
	r.remove_pickup(id)
	Loadout.apply(r.player, gs)
	if id == "gear":
		gear_picked.emit()
