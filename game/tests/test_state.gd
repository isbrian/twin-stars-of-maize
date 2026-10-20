extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 2：GameState 與存檔。測試一律用新建的 GameState，不動 autoload 的那份。

const GameStateScr := preload("res://state/game_state.gd")
const Save := preload("res://state/save.gd")
const TEST_SAVE := "user://test_slot.json"


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func test_new_game_defaults() -> void:
	var gs = make_gs()
	check(gs.cacao == 0, "可可豆 0")
	check(gs.equip == [-1, -1], "兩人都沒有武器")
	check(gs.soup == 0, "熱湯 0")
	check(gs.skill_res == 3, "技能資源 3 格")
	check(gs.last_rest == "home", "最後休息地點是祖母家")
	check(gs.hp == gs.tn.max_hp and gs.heal_charges == gs.tn.heal_charges, "血量與治療次數是初始值")
	gs.free()


func test_soup_price_and_cap() -> void:
	var gs = make_gs()
	gs.add_cacao(14)
	check(not gs.can_buy_soup() and not gs.buy_soup(), "14 顆買不起")
	gs.add_cacao(1)
	check(gs.buy_soup() and gs.soup == 1 and gs.cacao == 0, "15 顆買到 1 碗、剩 0")
	gs.add_cacao(100)
	check(gs.buy_soup() and gs.soup == 2, "第 2 碗")
	check(not gs.can_buy_soup() and not gs.buy_soup() and gs.soup == 2 and gs.cacao == 85, "滿 2 碗不能再買、豆子不扣")
	gs.free()


func test_give_weapon_auto_equips_in_order() -> void:
	var gs = make_gs()
	gs.give_weapon(Weapons.Weapon.AXE)
	check(gs.equip == [Weapons.Weapon.AXE, -1], "斧頭給 Hunahpu")
	gs.give_weapon(Weapons.Weapon.STICK)
	check(gs.equip == [Weapons.Weapon.AXE, Weapons.Weapon.STICK], "掘棒給 Xbalanque")
	gs.give_weapon(Weapons.Weapon.BALLGEAR)
	check(gs.equip == [Weapons.Weapon.AXE, Weapons.Weapon.STICK], "兩人都有武器時球具只加入持有")
	check(gs.weapons_owned.has(Weapons.Weapon.BALLGEAR), "球具已持有")
	gs.give_weapon(Weapons.Weapon.AXE)
	check(gs.weapons_owned.count(Weapons.Weapon.AXE) == 1, "重複給不會重複持有")
	gs.free()


func test_equip_swaps_when_taken() -> void:
	var gs = make_gs()
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.give_weapon(Weapons.Weapon.STICK)
	gs.equip_weapon(0, Weapons.Weapon.STICK)
	check(gs.equip == [Weapons.Weapon.STICK, Weapons.Weapon.AXE], "選到對方的武器時兩人互換")
	gs.equip_weapon(0, Weapons.Weapon.BALLGEAR)
	check(gs.equip == [Weapons.Weapon.STICK, Weapons.Weapon.AXE], "沒持有的武器不能裝")
	gs.give_weapon(Weapons.Weapon.BALLGEAR)
	gs.equip_weapon(1, Weapons.Weapon.BALLGEAR)
	check(gs.equip == [Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR], "換成沒人用的武器")
	gs.free()


func test_skill_use_and_recharge() -> void:
	var gs = make_gs()
	check(gs.use_skill(1) and gs.use_skill(1) and gs.use_skill(1), "3 格可用 3 次")
	check(not gs.use_skill(1) and gs.skill_res == 0, "0 格時不能用、不會變負")
	for i in 3:
		gs.on_weapon_hit()
	check(gs.skill_res == 0, "打中 3 次還沒回")
	gs.on_weapon_hit()
	check(gs.skill_res == 1, "打中第 4 次回 1 格")
	for i in 40:
		gs.on_weapon_hit()
	check(gs.skill_res == 3, "回充不超過 3 格")
	gs.free()


func test_give_skill_fills_first_open_slot() -> void:
	var gs = make_gs()
	gs.give_skill("rat")
	check(gs.skills_owned == ["rat"] and gs.skill_slots == ["rat", ""], "老鼠放進第 1 槽")
	gs.give_skill("rat")
	check(gs.skills_owned.size() == 1, "重複給不會重複持有")
	gs.free()


func test_flags() -> void:
	var gs = make_gs()
	check(not gs.has_flag("gear_obtained"), "新遊戲沒有旗標")
	gs.set_flag("gear_obtained")
	check(gs.has_flag("gear_obtained"), "設了就有")
	gs.free()


func test_rest_refills_and_clears_defeated() -> void:
	var gs = make_gs()
	gs.hp = 1
	gs.heal_charges = 0
	gs.skill_res = 0
	gs.defeated["forest_1"] = [0, 1]
	gs.rest("forest_2")
	check(gs.hp == gs.tn.max_hp and gs.heal_charges == gs.tn.heal_charges and gs.skill_res == 3, "回滿")
	check(gs.defeated.is_empty(), "打倒紀錄清空（敵人重生）")
	check(gs.last_rest == "forest_2", "記下休息地點")
	gs.free()


func test_save_roundtrip() -> void:
	var gs = make_gs()
	gs.add_cacao(42)
	gs.give_weapon(Weapons.Weapon.AXE)
	gs.give_skill("rat")
	gs.set_flag("tools_obtained")
	gs.hints_seen["move"] = true
	gs.stashes_taken["forest_3"] = true
	gs.defeated["forest_1"] = [0]
	check(Save.write(gs.to_dict(), TEST_SAVE) == OK, "寫入成功")
	var gs2 = make_gs()
	check(gs2.from_dict(Save.read(TEST_SAVE)), "讀回成功")
	check(gs2.to_dict() == gs.to_dict(), "內容完全一致")
	check(gs2.defeated.is_empty(), "打倒紀錄不存檔")
	check(Save.exists(TEST_SAVE), "存檔存在")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	check(not Save.exists(TEST_SAVE), "刪除後不存在")
	gs.free()
	gs2.free()


func test_corrupt_or_old_save_is_ignored() -> void:
	for content in ["not json", JSON.stringify({"version": 0, "state": {}}), JSON.stringify({"version": 1})]:
		var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		f.store_string(content)
		f.close()
		check(Save.read(TEST_SAVE).is_empty(), "壞掉或版本不符的存檔當成沒有：%s" % content)
		check(not Save.exists(TEST_SAVE), "也不算存在：%s" % content)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var gs = make_gs()
	gs.add_cacao(7)
	check(not gs.from_dict({"cacao": "x"}), "型別不對回傳 false")
	check(gs.cacao == 7, "讀取失敗時狀態不變")
	var d: Dictionary = gs.to_dict()
	d.erase("equip")
	check(not gs.from_dict(d) and gs.cacao == 7, "缺欄位回傳 false、狀態不變")
	gs.free()
