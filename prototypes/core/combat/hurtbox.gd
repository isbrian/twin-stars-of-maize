extends Area2D
# 受擊判定：只被偵測、不偵測別人。攻擊方呼叫 receive()，擁有者連接 hurt 訊號處理扣血。

signal hurt(amount: int, source: Node, kind: StringName)


## 加入場景前呼叫
func setup(size: Vector2, offset: Vector2, layer_bit: int) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	add_child(cs)
	collision_layer = layer_bit
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive(amount: int, source: Node, kind: StringName) -> void:
	hurt.emit(amount, source, kind)
