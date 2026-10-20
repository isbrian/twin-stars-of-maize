extends "res://tests/base_test.gd"
# MV-SLICE-001a 手把驗收第 1 輪（Brian 2026-10-09）：玩家不知道要先去田地拿工具、荊棘跳得過去。
# 修正：開場旁白文字卡、每一步的目標提示、荊棘擋到頂。

const GameStateScr := preload("res://state/game_state.gd")
const GameWorld := preload("res://world/game_world.gd")
const TEST_SAVE := "user://test_guidance_slot.json"


func make_game_world() -> Node:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.tn.card_min_time = 0.0
	var w = GameWorld.new()
	w.gs = gs
	w.save_path = TEST_SAVE
	w.fade_time = 0.0
	add_child(w)
	return w


func free_world(w) -> void:
	var gs = w.gs
	w.queue_free()
	await frames(2)
	gs.free()
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func settle(w) -> bool:
	return await wait_until(func(): return not w.flow.is_busy() and w.flow.current != null, 60)


func test_new_game_opens_with_field_card_once() -> void:
	var w = make_game_world()
	w.new_game()
	await settle(w)
	var shown: bool = await wait_until(func(): return w.runner.card.visible, 30)
	check(shown and w.runner.card.text.contains("田地") and w.runner.card.text.contains("工具"), "新遊戲先出開場旁白：去田地、工具在田邊")
	w.runner.card.confirm()
	await frames(2)
	check(w.gs.has_flag("intro_seen"), "看過開場旁白記進旗標（會存檔）")
	w.flow.rest_here()
	await settle(w)
	await frames(10)
	check(not w.runner.card.visible, "再回祖母家不重播")
	await free_world(w)


func test_objective_follows_story_flags() -> void:
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var h = Hud.new()
	h.gs = gs
	var steps := [
		["", ["田地", "工具"]],
		["tools_obtained", ["灌木", "斧頭", "土塊", "掘棒"]],
		["field_cleared", ["老鼠", "牆角"]],
		["rat_caught", ["祖母家"]],
		["gear_obtained", ["森林"]],
	]
	for s in steps:
		if s[0] != "":
			gs.set_flag(s[0])
		var line: String = h.objective_line()
		var ok := line.begins_with("目標：")
		for word in s[1]:
			ok = ok and line.contains(word)
		check(ok, "旗標 %s：%s" % [s[0] if s[0] != "" else "（開頭）", line])
	gs.awakened = true
	check(h.objective_line() == "", "覺醒後不再顯示目標")
	h.free()
	gs.free()


func test_thorns_cannot_be_jumped_over() -> void:
	var w = make_game_world()
	w.gs.reset_new_game()
	w.gs.awakened = true  # 連二段跳都要擋得住
	w.flow.start("yard", false)
	await settle(w)
	var p = w.flow.current.player
	p.scripted = true
	var gate: Rect2 = w.flow.current.data.gates[0].rect
	p.position = Vector2(gate.position.x - 200.0, 900.0)
	p.velocity = Vector2.ZERO
	await frames(3)
	p.intent.move_x = 1.0
	p.intent.jump_held = true
	p.intent.jump_pressed = true
	await frames(18)
	p.intent.jump_pressed = true  # 第二跳
	await frames(90)
	check(p.position.x < gate.position.x, "跳到最高（含二段跳）也過不了荊棘（x＝%.0f）" % p.position.x)
	await free_world(w)


## 開場旁白一開遊戲就出現：按鍵提示框不能疊在文字卡底部的「攻擊鍵繼續」上
func test_hints_hidden_while_card_shows() -> void:
	var w = make_game_world()
	w.new_game()
	await settle(w)
	await wait_until(func(): return w.runner.card.visible, 30)
	await frames(2)
	check(not w.hints.visible, "文字卡顯示時不畫按鍵提示")
	w.runner.card.confirm()
	await frames(3)
	check(w.hints.visible and w.hints.current == "move", "文字卡關掉後提示回來")
	await free_world(w)
