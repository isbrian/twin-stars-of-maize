extends RefCounted
# 轉場（MV-SLICE-001c2a，SLICE-c2-15、16；MV-BOSS-001 BOSS-7a）：接在斷臂後。
# 小路起點：兩位老人站在路邊，兄弟倆走過去、請他們同行，老人走到兄弟身後；交還操作後帶著他們走到宮殿門口。

const Palace := preload("res://core/boss/palace_arena.gd")

const N := "兄弟倆去找兩位老人：一位頭髮全白，一位彎著腰。"
const HUNAHPU := "請陪我們去七金剛鸚鵡那裡，取回我們的手臂。"
const XBALANQUE := "我們跟在後面，就說是你們的孫子。"
const ELDERS := "好。"
const TWINS_FROM := -600.0  # 相對 PATH_START.x
const ELDERS_AT := 250.0
const TWIN_GAP := 90.0
const COUPLE_BEHIND := 160.0  # 同 boss_fight 的 couple_x
const VIEW := Rect2(Palace.REGION.position.x, Palace.GROUND_Y - 960.0, 1920.0, 1080.0)  # ＝角色在 PATH_START 時戰鬥鏡頭看到的範圍（交還不跳）
const MAN_DX := -45.0  # 同 boss_fight._update_couple 的排法：老伯 couple_x − 45、老婆婆 + 25
const WOMAN_DX := 25.0


func play(cs) -> void:
	cs.sfx(&"voc_alive")  # 老夫婦登場＝活物（MV-SLICE-001d1a）
	var x0: float = Palace.PATH_START.x
	var y: float = Palace.GROUND_Y
	cs.view(VIEW)
	var hu: Node2D = cs.spawn("hunahpu", Vector2(x0 + TWINS_FROM, y))
	hu.rig.set_arm_visible(false)
	var xb: Node2D = cs.spawn("xbalanque", Vector2(x0 + TWINS_FROM - TWIN_GAP, y))
	var man: Node2D = cs.spawn("healer_man", Vector2(x0 + ELDERS_AT, y))
	var woman: Node2D = cs.spawn("healer_woman", Vector2(x0 + ELDERS_AT + 70.0, y))
	for e in [man, woman]:
		e.facing = -1
	await cs.fade_in()
	cs.walk(xb, x0 - TWIN_GAP)
	await cs.walk(hu, x0)
	await cs.narrate(N)
	await cs.say("胡納普", HUNAHPU)
	await cs.say("希巴拉克", XBALANQUE)
	await cs.say("兩位老人", ELDERS)
	cs.walk(woman, x0 - COUPLE_BEHIND + WOMAN_DX)
	await cs.walk(man, x0 - COUPLE_BEHIND + MAN_DX)
	await cs.wait(0.1)
	for a in [man, woman, hu, xb]:
		a.facing = 1
	await cs.wait(0.4)


func end_state(f) -> void:
	f.player.position = Palace.PATH_START
	f.player.velocity = Vector2.ZERO
	f.couple_following = true
	f.couple_x = Palace.PATH_START.x - COUPLE_BEHIND
	f._set_view(Palace.REGION)
	f.stage = f.Stage.APPROACH
