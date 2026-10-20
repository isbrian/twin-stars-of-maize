extends Node2D
# 測試房間（MV-PROTO-001 規格書第 6 節）：左邊戰鬥房（爬行型 ×2、飛行型 ×1、兩個高台），
# 右邊平台段（坑上方 3 個彈跳物）。掉坑扣血回坑邊；血量歸零整個房間重置。
# MV-PROTO-002 規格書第 7 節：起點左側的招架練習對象；平台段右邊接探索區
# ① 二段跳高台 → ② 坑中央的懸空木障 → ③ 台階＋木障 → 小戰鬥房。探索區不放文字提示。
# ponytail: yagni: 地形用矩形資料建立 | upgrade if: 正式素材進來，改用 TileMapLayer

const Tuning := preload("res://tuning/combat_tuning.gd")
const L := preload("res://combat/layers.gd")
const Player := preload("res://player/player.gd")
const Crawler := preload("res://enemies/crawler.gd")
const Flyer := preload("res://enemies/flyer.gd")
const PogoCrystal := preload("res://level/pogo_crystal.gd")
const Dart := preload("res://player/dart.gd")
const Feedback := preload("res://fx/feedback.gd")
const Shatter := preload("res://fx/shatter.gd")
const Barrier := preload("res://level/barrier.gd")
const ParryDummy := preload("res://enemies/parry_dummy.gd")

const GROUND_Y := 900.0
const PIT_LEFT := 2900.0
# 坑與彈跳物的間距由 --self-test 的平台段機器人驗證：依序彈 3 顆才過得去，跳過任何一顆都不行
const PIT_WIDTH := 1600.0
const CRYSTAL_OFFSETS := [300.0, 800.0, 1300.0]  # 從坑左緣算起（下落變慢後單跳變遠，間距 400 → 500）
const RIGHT_EDGE := 10000.0
const START := Vector2(300, GROUND_Y)
const PIT_RESPAWN := Vector2(PIT_LEFT - 150.0, GROUND_Y)
# 探索區（依初始數值：單跳高 400、二段跳約 700、單跳水平約 820（下落倍率 0.6）、角色高 180）
const LEDGE1 := Rect2(5600, GROUND_Y - 550, 800, 950)  # ① 高 550：單跳搆不到、二段跳有餘裕
const PIT2_LEFT := 7000.0
const PIT2_WIDTH := 600.0  # ② 單跳跨得過
const PIT2_RESPAWN := Vector2(PIT2_LEFT - 150.0, GROUND_Y)
const LEDGE3 := Rect2(8000, GROUND_Y - 550, 800, 950)  # ③ 高 550
const CEILING := Rect2(6800, GROUND_Y - 1050, 2200, 100)  # ②③ 的天花板，下緣在地面上方 950 px
const BARRIERS := [
	Rect2(7270, GROUND_Y - 950, 60, 950),  # ② 坑中央，從天花板垂到地面高度
	Rect2(8160, GROUND_Y - 950, 60, 400),  # ③ 台階頂端往內 160 px（Hunahpu 的落腳處）
]
const DUMMY := Vector2(-80, GROUND_Y)  # 起點左側、緊鄰左牆（計畫 D3）
const SOLIDS := [
	Rect2(-200, GROUND_Y, PIT_LEFT + 200, 400),  # 戰鬥房與坑前地面
	Rect2(PIT_LEFT + PIT_WIDTH, GROUND_Y, PIT2_LEFT - PIT_LEFT - PIT_WIDTH, 400),  # 對岸到 ② 坑緣
	Rect2(PIT2_LEFT + PIT2_WIDTH, GROUND_Y, RIGHT_EDGE - PIT2_LEFT - PIT2_WIDTH, 400),  # ② 對岸到小戰鬥房
	LEDGE1,
	LEDGE3,
	CEILING,
	Rect2(-300, -600, 100, 1900),  # 左牆
	Rect2(RIGHT_EDGE, -600, 100, 1900),  # 右牆
]
# 高台是單向平台：從下方可以跳穿、站上去。爬行型在高台下方巡邏，實心高台會讓那裡跳不起來
const PLATFORMS := [
	Rect2(900, GROUND_Y - 260, 360, 30),  # 高台 1
	Rect2(1700, GROUND_Y - 260, 360, 30),  # 高台 2
]
const CRYSTALS := [
	Vector2(PIT_LEFT + CRYSTAL_OFFSETS[0], GROUND_Y - 120),
	Vector2(PIT_LEFT + CRYSTAL_OFFSETS[1], GROUND_Y - 120),
	Vector2(PIT_LEFT + CRYSTAL_OFFSETS[2], GROUND_Y - 120),
]
const CRAWLERS := [Vector2(1100, GROUND_Y), Vector2(2000, GROUND_Y), Vector2(9400, GROUND_Y)]
const FLYERS := [Vector2(1500, GROUND_Y - 450), Vector2(9600, GROUND_Y - 450)]

var tn: Tuning = Tune.data
var player
var enemies: Array = []
var barriers: Array = []
var dummy
var camera: Camera2D
var feedback


