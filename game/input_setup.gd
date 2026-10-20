extends Node
# 方案 A 按鍵（討論紀錄 E6），用程式登記；單獨執行任何場景時也有效。
# MV-PROTO-002 加換人（Y／Tab）與除錯鍵 1／2／3（改目前場上的人的武器）。
# MV-SLICE-001a：Esc／Start 改為暫停（pause），新增動物技能槽 1／2（十字鍵左右、Q／F）與互動（十字鍵下、E）。
# 同時記錄最後使用的裝置：滑鼠或鍵盤 → 吹箭朝游標；手把 → 右搖桿、左搖桿 8 方向或面向。

var _last_pad := false


func _ready() -> void:
	_keys("move_left", [KEY_A, KEY_LEFT])
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_keys("look_up", [KEY_W, KEY_UP])
	_pad_axis("look_up", JOY_AXIS_LEFT_Y, -1.0)
	_keys("look_down", [KEY_S, KEY_DOWN])
	_pad_axis("look_down", JOY_AXIS_LEFT_Y, 1.0)
	_keys("jump", [KEY_SPACE])
	_pad_button("jump", JOY_BUTTON_A)
	_keys("roll", [KEY_SHIFT])
	_pad_button("roll", JOY_BUTTON_B)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_pad_button("attack", JOY_BUTTON_X)
	_mouse("dart", MOUSE_BUTTON_RIGHT)
	_pad_axis("dart", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_keys("heal", [KEY_R])
	_pad_button("heal", JOY_BUTTON_DPAD_UP)
	_pad_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_keys("swap", [KEY_TAB])
	_pad_button("swap", JOY_BUTTON_Y)
	_keys("debug_save", [KEY_F9])
	_keys("debug_weapon_1", [KEY_1])
	_keys("debug_weapon_2", [KEY_2])
	_keys("debug_weapon_3", [KEY_3])
	_keys("debug_reset", [KEY_F10])
	_keys("debug_gauge", [KEY_F11])  # MV-PROTO-003：Boss 破綻直接加滿
	_keys("pause", [KEY_ESCAPE])
	_pad_button("pause", JOY_BUTTON_START)
	# MV-SLICE-001a：動物技能兩槽、互動
	_keys("skill_1", [KEY_Q])
	_pad_button("skill_1", JOY_BUTTON_DPAD_LEFT)
	_keys("skill_2", [KEY_F])
	_pad_button("skill_2", JOY_BUTTON_DPAD_RIGHT)
	_keys("interact", [KEY_E])
	_pad_button("interact", JOY_BUTTON_DPAD_DOWN)


func uses_mouse() -> bool:
	return not _last_pad


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_last_pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_last_pad = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey:
		_last_pad = false


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)  # 搖桿死區


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _pad_button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
