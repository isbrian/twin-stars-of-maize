extends "res://tests/base_test.gd"
# MV-SLICE-001a Task 9：按鍵提示（規格 SLICE-a7）。

const GameStateScr := preload("res://state/game_state.gd")
const Hints := preload("res://ui/hints.gd")


func make_hints():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	var h = Hints.new()
	h.gs = gs
	return h


func test_hint_shows_once() -> void:
	var h = make_hints()
	h.request("move")
	check(h.current == "move", "第一次需要時出現")
	h.satisfy("move")
	check(h.current == "" and h.gs.hints_seen.get("move", false), "做到就消失並記下")
	h.request("move")
	check(h.current == "", "看過的不再出現")
	h.gs.free()
	h.free()


func test_hint_queue_one_at_a_time() -> void:
	var h = make_hints()
	h.request("move")
	h.request("jump")
	h.request("move")
	check(h.current == "move", "同時只顯示一個")
	h.satisfy("jump")
	check(h.current == "move" and h.gs.hints_seen.get("jump", false), "排隊中的先做到也算看過")
	h.satisfy("move")
	check(h.current == "", "jump 已經做到，不再出現")
	h.request("dart")
	h.request("attack")
	h.satisfy("dart")
	check(h.current == "attack", "下一個接著出現")
	h.gs.free()
	h.free()


func test_hint_text_follows_device() -> void:
	var h = make_hints()
	var was: bool = InputSetup._last_pad
	InputSetup._last_pad = false
	check(h.text_for("jump") == "Space 跳躍", "鍵盤：%s" % h.text_for("jump"))
	check(h.text_for("skill") == "Q 老鼠鑽地突襲", "鍵盤：%s" % h.text_for("skill"))
	InputSetup._last_pad = true
	check(h.text_for("jump") == "A 跳躍", "手把：%s" % h.text_for("jump"))
	check(h.text_for("interact") == "十字鍵下 互動", "手把：%s" % h.text_for("interact"))
	InputSetup._last_pad = was
	for id in ["move", "jump", "dart", "attack", "swap", "interact", "equip", "skill", "heal"]:
		check(h.text_for(id) != "", "提示 %s 有文字" % id)
	h.gs.free()
	h.free()


func test_hints_seen_saved() -> void:
	var h = make_hints()
	h.request("heal")
	h.satisfy("heal")
	check(h.gs.to_dict().hints_seen.get("heal", false), "看過的提示進存檔")
	h.gs.free()
	h.free()
