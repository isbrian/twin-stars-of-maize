extends Node
# 開墾田地（MV-SLICE-001a 規格「事件」）：田裡 3 叢灌木（斧頭砍）、3 個土塊（掘棒挖）；全部清掉 → 收工過場＋入夜（MV-SLICE-001c3a）。
# 斧頭、掘棒的拾取由 event_runner 處理（房間的 pickups）。田左半另有幾叢只供收工過場的灌木（decor_bushes，打不到），由過場自己放。

const Prop := preload("res://world/prop.gd")
const FieldDusk := preload("res://world/cutscene/field_dusk.gd")

var runner
var room
var gs
var _left := 0


func _ready() -> void:
	for p in room.data.props:
		if p.kind == "bush" or p.kind == "clod":
			var n := Prop.new()
			n.kind = p.kind
			n.position = p.pos
			room.add_child(n)
			n.cleared.connect(_on_cleared)
			_left += 1


func _on_cleared(_p: Node) -> void:
	_left -= 1
	if _left > 0:
		return
	runner.start_night([FieldDusk.new()])  # 收工的 end_state 設 field_cleared
