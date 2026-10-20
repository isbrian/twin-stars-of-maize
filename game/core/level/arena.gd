extends Node
# 關門戰（MV-SLICE-001c4a）：玩家整個進到 rect 才觸發 → 兩側升起荊棘牆 → 依序 3 波敵人（一波清完 1 秒後下一波）
# → 牆收回、出現獎勵碎片。狀態不存檔：死亡、離開房間、讀檔都會重建房間，自然重置；獎勵拿過時房間不建它。

signal started
signal cleared

const NEXT_WAVE := 1.0
const BODY_HALF := 30.0  # 玩家碰撞框半寬（整個進到 rect 才算）

var room  # world/room.gd
var data: Dictionary  # {rect, gates, waves, reward}
var wave := -1  # -1＝未開始；waves.size()＝已清完
var _alive: Array = []
var _gates: Array = []
var _wait := -1.0


func _physics_process(delta: float) -> void:
	if wave == -1:
		var p: Vector2 = room.player.position
		var r: Rect2 = data.rect
		if p.x - BODY_HALF >= r.position.x and p.x + BODY_HALF <= r.end.x and p.y > r.position.y and p.y <= r.end.y:
			_start()
	elif _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			_next()


func _start() -> void:
	for g in data.gates:
		_gates.append(room.add_gate(g))
	started.emit()
	wave = 0
	_spawn()


func _spawn() -> void:
	for e in data.waves[wave]:
		var n = room.spawn_enemy(e)
		_alive.append(n)
		n.died.connect(_on_died)


func _on_died(e: Node) -> void:
	_alive.erase(e)
	if _alive.is_empty():
		_wait = NEXT_WAVE


func _next() -> void:
	wave += 1
	if wave < data.waves.size():
		_spawn()
		return
	for g in _gates:
		room.remove_gate(g)
	_gates.clear()
	room.place_fragment(data.reward)
	cleared.emit()
