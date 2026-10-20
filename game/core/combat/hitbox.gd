extends Area2D
# 攻擊判定：啟用期間由擁有者每個物理幀呼叫 collect()，掃描重疊的受擊判定；
# 每次 start() 後每個目標只回傳一次。重疊清單在物理步進後才更新，
# 所以 configure() 要在判定開始前至少 2 個物理幀呼叫（出招期間）。

const Hurtbox := preload("res://core/combat/hurtbox.gd")

var shape := CollisionShape2D.new()
var rect := RectangleShape2D.new()
var active := false
var _already: Array = []


func _init() -> void:
	shape.shape = rect
	add_child(shape)
	monitorable = false


func configure(size: Vector2, offset: Vector2, mask: int) -> void:
	rect.size = size
	shape.position = offset
	collision_layer = 0
	collision_mask = mask


func start() -> void:
	active = true
	_already.clear()


func stop() -> void:
	active = false


func collect() -> Array:
	var hits := []
	if not active:
		return hits
	for a in get_overlapping_areas():
		if a is Hurtbox and not _already.has(a):
			_already.append(a)
			hits.append(a)
	return hits
