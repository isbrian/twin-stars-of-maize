extends RefCounted
# 斷臂（MV-SLICE-001c2a，SLICE-c2-12～14；MV-BOSS-001 BOSS-3）：第 1 段設局成功。
# nance 樹（逆光剪影）：他摔落 → 胡納普撲上去、被叼住手臂一扯、跌坐 → 他叼著手臂飛走；
# 宮殿（正常顏色）：他把手臂掛到火堆上方的繩子上，和奇瑪瑪特對話。台詞照 card_text 的 arm 卡拆開。

const Nance := preload("res://core/boss/nance_arena.gd")
const Palace := preload("res://core/boss/palace_arena.gd")
const ArmProp := preload("res://world/cutscene/arm_prop.gd")

const N1 := "七金剛鸚鵡大叫一聲，從樹頂摔落地面。"
const N2 := "胡納普衝上前去抓他，卻被他扯下了手臂。"
const N3 := "他捧著下顎回到家中，把手臂掛在火上。"
const CHIMALMAT := "你帶了什麼回來？"
const MACAW := "兩個騙子射了我。這條手臂就掛在這裡，等他們來拿回去。"
const HEAD_JAWHURT := 1  # MacawAnimator.HEADS：下顎受傷
const FALL_TO := Vector2(Nance.TREE_X + 250.0, Nance.GROUND_Y)
const REACH := 170.0  # 胡納普停在他前面多遠撲上去
const AWAY := Vector2(Nance.RIGHT + 400.0, Nance.VIEW.position.y - 300.0)
const HANG_FROM := 130.0  # 宮殿：他站在繩結左邊多遠、面向右（奇瑪瑪特在寶座那一側，尾羽不擋她）
const STEP_BACK := 260.0  # 掛好後往左退開，讓手臂露出來


func play(cs) -> void:
	var f = cs.host
	cs.view(Nance.VIEW)
	cs.silhouette(true)
	var macaw: Node2D = cs.spawn("sevenmacaw", f.boss.position)
	macaw.set_head(HEAD_JAWHURT)
	var hu: Node2D = cs.spawn("hunahpu", Vector2(minf(f.player.position.x, FALL_TO.x - 500.0), Nance.GROUND_Y))
	var xb: Node2D = cs.spawn("xbalanque", hu.position - Vector2(120, 0))
	cs.fly(macaw, FALL_TO, 0.7, "fall")
	cs.sfx(&"cs_macaw_fall")  # MV-SLICE-001d1b
	macaw.facing = -1  # 面向衝過來的兄弟（fly 會轉向目的地）
	await cs.narrate(N1)
	macaw.play("down")
	cs.walk(xb, FALL_TO.x - REACH - 260.0, 500.0, "run")
	await cs.walk(hu, FALL_TO.x - REACH, 700.0, "run")
	await cs.play(hu, "lunge")
	cs.sfx(&"cs_wing_wrench")  # 一扯：只用翅膀猛拍，不做撕扯聲（A21-2）
	await cs.play(macaw, "yank")
	hu.rig.set_arm_visible(false)
	macaw.hold(ArmProp.make())
	hu.play("knocked_down")
	cs.sfx(&"cs_sit_fall")
	await cs.narrate(N2)
	macaw.play("wail")
	await cs.wait(0.8)
	await cs.fly(macaw, AWAY, 1.0)
	await cs.fade_to_black()
	# 宮殿
	cs.silhouette(false)
	cs.view(Palace.VIEW)
	for a in [hu, xb]:
		a.visible = false
	macaw.position = Vector2(f.scenery.ROPE_KNOT.x - HANG_FROM, Palace.GROUND_Y)
	macaw.facing = 1
	macaw.play("idle_ground")
	await cs.fade_in()
	await cs.narrate(N3)
	await cs.play(macaw, "hang")
	macaw.release().queue_free()
	f.scenery.set_arm_hung(true)
	await cs.fly(macaw, macaw.position - Vector2(STEP_BACK, 0), 0.5, "idle_ground")  # 退開，讓掛著的手臂露出來
	macaw.facing = 1
	await cs.say("奇瑪瑪特", CHIMALMAT)
	await cs.say("七金剛鸚鵡", MACAW)
	await cs.fade_to_black()


func end_state(f) -> void:
	f.phase = 2
	f._apply_loadout()  # 胡納普斷臂；宮殿掛著手臂
	f.boss.park(2)
