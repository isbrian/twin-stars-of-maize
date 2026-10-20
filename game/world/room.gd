extends Node2D
# 通用房間（MV-SLICE-001a 規格「架構」、Task 4）：讀一份房間資料，建出地形、門、旗標門、敵人、角色與鏡頭。
# 房間只描述內容、不含流程；換房由 room_flow.gd 負責。灰盒：_draw() 畫色塊。

const Tuning := preload("res://core/tuning/combat_tuning.gd")
const Sound := preload("res://core/audio/sound_table.gd")
const L := preload("res://core/combat/layers.gd")
const Crawler := preload("res://core/enemies/crawler.gd")
const Flyer := preload("res://core/enemies/flyer.gd")
const Reflector := preload("res://core/enemies/reflector.gd")  # MV-SLICE-001c4c1
const BeamFx := preload("res://world/fx/beam_fx.gd")
const ENEMY_SCRIPTS := {"crawler": Crawler, "flyer": Flyer, "reflector": Reflector}
const Feedback := preload("res://core/fx/feedback.gd")
const Shatter := preload("res://core/fx/shatter.gd")
const Loadout := preload("res://state/loadout.gd")
const RestPoint := preload("res://world/rest_point.gd")
const Pickup := preload("res://world/pickup.gd")
const FloatText := preload("res://world/float_text.gd")
const ToolPickup := preload("res://world/tool_pickup.gd")
const Weapons := preload("res://core/player/weapons.gd")
const SceneryView := preload("res://world/scenery_view.gd")
const NpcAnimator := preload("res://world/npc_animator.gd")
const Hazard := preload("res://core/level/hazard.gd")
const Intent := preload("res://core/player/intent.gd")
const PogoCrystal := preload("res://core/level/pogo_crystal.gd")
const Arena := preload("res://core/level/arena.gd")
const Barrier := preload("res://core/level/barrier.gd")
const BARRIER_TEX := "res://art/prop/prop_forest_barrier.png"  # MV-ASSET-017 C-04
const EnemyAnimator := preload("res://world/enemy_animator.gd")  # 造物的骨架（MV-SLICE-001b2b1；房間的 kind 就是骨架的角色名）
const ITEMS := {"axe": Weapons.Weapon.AXE, "stick": Weapons.Weapon.STICK, "gear": Weapons.Weapon.BALLGEAR}

signal door_entered(door_id: String)
signal trigger_entered(trigger_id: String)
signal interacted(kind: String)  # "rest"、"npc"、"pickup:<id>"
signal player_died
signal hint_requested(id: String)  # 玩家進到資料 hint_at 的區域（每次進房一次；MV-SLICE-001c4a）

var data: Dictionary
var gs
var tn: Tuning
var player
var enemies: Array = []
var gates: Array = []
var camera: Camera2D
var feedback
var rest  # rest_point.gd（沒有時 null）
var stash  # pickup.gd（沒有或已拿過時 null）
const SAFE_PAD := 80.0  # 荊棘：安全點要離每段荊棘至少這麼遠（約一個身寬；MV-SLICE-001c4a）
const THORN_FADE := 0.15  # 荊棘放回：淡黑、淡回各這麼久
const SAFE_EDGE := 60.0  # 安全點離所站地形的邊緣至少這麼遠：放回後不會一放就站在原木邊上（MV-TUNE-004）

var barriers: Array = []  # 木障 barrier.gd（MV-SLICE-001c4b；有旗標且已破開的不建）
var arena  # 關門戰 arena.gd（沒有或獎勵已拿過時 null）
var hazards: Array = []  # 荊棘地形的矩形
var _hazard_nodes: Array = []
var safe_ground := Vector2.INF  # 最後站穩的地面（離荊棘夠遠）
var _respawning := false
var _fade: ColorRect
var fragment_pickup  # 血量碎片的 pickup.gd（MV-SLICE-001c4a；沒有或已拿過時 null）
var npc_anim  # 祖母的 npc_animator.gd（沒有時 null）
var npc_asleep := false:  # 祖母睡著（MV-SLICE-001c3a：抓到老鼠後的夜裡到天亮）：頭上「Zzz」、互動不開兌換
	set(v):
		npc_asleep = v
		_show_zzz(v)
		if npc_anim != null:
			npc_anim.play("doze" if v else "idle")  # 坐不下去（祖母沒有腿）：站著打盹（MV-SLICE-001c3b）
