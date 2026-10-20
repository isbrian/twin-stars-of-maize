extends Node2D
# 場景圖層（MV-SLICE-001b1 Task 3）：依主題表鋪四層圖，每幀依鏡頭左緣平移做視差。
# 不用 Parallax2D：它的重複圖塊由渲染層畫、不是節點，測不到「鏡頭在房間兩端時有沒有露出空白」（Review Focus 3）。
# 每層是一個 Node2D，底下是實際鋪好的 Sprite2D；倍率 s 的層，畫面 x ＝ 層內 x − s × 鏡頭左緣。

const Scenery := preload("res://world/scenery.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const NpcAnimator := preload("res://world/npc_animator.gd")
const PalaceLights := preload("res://world/fx/palace_lights.gd")
const ArmProp := preload("res://world/cutscene/arm_prop.gd")
const RigView := preload("res://world/rig_view.gd")
const MacawAnimator := preload("res://world/macaw_animator.gd")
const BODY_AT := Vector2(15100, 900)  # 死後的身體（同死亡演出的舞台，MV-SLICE-001c2b）
const BODY_HEAD_BLIND := 3
const LEDGE_MAX := 40.0  # 厚度不超過這個的實心地形畫成原木平台（MV-SLICE-001c4a）
const BRANCH_MARK := 0.7  # 支路路標的縮放（MV-SLICE-001c4a）
const BODY_DIM := 0.5  # 同 MacawGlints 熄滅後的亮度
const ROPE_KNOT := Vector2(14714, 738)  # 宮殿後牆火堆上方的繩結下緣（bg_palace_back_01.png 量得，MV-SLICE-001c2a）
const SCREEN := Vector2(1920, 1080)
const FLOOR_Y := 900.0
const NIGHT := Color(0.45, 0.5, 0.75)  # 同 MV-SLICE-001a 的夜晚色
const PROP := "res://art/prop/%s.png"
const WAYMARK_INSET := 120.0  # 路標立在門內側多遠
const SHAKE_PAD := 16.0  # 畫面震動（camera.offset ±8，加在鏡頭邊界之後）時多蓋的邊：遠景往上、區段交界往外

var layers := {}  # 圖層名 → Node2D
var regions := {}  # Boss 段落：區段名 → Node2D（底下是該區段的圖層）
var _par: Array = []  # [圖層 Node2D, 視差倍率]
var _ranges := {}  # 區段名 → Vector2(世界 x 起, 迄)：畫面和它重疊才顯示
var _clips: Array = []  # [圖層, 視差倍率, 世界 x]：每幀把圖層裁到這條線（左邊留、右邊不畫）
var palace_lights: Node2D  # Boss 段落：宮殿的假光（MV-SLICE-001c1）
const SIL_ALPHA := {"far": 0.35, "mid": 0.6, "near": 0.85}  # 剪影：各角色的圖層塗成這個透明度的黑（MV-SLICE-001c2a）
var _roles := {}  # Boss 段落：圖層 → 剪影角色 far／mid／near
var _sil_saved := {}  # 剪影前的 modulate
var _sil_on := false
var body_prop: Node2D  # 宮殿地上倒下的 Seven Macaw（覺醒後一直在；MV-SLICE-001c2b）
var arm_prop: Node2D  # 宮殿繩結上掛著的胡納普手臂（第 2 段起到覺醒前）
var terrain: Node2D  # 平台、路標等跟著地形走的素材（不做視差）
var _pieces: Array = []  # {kind, rect}：測試用
var night := false:
	set(v):
		night = v
		modulate = NIGHT if v else Color.WHITE


## 主題、變體、房間大小 → 鋪好四層（前景在角色前面，其餘在後面）
func build(theme: String, variant: int, room_size: Vector2) -> void:
	z_index = -10
	var paths: Dictionary = Scenery.layers(theme, variant)
	for name in Scenery.ORDER:
		if paths[name] == "":
			continue
		var layer := Node2D.new()
		layer.name = name
		if name == "fore":
			layer.z_index = 20  # 相對於本節點的 -10 → 10，畫在角色前面
		add_child(layer)
		layers[name] = layer
		_par.append([layer, Scenery.PARALLAX[name]])
		var tex: Texture2D = load(paths[name])
		var y := FLOOR_Y - Scenery.GROUND_TOP_ROW if name == "ground" else (-SHAKE_PAD if name == "far" else 0.0)
		_tile(layer, tex, y, _span(Scenery.PARALLAX[name], room_size.x))
		if name == "ground":
			var earth := ColorRect.new()
			earth.color = Scenery.EARTH
			earth.position = Vector2(-SCREEN.x, y + Scenery.GROUND_BOTTOM_ROW)  # 從地表條不透明的最後一列往下補，不和地表條重疊
			earth.size = Vector2(room_size.x + SCREEN.x * 3.0, 400.0)
			layer.add_child(earth)
	update(0.0)


## 這一層在鏡頭走完整個房間時會用到的寬度（層內座標）
func _span(s: float, room_w: float) -> float:
	return SCREEN.x + s * maxf(room_w - SCREEN.x, 0.0)


## 從 -圖寬 鋪到 span + 圖寬（左右各多一張，鏡頭抖動也不露底）
func _tile(layer: Node2D, tex: Texture2D, y: float, span: float) -> void:
	var w := tex.get_width()
	var x := -float(w)
	while x < span + w:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = Vector2(x, y)
		layer.add_child(sp)
		x += w


## 依房間資料擺地形素材（MV-SLICE-001b1 Task 4）：平台＝倒木（整根等比縮放到平台寬、上緣對齊）、每扇門內側一個路標
func place_terrain(d: Dictionary) -> void:
	terrain = Node2D.new()
	terrain.name = "terrain"
	add_child(terrain)
	var log_tex: Texture2D = load(PROP % "prop_platform_log")
	var thin: Array = d.solids.filter(func(r): return r.size.y <= LEDGE_MAX)  # 右端的高處平台等薄的實心（MV-SLICE-001c4a）
	for p in d.platforms + thin:
		var k: float = p.size.x / log_tex.get_width()
		add_piece("platform", log_tex, p.position, k)
	var thorns: Texture2D = load(PROP % "prop_thorns_ground")
	for h in d.get("hazards", []):  # 荊棘地形（MV-SLICE-001c4a）：地上荊棘的圖（MV-ASSET-018，淺色尖刺），水平重複
		_fill_low(thorns, h)
	var mark: Texture2D = load(PROP % "prop_waymark")
	for door in d.doors:
		var inward: bool = door.rect.get_center().x < d.size.x / 2.0
		var cx: float = door.rect.end.x + WAYMARK_INSET if inward else door.rect.position.x - WAYMARK_INSET
		var k: float = BRANCH_MARK if door.get("branch", false) else 1.0  # 支路的門：小一號的路標（MV-SLICE-001c4a）
		add_piece("waymark", mark, Vector2(cx - mark.get_width() * k / 2.0, door.spawn.y - mark.get_height() * k), k)


## 荊棘地形：取貼圖底下 rect 高的一截，從左到右重複鋪滿 rect（最後一張裁掉多出的寬）
func _fill_low(tex: Texture2D, rect: Rect2) -> void:
	var h: float = minf(rect.size.y, tex.get_height())
	var x := rect.position.x
	while x < rect.end.x:
		var w: float = minf(tex.get_width(), rect.end.x - x)
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(0, tex.get_height() - h, w, h)
		sp.position = Vector2(x, rect.end.y - h)
		terrain.add_child(sp)
		x += w
	_pieces.append({"kind": "hazard", "rect": rect})


## 在 terrain 放一張貼圖（左上角 at、等比縮放 k），記下它的範圍
func add_piece(kind: String, tex: Texture2D, at: Vector2, k: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = at
	sp.scale = Vector2(k, k)
	terrain.add_child(sp)
	_pieces.append({"kind": kind, "rect": Rect2(at, Vector2(tex.get_size()) * k)})
	return sp


func piece_rects() -> Array:
	return _pieces


## 直條素材（荊棘、閘門、木障）縱向重複蓋滿 rect：寬度等比縮放到 rect 寬，從上緣往下鋪（圖是鏡像拼接的，接縫為 0）
## from_bottom：從底邊往上鋪，多出來的在上緣外（房間木障站在高台上，MV-ASSET-017）
static func fill_vertical(parent: Node2D, tex: Texture2D, rect: Rect2, from_bottom := false) -> void:
	var k: float = rect.size.x / tex.get_width()
	var h: float = tex.get_height() * k
	var y := rect.position.y
	if from_bottom:
		y = rect.end.y - ceilf(rect.size.y / h) * h
	while y < rect.end.y:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = Vector2(rect.position.x, y)
		sp.scale = Vector2(k, k)
		parent.add_child(sp)
		y += h


func update(cam_left: float) -> void:
	for p in _par:
		p[0].position.x = cam_left * (1.0 - p[1])
	for c in _clips:
		_clip(c[0], c[2] - cam_left * (1.0 - c[1]))
	if not regions.is_empty():
		update_region(cam_left + SCREEN.x / 2.0)


func _process(_delta: float) -> void:
	update(-get_viewport().get_canvas_transform().origin.x)


# ---- Boss 段落（MV-SLICE-001b1 Task 6）----

## 三個區段各一組圖層＋地形素材。區段依世界 x 分：nance 樹（到 nance 右牆外緣）、小路（到宮殿入口）、宮殿。
## 小路與宮殿在入口處會同時入鏡：宮殿後牆不透明、加在後面，蓋住小路伸過入口的遠景與中景。
func build_boss() -> void:
	z_index = -10
	var top := Nance.VIEW.position.y  # 畫面上緣 -60
	var ground_y := FLOOR_Y - Scenery.GROUND_TOP_ROW
	var bg := func(k: String) -> Texture2D: return load(Scenery.BG % Scenery.BOSS[k])
	var gate_x := Palace.LEFT
	# nance 樹：鏡頭左緣 -100～4800；樹是一張張左右鏡像接起來的（接縫為 0），正向那張的樹幹在 TREE_X
	var r := _region("boss_nance", -INF, Nance.RIGHT + 100.0)
	var cam := Vector2(Nance.REGION.position.x, Nance.RIGHT - SCREEN.x)
	_roles[_layer(r, bg.call("far"), 0.2, top - SHAKE_PAD, cam)] = "far"
	_roles[_layer(r, bg.call("nance"), 1.0, top, cam, Nance.TREE_X - Scenery.NANCE_TRUNK_X)] = "mid"
	_roles[_ground(r, cam)] = "near"
	var fore := _layer(r, bg.call("fore"), Scenery.PARALLAX.fore, top, cam)
	fore.z_index = 20
	_roles[fore] = "near"
	var cut := Nance.CANOPY.y - top  # Boss 停在樹冠時身體與出招訊號都在畫面頂端：前景上緣的樹冠邊切掉，只留下緣的草叢
	for sp in fore.get_children():
		sp.region_enabled = true
		sp.region_rect = Rect2(0, cut, sp.texture.get_width(), sp.texture.get_height() - cut)
		sp.position.y += cut
	# 小路：鏡頭左緣 7800～14000；前景比角色快、畫在角色前面，伸過入口會蓋在宮殿裡 → 每幀裁到入口線
	r = _region("boss_path", Nance.RIGHT + 100.0, gate_x)
	cam = Vector2(Palace.REGION.position.x, gate_x)
	_roles[_layer(r, bg.call("far"), 0.2, top - SHAKE_PAD, cam)] = "far"
	_roles[_layer(r, bg.call("path_mid"), 0.6, top, cam)] = "mid"
	_roles[_ground(r, cam)] = "near"
	fore = _layer(r, bg.call("fore"), Scenery.PARALLAX.fore, top, cam)
	fore.z_index = 20
	_roles[fore] = "near"
	_clips.append([fore, Scenery.PARALLAX.fore, gate_x])
	# 宮殿：後牆從入口鋪到出口高台的右端，地板線對齊 900
	r = _region("boss_palace", gate_x, INF)
	var back_y := FLOOR_Y - Scenery.PALACE_FLOOR_ROW
	var back := _layer(r, bg.call("palace"), 1.0, back_y, Vector2(gate_x, Palace.EXIT_RIGHT - SCREEN.x), gate_x)
	var roof := ColorRect.new()  # 後牆圖頂只到 −61：上面補一條屋頂的顏色，震動時不露空白
	roof.color = Color8(50, 36, 29)
	roof.position = Vector2(gate_x, top - SHAKE_PAD * 2.0)
	roof.size = Vector2(Palace.EXIT_RIGHT + SCREEN.x - gate_x, back_y - roof.position.y)
	back.add_child(roof)
	_roles[back] = "mid"
	_place_boss_terrain()
	_roles[terrain] = "near"
	palace_lights = PalaceLights.new()  # 最後加：畫在寶座上面
	add_child(palace_lights)
	update(0.0)


## 新區段（之後加的畫在前面）；range_lo～range_hi 是它的世界 x 範圍
func _region(name: String, range_lo: float, range_hi: float) -> Node2D:
	var n := Node2D.new()
	n.name = name
	add_child(n)
	regions[name] = n
	_ranges[name] = Vector2(range_lo, range_hi)
	return n


## 一層：cam＝這個區段的鏡頭左緣範圍；anchor 有值時左右鏡像交替鋪、正向那張的左緣在 anchor
func _layer(region: Node2D, tex: Texture2D, s: float, y: float, cam: Vector2, anchor := NAN) -> Node2D:
	var layer := Node2D.new()
	region.add_child(layer)
	_par.append([layer, s])
	var w := float(tex.get_width())
	var lo := s * cam.x
	var hi := s * cam.y + SCREEN.x
	var i := 0 if is_nan(anchor) else floori((lo - anchor) / w)
	var x0 := lo - w if is_nan(anchor) else anchor
	while x0 + i * w < hi:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = Vector2(x0 + i * w, y)
		sp.flip_h = not is_nan(anchor) and posmod(i, 2) == 1
		layer.add_child(sp)
		i += 1
	return layer


## 把圖層的圖塊裁到層內 x＝cut：整張在右邊的隱藏、跨線的只畫左半段
static func _clip(layer: Node2D, cut: float) -> void:
	for sp in layer.get_children():
		var x: float = sp.position.x
		var size: Vector2 = sp.texture.get_size()
		sp.visible = x < cut
		sp.region_enabled = x < cut and x + size.x > cut
		sp.region_rect = Rect2(0, 0, cut - x, size.y)


## 森林地表＋下方補色（同 build 的 ground）
func _ground(region: Node2D, cam: Vector2) -> Node2D:
	var tex: Texture2D = load(Scenery.BG % "bg_forest_ground_tile")
	var y := FLOOR_Y - Scenery.GROUND_TOP_ROW
	var layer := _layer(region, tex, 1.0, y, cam)
	var earth := ColorRect.new()
	earth.color = Scenery.EARTH
	earth.position = Vector2(cam.x - SCREEN.x, y + Scenery.GROUND_BOTTOM_ROW)
	earth.size = Vector2(cam.y - cam.x + SCREEN.x * 3.0, 400.0)
	layer.add_child(earth)
	return layer


## Boss 段落的地形素材：nance 樹枝（圖上沒有在 BRANCH 高度的水平粗枝 → 疊倒木）、宮殿低台、Chimalmat 與寶座、出口高台、左端路標
func _place_boss_terrain() -> void:
	terrain = Node2D.new()
	terrain.name = "terrain"
	add_child(terrain)
	# nance 粗枝（MV-ASSET-015）：可站的枝幹上緣對齊樹枝平台；左端的粗端疊在樹幹上，右端的葉叢在平台外
	var b := Scenery.NANCE_BRANCH_BODY
	add_piece("branch", load(PROP % "prop_nance_branch"), Nance.BRANCH.position - b, 1.0)
	for i in Palace.PLATFORMS.size():
		add_piece("platform", load(PROP % ["prop_palace_platform_l", "prop_palace_platform_r"][i]), Palace.PLATFORMS[i].position, 1.0)
	var throne: Texture2D = load(PROP % "prop_palace_throne")
	var throne_x := Palace.BARRIER.position.x - throne.get_width()  # 寶座右緣靠著障壁
	var chimalmat := Node2D.new()  # 她站在寶座左邊、尾巴在寶座後面（先加，畫在寶座後面）
	chimalmat.name = "Chimalmat"
	chimalmat.position = Vector2(throne_x + 60.0, FLOOR_Y)
	terrain.add_child(chimalmat)
	NpcAnimator.attach(chimalmat, "chimalmat").facing = -1  # 照基準圖面向左（同原本的立繪）
	add_piece("throne", throne, Vector2(throne_x, FLOOR_Y - throne.get_height()), 1.0)
	add_piece("ledge", load(PROP % "prop_palace_ledge"), Palace.EXIT_LEDGE.position, 1.0)
	var mark: Texture2D = load(PROP % "prop_waymark")
	add_piece("waymark", mark, Vector2(-mark.get_width() / 2.0, FLOOR_Y - mark.get_height()), 1.0)  # 回森林 4 的出口線 x＝0
	# 宮殿入口外牆（MV-ASSET-015）：右柱的右緣對齊入口閘門右緣（閘門關上時疊在柱上），門洞在閘門左邊
	var door: Texture2D = load(PROP % "prop_palace_entrance")
	add_piece("palace_entrance", door, Vector2(Palace.GATE.end.x - door.get_width(), FLOOR_Y - door.get_height()), 1.0)


## 只顯示和畫面（鏡頭中心 ±960，再加震動的邊）重疊的區段；剪影時不震動、不加邊（宮殿後牆半透明，不透出小路；MV-SLICE-001c2c）
func update_region(camera_x: float) -> void:
	var half := SCREEN.x / 2.0 + (0.0 if _sil_on else SHAKE_PAD)
	for name in regions:
		var rg: Vector2 = _ranges[name]
		regions[name].visible = camera_x + half > rg.x and camera_x - half < rg.y


## 死後的宮殿（MV-SLICE-001c2b，SLICE-c2b-8）：地上倒下的 Seven Macaw（collapse 最後一格、失明的頭、偏暗、沒有判定），奇瑪瑪特不在
func set_dead(on: bool) -> void:
	if on and body_prop == null:
		body_prop = RigView.new()
		body_prop.name = "Body"
		terrain.add_child(body_prop)
		body_prop.build("sevenmacaw")
		var a: Dictionary = RigView.anims_at(body_prop.anims_path).anims["collapse"]
		body_prop.pose("collapse", a.frames[-1].t)
		for i in MacawAnimator.HEADS.size():
			body_prop.sprite(MacawAnimator.HEADS[i]).visible = i == BODY_HEAD_BLIND
		body_prop.position = BODY_AT
		_dim_body()
	if body_prop != null:
		body_prop.visible = on
	var chi: Node2D = terrain.get_node("Chimalmat")
	chi.visible = not on
	if not on:  # 死亡演出把她塗黑、淡出、倒下（MV-SLICE-001c2b）：恢復
		chi.modulate = Color.WHITE
		chi.get_node("NpcAnimator").play("idle")


## 身體的實際亮度＝BODY_DIM（同替身熄滅後）：它在 terrain 底下，要抵掉場景的暗度（modulate 可以 > 1）
func _dim_body() -> void:
	if body_prop != null:
		var k: float = BODY_DIM / modulate.r
		body_prop.modulate = Color(k, k, k)


## 宮殿繩結上掛著胡納普的手臂（MV-SLICE-001c2a；由 boss_fight 依進度設定：第 2 段起、覺醒前）
func set_arm_hung(on: bool) -> void:
	if on and arm_prop == null:
		arm_prop = ArmProp.make()
		arm_prop.position = ROPE_KNOT
		terrain.add_child(arm_prop)
	if arm_prop != null:
		arm_prop.visible = on


## 逆光剪影（MV-SLICE-001c2a，SLICE-c2-4）：各圖層塗成黑色＋依角色的透明度，疊在過場執行器的暖色漸層底上；關閉還原
func set_silhouette(on: bool) -> void:
	_sil_on = on
	for n in _roles:
		if on:
			if not _sil_saved.has(n):
				_sil_saved[n] = n.modulate
			n.modulate = Color(0, 0, 0, SIL_ALPHA[_roles[n]])
		elif _sil_saved.has(n):
			n.modulate = _sil_saved[n]
	if not on:
		_sil_saved.clear()


## 某角色第一個圖層目前的透明度（測試用）
func layer_alpha(role: String) -> float:
	for n in _roles:
		if _roles[n] == role:
			return n.modulate.a
	return -1.0


## 每拔掉一個光源暗一階（灰階倍率），宮殿假光同時熄一組；animate＝段落進行中拔掉（假光淡出）
func set_darkness(lights_removed: int, animate := false) -> void:
	var v: float = Scenery.DARKNESS[clampi(lights_removed, 0, Scenery.DARKNESS.size() - 1)]
	modulate = Color(v, v, v)
	_dim_body()
	if palace_lights != null:
		palace_lights.set_level(lights_removed, animate)


func ground_top() -> float:
	return FLOOR_Y
