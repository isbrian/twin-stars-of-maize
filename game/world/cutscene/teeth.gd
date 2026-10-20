extends RefCounted
# 換牙（MV-SLICE-001c2b，SLICE-c2b-3、4；MV-BOSS-001 BOSS-9a）：第 2 段設局成功。
# 他跳到舞台、伏低哀求 → 兩位老人走到他頭前伸手，背影擋住他的嘴，換上白玉米牙 → 老人退回、他起身。台詞照 card_text 的 teeth 卡。

const Palace := preload("res://core/boss/palace_arena.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")

const PLEA := "可憐可憐我，治好我的牙吧。"
const N1 := "老人取出他的牙，換上一粒粒發亮的白玉米。"
const N2 := "他的臉立刻垮了下來，看起來不再像王。"
const STAGE_X := 15100.0  # 他伏低的位置（面向左）
const HEAD_REACH := -220.0  # 伏低時頭相對腳底的 x（面向左）
const ELDER_GAP := 70.0  # 兩位老人在他頭前，相距
const HEAD_JAWHURT := 1
const HEAD_MAIZE := 2
const TWIN_GAP := 90.0
const HOP_SECS := 0.6
const COUPLE_DX := [-45.0, 25.0]  # 同 boss_fight._update_couple：老伯、老婆婆


## 老夫婦替身（真正的老夫婦藏起）；回傳 [老伯, 老婆婆]
static func spawn_elders(cs) -> Array:
	var out := []
	for i in 2:
		cs.conceal(cs.host.couple[i])
		var e: Node2D = cs.spawn(["healer_man", "healer_woman"][i], Vector2(Palace.COUPLE_X + COUPLE_DX[i], Palace.GROUND_Y))
		e.facing = 1
		e.z_index = 1  # 畫在他前面：背影擋住他的臉（SLICE-c2b-3）
		out.append(e)
	return out


## 雙胞胎替身站在真角色的位置
static func spawn_twins(cs) -> void:
	var f = cs.host
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[f.player.twin_index], Vector2(f.player.position.x, Palace.GROUND_Y))
	cs.spawn(TwinAnimator.CHARS[1 - f.player.twin_index], me.position - Vector2(TWIN_GAP, 0))


## 他跳到舞台、面向左伏低
static func hop_and_bow(cs, macaw: Node2D) -> void:
	await cs.fly(macaw, Vector2(STAGE_X, Palace.GROUND_Y), HOP_SECS)
	macaw.facing = -1
	await cs.play(macaw, "bow")


## 面向玩家（同 SevenMacaw.face_target：交還時接得上真正的 Boss）
static func face_player(cs, macaw: Node2D) -> void:
	var px: float = cs.host.player.global_position.x
	if px != macaw.global_position.x:
		macaw.facing = 1 if px > macaw.global_position.x else -1


## 他飛回起始位置 Palace.HOME、面向玩家、待機（真正的 Boss 第 3 段從這裡開打）
static func hop_home(cs, macaw: Node2D) -> void:
	await cs.fly(macaw, Palace.HOME, HOP_SECS)
	face_player(cs, macaw)
	macaw.play("idle_ground")


## 老人走到他頭前、面向右伸手
static func elders_reach(cs, elders: Array) -> void:
	var head_x := STAGE_X + HEAD_REACH
	await cs.together([cs.walk.bind(elders[0], head_x - ELDER_GAP / 2.0), cs.walk.bind(elders[1], head_x + ELDER_GAP / 2.0)])
	for e in elders:
		e.facing = 1
	await cs.together([cs.play.bind(elders[0], "reach"), cs.play.bind(elders[1], "reach")])


func play(cs) -> void:
	var f = cs.host
	cs.view(Palace.VIEW)
	spawn_twins(cs)
	var elders := spawn_elders(cs)
	var macaw: Node2D = cs.spawn("sevenmacaw", f.boss.position)
	macaw.set_head(HEAD_JAWHURT)
	await hop_and_bow(cs, macaw)
	await cs.say("七金剛鸚鵡", PLEA)
	await elders_reach(cs, elders)
	macaw.set_head(HEAD_MAIZE)  # 老人的背影擋住他的嘴
	cs.sfx(&"evt_cover")  # 老夫婦遮擋畫面（MV-SLICE-001d1a）
	cs.sfx(&"cs_teeth_swap")  # 換上白玉米牙（MV-SLICE-001d1b）
	await cs.narrate(N1)
	await cs.together([
		cs.walk.bind(elders[0], Palace.COUPLE_X + COUPLE_DX[0]),
		cs.walk.bind(elders[1], Palace.COUPLE_X + COUPLE_DX[1]),
		hop_home.bind(cs, macaw),
		cs.narrate.bind(N2),
	])


func end_state(f) -> void:
	f.phase = 3
	f.boss.park(3)  # 在 HOME、面向玩家：同替身最後的樣子（交還到 _start_fight 之間不跳位）
