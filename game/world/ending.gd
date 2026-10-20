extends Node
# 切片結尾（規格房間 #13）：結束畫面「謝謝試玩」→ 自動捲動的製作說明（含 AI 揭露；MV-SLICE-001d2a）→ done（room_flow 轉成 ended → 回主選單）。

const TextCard := preload("res://ui/text_card.gd")
const Credits := preload("res://ui/credits.gd")
const TitleMenu := preload("res://ui/title_menu.gd")

const TEXT := "垂直切片到此結束，謝謝試玩。"

signal done

var tn
var card
var credits


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	card = TextCard.new()
	card.min_time = tn.card_min_time
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(card)
	card.show_card(TEXT)
	await card.closed
	credits = Credits.new()
	credits.mode = "auto"
	credits.title = TitleMenu.display_title()
	layer.add_child(credits)
	await credits.closed
	done.emit()