var pickups: Array = []  # tool_pickup.gd
var scenery  # scenery_view.gd（MV-SLICE-001b1；資料沒有 theme 的測試房間為 null，維持灰盒）


func build(d: Dictionary, p_gs, p_tn: Tuning) -> void:
	data = d
	gs = p_gs
	tn = p_tn
	if d.get("theme", "") != "":
		scenery = SceneryView.new()
		add_child(scenery)
		scenery.build(d.theme, d.get("variant", 0), d.size)
		scenery.place_terrain(d)
	for r in d.solids:
		_add_solid(r)
	for r in d.platforms:
		_add_solid(r, true)
	for g in d.get("gates", []):
		if not gs.has_flag(g.until_flag):
			add_gate(g.rect)
	for door in d.doors:
		_add_area(door.rect).body_entered.connect(_on_body.bind(door_entered, door.id))
	for t in d.get("triggers", []):
		_add_area(t.rect).body_entered.connect(_on_body.bind(trigger_entered, t.id))
	if d.has("rest"):
		rest = RestPoint.new()
		rest.position = d.rest.pos
		add_child(rest)
	if d.has("stash") and not gs.stashes_taken.get(d.stash.id, false):
		stash = Pickup.new()
		stash.position = d.stash.pos
		add_child(stash)
		stash.touched.connect(_on_stash, CONNECT_ONE_SHOT)
	if d.has("fragment"):
		place_fragment(d.fragment)
	for p in d.get("pickups", []):
		if not gs.weapons_owned.has(ITEMS[p.item]):
			add_pickup(p.id, p.item, p.pos)
	if d.has("npc") and scenery != null:  # 祖母的骨架（面向右，MV-SLICE-001b2b2）
		var npc := Node2D.new()
		npc.name = "Npc"
		npc.position = d.npc.pos
		add_child(npc)
		npc_anim = NpcAnimator.attach(npc, "xmucane")
		npc_anim.process_mode = Node.PROCESS_MODE_ALWAYS  # 兌換時遊戲暫停，遞出物品照樣播
	player = Loadout.make_player(gs, tn)
	player.position = d.rest.pos if d.has("rest") else d.doors[0].spawn
	add_child(player)
	Audio.listener = player
	Audio.floor_source = floor_material_at
	player.interacted.connect(_on_interact)
	player.died.connect(func(): player_died.emit(), CONNECT_DEFERRED)
	for at in d.get("crystals", []):  # 下劈水晶（MV-SLICE-001c4a）
		var c := PogoCrystal.new()
		c.position = at
		add_child(c)
	if d.has("arena") and not gs.stashes_taken.get(d.arena.reward.id, false):
		arena = Arena.new()
		arena.room = self
		arena.data = d.arena
		add_child(arena)
	if d.has("hint_at"):
		var area := _add_area(d.hint_at.rect)
		area.body_entered.connect(func(b): if b == player: hint_requested.emit(d.hint_at.id), CONNECT_ONE_SHOT)
	for h in d.get("hazards", []):
		var hz := Hazard.new()
		hz.setup(h)
		hz.add_to_group(Audio.GROUP_DANGER)
		hz.touched.connect(func(b): if b == player: _thorn_respawn())
		add_child(hz)
		_hazard_nodes.append(hz)
		hazards.append(h)
	camera = Camera2D.new()
	camera.position = Vector2(0, -150)
	camera.position_smoothing_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(d.size.x)
	camera.limit_bottom = int(d.size.y)
	player.add_child(camera)
	feedback = Feedback.new()
	feedback.tn = tn
	feedback.camera = camera
	add_child(feedback)
	_wire_feedback()
	for b in d.get("barriers", []):
		_add_barrier(b)
	var gone: Array = gs.defeated.get(d.id, [])
	for i in d.enemies.size():
		if not gone.has(i):
			_add_enemy(i, d.enemies[i])
	queue_redraw()


func spawn_point(door_id: String) -> Vector2:
	for door in data.doors:
		if door.id == door_id:
			return door.spawn
	return player.position