func _ready() -> void:
	for r in SOLIDS:
		_add_solid(r)
	for r in PLATFORMS:
		_add_solid(r, true)
	for at in CRYSTALS:
		var c := PogoCrystal.new()
		c.position = at
		add_child(c)
	_add_pit(PIT_LEFT, PIT_WIDTH, PIT_RESPAWN)
	_add_pit(PIT2_LEFT, PIT2_WIDTH, PIT2_RESPAWN)
	player = Player.new()
	player.tn = tn
	player.position = START
	add_child(player)
	player.died.connect(reset_room, CONNECT_DEFERRED)
	camera = Camera2D.new()
	camera.position = Vector2(0, -150)
	camera.position_smoothing_enabled = true
	camera.limit_left = -200
	camera.limit_right = int(RIGHT_EDGE)
	camera.limit_top = -400
	camera.limit_bottom = int(GROUND_Y + 400.0)
	player.add_child(camera)
	feedback = Feedback.new()
	feedback.tn = tn
	feedback.camera = camera
	add_child(feedback)
	player.swung.connect(_on_player_swung)
	player.hit_landed.connect(_on_player_hit)
	player.dart_fired.connect(_on_player_dart)
	player.hurt_taken.connect(_on_player_hurt)
	player.healed.connect(_on_player_healed)
	player.swapped.connect(feedback.play.bind(&"swap"))
	player.parried.connect(func(_e): feedback.play(&"parry"))
	player.double_jumped.connect(feedback.play.bind(&"double_jump"))
	player.tool_sent.connect(_on_tool_sent)
	for r in BARRIERS:
		var b := Barrier.new()
		b.setup(r)
		b.broken.connect(feedback.play.bind(&"barrier_break"))
		b.thudded.connect(feedback.play.bind(&"thud"))
		add_child(b)
		barriers.append(b)
	_spawn_enemies()


func _add_solid(r: Rect2, one_way := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)
	add_child(body)


func _add_pit(left: float, width: float, respawn: Vector2) -> void:
	var pit := Area2D.new()
	pit.collision_layer = 0
	pit.collision_mask = L.PLAYER_BODY | L.ENEMY_BODY
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 100)
	cs.shape = shape
	cs.position = Vector2(left + width / 2.0, GROUND_Y + 350.0)
	pit.add_child(cs)
	pit.body_entered.connect(_on_pit_entered.bind(respawn))
	add_child(pit)


func _on_pit_entered(body: Node, respawn: Vector2) -> void:
	if body == player:
		_player_fell.call_deferred(respawn)
	elif body in enemies:
		body.kill.call_deferred()  # 敵人掉進坑就死，不會一直往下掉


func _player_fell(respawn: Vector2) -> void:
	player.fall_into_pit(respawn)
	camera.reset_smoothing()  # 傳送後鏡頭立即到位，不掃過房間


func _spawn_enemies() -> void:
	for at in CRAWLERS:
		_add_enemy(Crawler.new(), at)
	for at in FLYERS:
		_add_enemy(Flyer.new(), at)
	dummy = ParryDummy.new()  # 練習對象不放進 enemies：不算戰鬥房的敵人
	dummy.tn = tn
	dummy.target = player
	dummy.position = DUMMY
	add_child(dummy)


func _add_enemy(e: Node2D, at: Vector2) -> void:
	e.tn = tn
	e.target = player
	e.position = at
	add_child(e)
	enemies.append(e)
	e.died.connect(_on_enemy_died)
	e.interrupted.connect(_on_enemy_interrupted)


func _on_enemy_died(e: Node) -> void:
	enemies.erase(e)
	var s := Shatter.new()
	s.position = e.position + Vector2(0, -40)
	add_child(s)
	feedback.play(&"shatter")


func _on_enemy_interrupted(_e: Node) -> void:
	feedback.play(&"interrupt")


func _on_player_swung() -> void:
	feedback.play(&"swing")


func _on_player_hit(target: Node) -> void:
	feedback.hitstop()
	feedback.shake()
	feedback.play(&"pogo" if target.collision_layer & L.POGO else &"hit")


func _on_player_dart() -> void:
	feedback.play(&"dart")


func _on_player_hurt() -> void:
	feedback.play(&"hurt")
	feedback.shake()


func _on_player_healed() -> void:
	feedback.play(&"heal")


func _on_tool_sent(t: Node) -> void:
	feedback.play(&"tool_out")
	t.chopped.connect(feedback.play.bind(&"chop"))


## F10 與血量歸零：角色回起點並補滿，敵人全部重生
func reset_room() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	if is_instance_valid(dummy):
		dummy.queue_free()
	for b in barriers:
		b.restore()
	for c in get_children():
		if c is Dart:
			c.queue_free()
	player.respawn(START)
	camera.reset_smoothing()
	_spawn_enemies()


func _draw() -> void:
	for r in SOLIDS + PLATFORMS:
		draw_rect(r, Color(0.22, 0.27, 0.25))
	draw_rect(Rect2(PIT_LEFT, GROUND_Y, PIT_WIDTH, 400), Color(0.05, 0.05, 0.07))
	draw_rect(Rect2(PIT2_LEFT, GROUND_Y, PIT2_WIDTH, 400), Color(0.05, 0.05, 0.07))
