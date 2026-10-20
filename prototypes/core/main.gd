extends Node2D
# 核心專案：MV-PROTO-001 戰鬥手感、MV-PROTO-002 換人與武器、MV-PROTO-003 交織式 Boss。
# 規格：todo/spec/MV-PROTO-001_戰鬥手感.md、MV-PROTO-002_換人與武器.md、MV-PROTO-003_交織式Boss.md
# 沒有參數時先顯示開頭選單（練習房／Boss 戰／Boss 段落保留）。使用者參數（放在 -- 之後）：
#   --self-test         執行自動測試後結束（結束碼 0＝全部通過）
#   --boss              略過選單，直接進 Boss 戰
#   --boss-phase <n>    直接從第 n 段開打（1～3；4＝覺醒後的出口），除錯用
#   --tester <代號>      測試日誌檔名用的代號（預設 anon）
#   --demo              展示模式：角色站在敵人旁不動，供錄影截圖檢查前搖訊號
#   --demo-pit          展示模式：角色站在坑邊不動，供錄影截圖檢查平台段
#   --demo-explore      展示模式：角色站在 ③ 台階前，供錄影截圖檢查探索區
#   --demo-parry        展示模式：角色拿球具站在練習對象面前，供錄影截圖檢查前搖與招架
#   --demo-boss-intro   展示模式：Boss 戰開場（下顎微亮）
#   --demo-boss-flash   展示模式：第 1 段假光閃耀與白茫
#   --demo-boss-p3      展示模式：第 3 段（最暗一階）的前搖訊號
# Esc／手把 Start：回開頭選單。

const SelfTest := preload("res://tests/self_test.gd")
const Room := preload("res://level/test_room.gd")
const Hud := preload("res://ui/hud.gd")
const Weapons := preload("res://player/weapons.gd")
const BossFight := preload("res://boss/boss_fight.gd")
const StartMenu := preload("res://ui/start_menu.gd")
const LaunchArgs := preload("res://launch_args.gd")
const Nance := preload("res://boss/nance_arena.gd")
const Palace := preload("res://boss/palace_arena.gd")

var room  # 練習房（沒有時 null）
var fight  # Boss 戰（沒有時 null）
var menu
var current: Node  # 目前模式的根節點
var keep_phase := false  # 開頭選單的「Boss 段落保留」
var opts := {}


func _ready() -> void:
	opts = LaunchArgs.parse(OS.get_cmdline_user_args())
	match opts.mode:
		"selftest":
			var t := SelfTest.new()
			add_child(t)
			await t.run()
			get_tree().quit(0 if t.fail_count == 0 else 1)
		"room":
			start_room(opts.demo)
		"boss":
			start_boss(opts.boss_phase, opts.demo)
		_:
			show_menu()


func _clear() -> void:
	if is_instance_valid(current):
		current.queue_free()
	current = null
	room = null
	fight = null
	menu = null


func show_menu() -> void:
	_clear()
	var layer := CanvasLayer.new()
	add_child(layer)
	current = layer
	menu = StartMenu.new()
	menu.keep_phase = keep_phase
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	menu.chosen.connect(_on_menu_chosen)


func _on_menu_chosen(mode: String, keep: bool) -> void:
	keep_phase = keep
	if mode == "room":
		start_room()
	else:
		start_boss()


func start_room(demo := "") -> void:
	_clear()
	var box := Node2D.new()
	add_child(box)
	current = box
	room = Room.new()
	box.add_child(room)
	var layer := CanvasLayer.new()
	box.add_child(layer)
	var hud := Hud.new()
	hud.player = room.player
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	match demo:
		"--demo":
			room.player.scripted = true
			room.player.position = Vector2(1350, Room.GROUND_Y)
		"--demo-pit":
			room.player.scripted = true
			room.player.position = Room.PIT_RESPAWN
		"--demo-explore":
			room.player.scripted = true
			room.player.position = Vector2(7850, Room.GROUND_Y)
		"--demo-parry":
			room.player.scripted = true
			room.player.position = Vector2(70, Room.GROUND_Y)
			room.player.facing = -1
			room.player.set_weapon(Weapons.Weapon.BALLGEAR)


func start_boss(phase := 0, demo := "") -> void:
	_clear()
	fight = BossFight.new()
	fight.tester = opts.get("tester", "anon")
	fight.keep_phase = keep_phase
	fight.player_scripted = demo != ""
	add_child(fight)
	current = fight
	fight.finished.connect(show_menu)
	var p = fight.player
	match demo:
		"--demo-boss-intro":
			p.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
		"--demo-boss-flash":
			fight.start_at(1, "false_flash")
			p.position = Vector2(Nance.CANOPY.x - 500.0, Nance.GROUND_Y)
			p.facing = 1
		"--demo-boss-p3":
			fight.start_at(3)
			p.position = Vector2(Palace.HOME.x - 600.0, Palace.GROUND_Y)
			p.facing = 1
		_:
			if phase > 0:
				fight.start_at(phase)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back"):
		if menu == null and (fight == null or fight.request_menu()):
			show_menu()
		return
	var p = null
	if room != null:
		p = room.player
		if event.is_action_pressed("debug_reset"):
			room.reset_room()
	elif fight != null:
		p = fight.player
		if event.is_action_pressed("debug_reset"):
			fight.reset_area()
		elif event.is_action_pressed("debug_gauge"):
			fight.debug_fill_gauge()
	if p == null:
		return
	if event.is_action_pressed("debug_save"):
		var err := Tune.save()
		print(Tune.table())
		print("TUNING saved err=%d" % err)
		print(p.parry_stats.report())
		if fight != null:
			print(fight.log.summary_markdown(fight.now()))
	elif event.is_action_pressed("debug_weapon_1"):
		p.set_weapon(Weapons.Weapon.AXE)
	elif event.is_action_pressed("debug_weapon_2"):
		p.set_weapon(Weapons.Weapon.STICK)
	elif event.is_action_pressed("debug_weapon_3"):
		p.set_weapon(Weapons.Weapon.BALLGEAR)