## 互動鍵：附近有休息點就休息、有祖母就兌換（Task 7）、有東西就撿（Task 10）
func _on_interact() -> void:
	var t := interact_target()
	if t == "npc" and npc_anim != null:
		npc_anim.play("give", "idle")
	if t == "rest" or t == "npc":
		Audio.play(&"voc_real" if t == "rest" else &"voc_alive")  # 真實＝篝火、活物＝祖母（MV-SLICE-001d1a）
	if t != "":
		interacted.emit(t)


## 腳下地面（MV-SLICE-001d1b 腳步，SLICE-d1b-2）：房間 floor 是 hard（祖母家）或站在平台頂端 → 硬地；其他是土
func floor_material_at(pos: Vector2) -> StringName:
	if data.get("floor", "") == "hard":
		return &"hard"
	for r in data.get("platforms", []):
		if pos.x >= r.position.x and pos.x <= r.end.x and absf(pos.y - r.position.y) <= 8.0:
			return &"hard"
	return &"dirt"


## 角色現在按互動鍵會做什麼："rest"、"npc"、"pickup:<id>"；沒有時 ""（按鍵提示也用）
func interact_target() -> String:
	if rest != null and rest.near(player):
		return "rest"
	if data.has("npc") and not npc_asleep and absf(player.global_position.x - data.npc.pos.x) <= RestPoint.REACH.x:
		return "npc"
	for pk in pickups:
		if pk.near(player):
			return "pickup:" + pk.id
	return ""


## 佔位的「Zzz」（c3b 換成祖母的睡姿）
func _show_zzz(on: bool) -> void:
	var npc := get_node_or_null("Npc")
	if npc == null:
		return
	var z := npc.get_node_or_null("Zzz")
	if on and z == null:
		var l := Label.new()
		l.name = "Zzz"
		l.text = "Z z z"
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		l.position = Vector2(20, -260)
		npc.add_child(l)
	elif not on and z != null:
		z.queue_free()


func add_pickup(id: String, item: String, at: Vector2) -> void:
	var pk := ToolPickup.new()
	pk.id = id
	pk.item = item
	pk.position = at
	add_child(pk)
	pickups.append(pk)


func remove_pickup(id: String) -> void:
	for pk in pickups:
		if pk.id == id:
			pickups.erase(pk)
			pk.queue_free()
			return


## 荊棘：記下最後站穩、離荊棘夠遠的地面
func _physics_process(_delta: float) -> void:
	if player == null or _respawning:
		return
	for hz in _hazard_nodes:  # 已經在荊棘裡（例如放回後又走回去）：body_entered 不會再發，這裡補上（c4a 最終審查）
		if hz.overlaps_body(player):
			_thorn_respawn()
			return
	if safe_ground == Vector2.INF:
		safe_ground = player.position
	elif player.is_on_floor() and _clear_of_hazards(player.position):
		var at := _inside_ground(player.position)
		if at != Vector2.INF:  # 找不到腳下的地形（站在邊緣外一點點）就不記，免得記在半空
			safe_ground = at


## 把腳底位置往所站地形的內側挪，離兩邊至少 SAFE_EDGE（地形太窄時放中間）
## 站在邊緣時腳底點可能已經在地形外（身體還壓著一半），所以範圍放寬半個身寬＋4；找不到回 INF
func _inside_ground(at: Vector2) -> Vector2:
	var half: float = player.SIZE.x / 2.0 + 4.0
	for r in data.solids + data.platforms:
		if at.x >= r.position.x - half and at.x <= r.end.x + half and absf(at.y - r.position.y) <= 2.0:
			if r.size.x <= SAFE_EDGE * 2.0:
				return Vector2(r.get_center().x, at.y)
			return Vector2(clampf(at.x, r.position.x + SAFE_EDGE, r.end.x - SAFE_EDGE), at.y)
	return Vector2.INF


func _clear_of_hazards(at: Vector2) -> bool:
	for h in hazards:
		if at.x > h.position.x - SAFE_PAD and at.x < h.end.x + SAFE_PAD and at.y > h.position.y - SAFE_PAD:
			return false
	return true


