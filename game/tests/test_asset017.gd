extends "res://tests/base_test.gd"
# MV-ASSET-017 整合：下劈水晶、血量碎片、血條半格、森林木障換成正式素材（規則不變）。

const GameStateScr := preload("res://state/game_state.gd")
const RoomScr := preload("res://world/room.gd")
const TestB := preload("res://world/rooms/_test_b.gd")


func make_gs():
	var gs = GameStateScr.new()
	gs.tn = fresh_tuning()
	gs.reset_new_game()
	return gs


func build_room(d: Dictionary, gs) -> Node:
	var r = RoomScr.new()
	add_child(r)
	r.build(d, gs, gs.tn)
	r.player.scripted = true
	await frames(3)
	return r


func tex_name(t) -> String:
	return "" if t == null else String(t.resource_path).get_file()


func test_crystal_uses_art() -> void:
	var c = PogoCrystal.new()
	check(tex_name(c.get("texture")) == "prop_pogo_crystal.png", "下劈水晶用素材（%s）" % tex_name(c.get("texture")))
	c.free()


func test_fragment_pickup_uses_art() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.fragment = {"id": "frag_x", "pos": Vector2(1500, 900)}
	var r = await build_room(d, gs)
	check(tex_name(r.fragment_pickup.texture) == "prop_health_fragment.png", "血量碎片用素材（%s）" % tex_name(r.fragment_pickup.texture))
	r.queue_free()
	await frames(1)
	gs.free()


func test_hud_half_pip_art() -> void:
	var t: Dictionary = Hud.TEXTURES
	check(t.has("health_half") and tex_name(t.health_half) == "ui_health_pip_half.png", "HUD 半格用素材")
	if t.has("health_half"):
		check(t.health_half.get_height() == t.health_full.get_height(), "半格和一格同高（%d／%d）" % [t.health_half.get_height(), t.health_full.get_height()])


## 森林木障：用森林的圖；圖從底部往上鋪，不能伸出木障底部（底部是高台頂面）
func test_room_barrier_forest_art_bottom_aligned() -> void:
	var gs = make_gs()
	var d: Dictionary = TestB.data()
	d.enemies = []
	d.gates = []
	d.theme = "forest"
	var rect := Rect2(1500, -1000, 60, 1600)
	d.barriers = [{"rect": rect}]
	var r = await build_room(d, gs)
	var sprites: Array = r.barriers[0].get_node("Art").get_children()
	check(not sprites.is_empty() and sprites.all(func(s): return tex_name(s.texture) == "prop_forest_barrier.png"), "木障用森林木障的圖")
	var bottom := rect.size.y / 2.0  # Art 的座標以木障中心為原點
	var lowest := -INF
	for s in sprites:
		lowest = maxf(lowest, s.position.y + s.texture.get_height() * s.scale.y)
	check(absf(lowest - bottom) < 0.5, "圖的底邊對齊木障底部（%.1f／%.1f）" % [lowest, bottom])
	r.queue_free()
	await frames(1)
	gs.free()
