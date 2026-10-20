extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 7：暫停選單、裝備頁、祖母兌換。

const GameStateScr := preload("res://state/game_state.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const EquipPage := preload("res://ui/equip_page.gd")
const Shop := preload("res://ui/shop.gd")


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func test_equip_page_lists_owned_only() -> void:
	var gs = make_gs()
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.give_weapon(Weapons.Weapon.STICK)
	var page = EquipPage.new()
	page.open(gs)
	check(page.options() == [Weapons.Weapon.AXE, Weapons.Weapon.STICK], "選項只有持有的武器")
	check(page.label_for(0) == "斧頭" and page.label_for(1) == "掘棒", "兩欄顯示各自的武器")
	page.choose(0, Weapons.Weapon.STICK)
	check(gs.equip == [Weapons.Weapon.STICK, Weapons.Weapon.AXE], "選到對方的武器時互換")
	page.free()
	gs.free()


func test_equip_page_no_weapons_shows_dash_and_no_duplicate() -> void:
	var gs = make_gs()
	var page = EquipPage.new()
	page.open(gs)
	check(page.options().is_empty() and page.label_for(0) == "—" and page.label_for(1) == "—", "沒有武器時兩欄都是「—」")
	gs.give_weapon(Weapons.Weapon.AXE)
	page.choose(1, Weapons.Weapon.AXE)
	check(gs.equip == [-1, Weapons.Weapon.AXE], "只有 1 把時給另一人＝互換，原本的人變「—」")
	check(page.label_for(0) == "—" and page.label_for(1) == "斧頭", "不會兩人拿同一把")
	page.free()
	gs.free()


func test_slot2_locked() -> void:
	var gs = make_gs()
	gs.give_skill("rat")
	var page = EquipPage.new()
	page.open(gs)
	check(page.slot_labels() == ["老鼠", "（鎖住）"], "第 1 槽老鼠、第 2 槽鎖住，實際 %s" % [page.slot_labels()])
	page.free()
	gs.free()


func test_pause_freezes_world() -> void:
	var w := make_world()
	var p = await make_player(w)
	var menu = PauseMenu.new()
	add_child(menu)
	menu.open()
	check(get_tree().paused and menu.visible, "暫停選單開啟時遊戲停止")
	var x: float = p.position.x
	p.intent.move_x = 1.0
	await frames(5)
	check(p.position.x == x, "暫停中角色不動")
	check(menu.items() == ["裝備", "回主選單", "回到遊戲"], "選單項目")
	menu.close()
	check(not get_tree().paused and not menu.visible, "關閉後恢復")
	await frames(5)
	check(p.position.x > x, "恢復後角色會動")
	menu.free()
	await free_world(w)


func test_pause_quit_to_title_signal() -> void:
	var menu = PauseMenu.new()
	add_child(menu)
	var got := [false]
	menu.quit_to_title.connect(func(): got[0] = true)
	menu.open()
	menu.choose_item("回主選單")
	check(got[0] and not get_tree().paused, "選「回主選單」發出訊號並解除暫停")
	menu.free()


func test_shop_disables_when_poor_or_full() -> void:
	var gs = make_gs()
	var shop = Shop.new()
	shop.open(gs)
	check(shop.item_label() == "熱湯（15 顆）", "品項與價格")
	check(not shop.can_confirm(), "豆子不足時不可選")
	gs.add_cacao(40)
	check(shop.can_confirm() and shop.confirm() and gs.soup == 1, "買到 1 碗")
	check(shop.confirm() and gs.soup == 2 and gs.cacao == 10, "第 2 碗")
	check(not shop.can_confirm() and not shop.confirm() and gs.soup == 2, "滿 2 碗不可選")
	shop.free()
	gs.free()