## 碰到荊棘：扣 1 格（無敵中不扣）；死了交給死亡流程；否則淡黑、放回 safe_ground、淡回
func _thorn_respawn() -> void:
	if _respawning:
		return
	Audio.play(&"lvl_thorn_hurt")  # MV-SLICE-001d1b
	if player.health.take_damage(1, tn.hurt_invuln_time):
		player.hurt_taken.emit()
	if player.health.is_dead():
		player.died.emit()
		return
	_respawning = true
	var was_scripted: bool = player.scripted
	player.scripted = true
	player.intent = Intent.new()  # 清掉按著的方向鍵，放回後不會滑回荊棘（c4a 最終審查）
	player.velocity = Vector2.ZERO
	await _fade_to(1.0)
	player.return_to(safe_ground)
	player.move_wait_neutral = true
	await _fade_to(0.0)
	player.scripted = was_scripted
	_respawning = false


func _fade_to(a: float) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	var from := _fade.color.a
	var t := 0.0
	while t < THORN_FADE:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_fade.color.a = lerpf(from, a, minf(t / THORN_FADE, 1.0))
	_fade.color.a = a


## 血量碎片（MV-SLICE-001c4a）：f＝{id, pos}；拿過的不放。關門戰的獎勵也用這個
func place_fragment(f: Dictionary) -> void:
	if gs.stashes_taken.get(f.id, false):
		return
	fragment_pickup = Pickup.new()
	fragment_pickup.fragment = true
	fragment_pickup.position = f.pos
	add_child(fragment_pickup)
	fragment_pickup.touched.connect(_on_fragment.bind(f.id), CONNECT_ONE_SHOT)


## 奇數片：提示湊一半；偶數片：上限 +1、補滿
func _on_fragment(id: String) -> void:
	gs.stashes_taken[id] = true
	var at: Vector2 = fragment_pickup.position
	if gs.fragments() % 2 == 1:
		_float("血量碎片 1/2", at)
	else:
		player.health.max_hp = gs.max_hp_now()
		player.health.hp = player.health.max_hp
		gs.hp = player.health.hp
		_float("血量上限 +1", at)
	fragment_pickup.queue_free()
	fragment_pickup = null


func _on_stash() -> void:
	gs.add_cacao(tn.stash_cacao)
	gs.stashes_taken[data.stash.id] = true
	_float("+%d" % tn.stash_cacao, stash.position)
	stash.queue_free()
	stash = null


func _float(text: String, at: Vector2) -> void:
	var f := FloatText.new()
	f.text = text
	f.position = at + Vector2(0, -120)
	add_child(f)


func _add_solid(r: Rect2, one_way := false) -> StaticBody2D:
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
	return body


func _add_area(r: Rect2) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = L.PLAYER_BODY
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	a.add_child(cs)
	add_child(a)
	return a


func _on_body(body: Node, sig: Signal, id: String) -> void:
	if body == player:
		sig.emit(id)


func _add_enemy(index: int, e: Dictionary) -> void:
	spawn_enemy(e).died.connect(_on_enemy_died.bind(index))


## 放一隻敵人（不記進 defeated：關門戰用；一般敵人由 _add_enemy 再接 defeated）。打倒時照樣掉可可豆、碎裂
func spawn_enemy(e: Dictionary) -> Node:
	var n = ENEMY_SCRIPTS[e.kind].new()
	n.tn = tn
	n.target = player
	n.position = e.pos
	n.add_to_group(Audio.GROUP_GLASS)  # 假光造物：玻璃顫音距離層（MV-SLICE-001d1a）
	n.died.connect(func(x): x.remove_from_group(Audio.GROUP_GLASS))
	add_child(n)
	if scenery != null:
		EnemyAnimator.attach(n, e.kind)
		if e.kind == "reflector":  # 光束沿用 Seven Macaw 的光束特效（MV-SLICE-001c4c2）
			BeamFx.attach(n)
	if n.has_signal("thudded"):
		n.thudded.connect(feedback.play.bind(&"enm_reflector_block"))
	enemies.append(n)
	n.died.connect(_on_enemy_gone)
	n.interrupted.connect(func(_e): feedback.play(&"interrupt"))
	return n


