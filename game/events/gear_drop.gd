extends Node
# 球具掉下（MV-SLICE-001a 規格「事件」；MV-SLICE-001c3a 改成過場）：抓到老鼠後回祖母家（夜晚、祖母睡著）→ 咬繩的過場 →
# 球具在地上可撿（gear_dropped：沒撿就離開，再回來不重播、球具還在）→ 撿起（event_runner 給球具與老鼠技能）→ 天亮的過場 → gear_obtained。

const GearRope := preload("res://world/cutscene/gear_rope.gd")
const Morning := preload("res://world/cutscene/morning.gd")

var runner
var room
var gs


var _picked := false


func _ready() -> void:
	runner.gear_picked.connect(func(): _picked = true, CONNECT_ONE_SHOT)  # 先接：咬繩的黑邊還在收時就能撿（MV-SLICE-001c3b）
	if gs.has_flag("gear_dropped"):  # 之前掉下沒撿：球具還在地上
		room.add_pickup("gear", "gear", Vector2(GearRope.rope_at(room).x, room.data.ground_y))
	else:
		await runner.play([GearRope.new()])  # end_state 放出可撿的球具
		if not is_inside_tree():
			return
	if not _picked:
		await runner.gear_picked
	if is_inside_tree():
		await runner.play([Morning.new()])
