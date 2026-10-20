extends RefCounted
# 選單輸入（MV-SLICE-001a 最終審查）：選單每幀輪詢 Input.is_action_just_pressed——搖桿推一次只算一次
# （_unhandled_input 會把每個越過死區的搖桿事件都當成按下），滑鼠左鍵（攻擊）也不會被全螢幕的 Control 吃掉。
# 開關選單時呼叫 swallow()：這一幀（process 與 physics 各一）選單、文字卡、角色都不讀「按下」，
# 同一下按鍵就不會穿透到下一個選單、文字卡或角色身上。
# 不用 Input.action_release：Godot 4 預設（legacy_just_pressed_behavior 關）放開後同一幀 just_pressed 仍是 true。

const Intent := preload("res://core/player/intent.gd")

static var _muted_process_frame := -1


static func just(action: StringName) -> bool:
	return Engine.get_process_frames() != _muted_process_frame and Input.is_action_just_pressed(action)


static func swallow() -> void:
	_muted_process_frame = Engine.get_process_frames()
	# 在 process 裡呼叫時，下一個物理幀的編號是 +1（按鍵的 just_pressed 也記在那一幀）
	Intent.muted_physics_frame = Engine.get_physics_frames() + (0 if Engine.is_in_physics_frame() else 1)
