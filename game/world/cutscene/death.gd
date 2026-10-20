extends RefCounted
# 死亡（MV-SLICE-001c2b，SLICE-c2b-3、5～8；MV-BOSS-001 BOSS-9b、BOSS-8）：第 3 段設局成功。
# 他伏低、老人摘去眼中的寶石 → 他呆望 → 身上的光一點一點熄滅、宮殿最後的假光淡出 → 他靜靜倒下，奇瑪瑪特變黑倒下、淡出
# → 老人撿起珠寶、帶著金光走出畫面。台詞照 card_text 的 death 卡。之後照舊顯示 awaken 卡（c2c 再改）。

const Palace := preload("res://core/boss/palace_arena.gd")
const Teeth := preload("res://world/cutscene/teeth.gd")
const FxKit := preload("res://world/fx/fx_kit.gd")

const N1 := "老人又摘去他眼中的貴金屬。"
const N2 := "他不覺得痛，只是呆呆望著前方。"
const N3 := "他身上的光一點一點熄滅了。"
const N4 := "七金剛鸚鵡死了。他的妻子奇瑪瑪特也隨之死去。"
const N5 := "兩位老人帶走了他的珠寶。"
const HEAD_MAIZE := 2
const HEAD_BLIND := 3
const OUT_SECS := 2.0  # 身上光點熄滅
const STEP_BACK := 120.0  # 摘眼後老人退開
const PICK_AT := [-170.0, -100.0]  # 撿珠寶：老人站在舞台左邊多遠（老伯、老婆婆）
const OUT_X := Palace.LEFT - 200.0  # 走出畫面
const JEWELS := 3
const JEWEL_D := 22.0
const JEWEL_AT := Vector2(30, -95)  # 捧在身前（替身本地座標，面向右）

var _macaw: Node2D
var _glints: Node2D
var _elders: Array = []


func play(cs) -> void:
	var f = cs.host
	cs.view(Palace.VIEW)
	Teeth.spawn_twins(cs)
	var elders: Array = Teeth.spawn_elders(cs)
	var macaw: Node2D = cs.spawn("sevenmacaw", f.boss.position)
	macaw.set_head(HEAD_MAIZE)
	var glints: Node2D = macaw.add_glints()
	_macaw = macaw
	_glints = glints
	_elders = elders
	cs.sfx(&"boss_sm_kneel")  # 伏低（MV-SLICE-001d1a）
	await Teeth.hop_and_bow(cs, macaw)
	await Teeth.elders_reach(cs, elders)
	macaw.set_head(HEAD_BLIND)  # 老人的背影擋住他的眼睛
	cs.sfx(&"cs_gem_pluck")  # 摘去眼中的寶石（MV-SLICE-001d1b）
	await cs.narrate(N1)
	await cs.together([cs.walk.bind(elders[0], elders[0].position.x - STEP_BACK), cs.walk.bind(elders[1], elders[1].position.x - STEP_BACK)])
	for e in elders:
		e.facing = 1
	macaw.play("idle_ground")
	await cs.narrate(N2)
	# 光熄滅：身上光點由翅膀尖往胸口熄、宮殿最後一組假光淡出、場景到最暗
	if not cs.skipped:
		glints.extinguish(OUT_SECS)
		cs.sfx(&"boss_sm_light_fade")
		f.scenery.set_darkness(3, true)
	await cs.together([cs.narrate.bind(N3), cs.wait.bind(OUT_SECS)])
	# 倒下；奇瑪瑪特變黑、倒下、淡出（場景裡真正的她：亮度跟著場景、留在寶座後面；跳過時由 end_state 的 set_dead 藏起）
	var chi: Node2D = f.scenery.terrain.get_node("Chimalmat")
	await cs.together([cs.play.bind(macaw, "collapse"), _chimalmat_dies.bind(cs, chi), cs.narrate.bind(N4)])
	# 帶走珠寶
	await cs.together([cs.walk.bind(elders[0], Teeth.STAGE_X + PICK_AT[0]), cs.walk.bind(elders[1], Teeth.STAGE_X + PICK_AT[1])])
	for e in elders:
		e.facing = 1
	await cs.together([cs.play.bind(elders[0], "pick"), cs.play.bind(elders[1], "pick")])
	cs.sfx(&"cs_jewels_gather")  # 撿起珠寶
	for e in elders:
		_give_jewels(e)
	await cs.together([cs.narrate.bind(N5), cs.walk.bind(elders[0], OUT_X), cs.walk.bind(elders[1], OUT_X - 70.0)])


## 被跳過、接著播覺醒時（skip_stop）：替身與場景直接擺到死亡的最後樣子——他倒下、光點熄滅、老人離開、奇瑪瑪特不在、最暗
func settle(cs) -> void:
	if is_instance_valid(_macaw):
		_macaw.set_head(HEAD_BLIND)
		_macaw.play("collapse")
		_macaw.t = _macaw.anim_length("collapse")
	if is_instance_valid(_glints):
		_glints.extinguish(0.0)
	for e in _elders:
		if is_instance_valid(e):
			e.queue_free()
	cs.host.scenery.terrain.get_node("Chimalmat").modulate = Color(0, 0, 0, 0)
	cs.host.scenery.set_darkness(3)


func _chimalmat_dies(cs, chi: Node2D) -> void:
	var anim: Node = chi.get_node("NpcAnimator")
	await cs.tint(chi, Color(0, 0, 0, 1), 0.6)
	anim.play("collapse")
	await cs.wait(anim.length("collapse"))
	await cs.tint(chi, Color(0, 0, 0, 0), 0.8)


## 捧在身前的幾顆小金光（c1 的光暈貼圖，加亮）
func _give_jewels(e: Node2D) -> void:
	for i in JEWELS:
		var s := Sprite2D.new()
		s.texture = FxKit.glow_texture(64)
		s.material = FxKit.add_material()
		s.scale = Vector2.ONE * JEWEL_D / 64.0
		s.modulate = FxKit.GOLD
		s.position = JEWEL_AT + Vector2((i - 1) * 9.0, (i % 2) * 6.0)
		e.add_child(s)


func end_state(f) -> void:
	f._apply_lights()  # 直接到最暗、假光全滅（看完時演出裡已淡出）
	f.boss.deactivate(true)
	f.scenery.set_dead(true)
	f.palace.couple_static = false
	for n in f.couple:
		n.visible = false