## 閘門：實心＋荊棘牆外觀（MV-SLICE-001b1）；回傳實心節點
func add_gate(r: Rect2) -> StaticBody2D:
	var body := _add_solid(r)
	gates.append(body)
	if scenery != null:  # 掛在閘門底下，閘門消失時一起消失
		var art := Node2D.new()
		art.name = "Art"
		body.add_child(art)
		SceneryView.fill_vertical(art, load("res://art/prop/prop_thorns_wall.png"), r)
	return body


func remove_gate(body: StaticBody2D) -> void:
	gates.erase(body)
	body.queue_free()


func _on_enemy_died(_e: Node, index: int) -> void:
	if not gs.defeated.has(data.id):
		gs.defeated[data.id] = []
	gs.defeated[data.id].append(index)


func _on_enemy_gone(e: Node) -> void:
	enemies.erase(e)
	var n := randi_range(tn.cacao_drop_min, tn.cacao_drop_max)  # 規格 SLICE-a8；Boss 段落的召喚物不經過這裡、不掉錢
	gs.add_cacao(n)
	_float("+%d" % n, e.position)
	var s := Shatter.new()
	s.position = e.position + Vector2(0, -40)
	add_child(s)
	feedback.play(&"shatter")


## 木障（MV-SLICE-001c4b）：有 flag 的破開後設旗標、之後不再建；沒有 flag 的每次建房都立起
func _add_barrier(b: Dictionary) -> void:
	var flag: String = b.get("flag", "")
	if flag != "" and gs.has_flag(flag):
		return
	var bar := Barrier.new()
	bar.setup(b.rect)
	add_child(bar)
	barriers.append(bar)
	if flag != "":
		bar.broken.connect(gs.set_flag.bind(flag))
	bar.broken.connect(feedback.play.bind(&"barrier_break"))
	bar.thudded.connect(feedback.play.bind(&"lvl_barrier_thud"))
	if scenery != null:  # 外觀掛在木障底下，破了就跟著消失（同 palace_arena.use_art）
		bar.art = true
		var art := Node2D.new()
		art.name = "Art"
		bar.add_child(art)
		SceneryView.fill_vertical(art, load(BARRIER_TEX), Rect2(-b.rect.size / 2.0, b.rect.size), true)  # 從底部往上鋪：底部是高台頂面，不能伸出去


## 命中回饋照原型練習房
func _wire_feedback() -> void:
	feedback.wire_moves(player)
	player.hit_landed.connect(func(target: Node):
		feedback.hitstop()
		feedback.shake()
		feedback.play(&"pogo" if target.collision_layer & L.POGO else Sound.hit_id(player.attack_weapon)))
	player.dart_fired.connect(feedback.play.bind(&"dart"))
	player.hurt_taken.connect(func():
		feedback.play(&"hurt")
		feedback.shake())
	player.healed.connect(feedback.play.bind(&"heal"))
	player.parried.connect(func(_e): feedback.play(&"parry"))
	player.double_jumped.connect(feedback.play.bind(&"double_jump"))  # 覺醒後的能力（MV-SLICE-001c4b，同 Boss 段落）
	player.tool_sent.connect(func(t: Node):
		feedback.play(&"tool_out")
		t.chopped.connect(feedback.play.bind(&"chop")))


func _draw() -> void:
	if scenery == null:  # 有場景時地面由地表層畫；左右牆在鏡頭外
		for r in data.solids:
			draw_rect(r, Color(0.32, 0.36, 0.3))
	if scenery == null:  # 有場景時平台、荊棘、路標都是素材（scenery_view、閘門的 Art）
		for r in data.platforms:
			draw_rect(r, Color(0.45, 0.42, 0.32))
		for g in gates:
			if is_instance_valid(g):
				var cs: CollisionShape2D = g.get_child(0)
				draw_rect(Rect2(cs.position - cs.shape.size / 2.0, cs.shape.size), Color(0.4, 0.55, 0.25))
		for door in data.doors:
			draw_rect(door.rect, Color(0.9, 0.85, 0.6, 0.35))
	if data.has("npc") and scenery == null:
		draw_rect(Rect2(data.npc.pos + Vector2(-35, -150), Vector2(70, 150)), Color(0.75, 0.45, 0.3))  # 祖母（灰盒）
