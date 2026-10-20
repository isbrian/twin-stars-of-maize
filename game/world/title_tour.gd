extends Node
# 標題畫面展示（MV-SLICE-001d2a，開發版 --title-tour）：配 --write-movie 錄影給 Brian 看。
# 主選單 → 上下移動 → 製作說明（手動捲）→ 返回 → 結束遊戲確認後取消 → 新遊戲 → 直接到結尾 → 片尾自動捲完 → 回主選單 → 結束。

const TitleMenu := preload("res://ui/title_menu.gd")
const GameWorld := preload("res://world/game_world.gd")
const SAVE := "user://title_tour_slot.json"  # 不碰正式存檔

var title
var world
var _back := false


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await _show_title()
	await _wait(3.0)
	for a in [&"look_down", &"look_down", &"look_up"]:
		await _press(a)
	await _wait(0.6)
	title.choose_item("製作說明")
	await _wait(1.0)
	Input.action_press(&"look_down")  # 手動往下捲
	await _wait(4.0)
	Input.action_release(&"look_down")
	await _wait(0.6)
	await _press(&"roll")
	await _wait(0.8)
	title.cursor = TitleMenu.ITEMS.find("結束遊戲")
	title.queue_redraw()
	await _wait(0.6)
	title.choose_item("結束遊戲")  # 第一次：要確認
	await _wait(1.5)
	await _press(&"roll")  # 取消
	await _wait(0.8)
	title.cursor = 0
	title.queue_redraw()
	await _wait(0.6)
	title.get_parent().queue_free()
	world = GameWorld.new()
	world.save_path = SAVE
	add_child(world)
	world.quit_to_title.connect(func(): _back = true)
	world.dev_start("exit")  # 直接到結尾
	await _wait(3.0)
	var room = world.flow.current
	if room != null and room.get("card") != null:
		room.card.min_time = 0.0
		room.card.confirm()
	while not _back:  # 片尾自動捲完會回主選單
		await get_tree().process_frame
	world.queue_free()
	await world.tree_exited  # 等遊戲世界離開再顯示標題（同 main.gd：不然環境音被它的 _exit_tree 關掉）
	await _show_title()
	await _wait(3.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


func _show_title() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = TitleMenu.new()
	title.save_path = SAVE
	layer.add_child(title)
	await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## 在一幀的開頭按一下（同 sound_tour）
func _press(action: StringName) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await _wait(0.6)
