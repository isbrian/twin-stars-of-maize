extends RefCounted
# 覺醒（MV-SLICE-001c2c，SLICE-c2c-2～8、16；MV-BOSS-001 BOSS-9c）：接在死亡演出之後（同一次 run）。
# 胡納普走到繩下、用好的那隻手取下手臂 → 逆光剪影裡希巴拉克把手臂扶回哥哥肩上 → 閃回開墾田地 → 兩個能力名。
# 旁白照 card_text 的 awaken 卡。跳過停在這一段的開頭（skip_stop）：跳過死亡的人仍看得到得到什麼能力。

const Palace := preload("res://core/boss/palace_arena.gd")
const Teeth := preload("res://world/cutscene/teeth.gd")
const ArmProp := preload("res://world/cutscene/arm_prop.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")
const Flashback := preload("res://world/cutscene/flashback.gd")

const N1 := "胡納普從火上取回手臂，"
const N2 := "兄弟倆把它裝回原處，手臂完好如初。"
const N3 := "希巴拉克想起開墾田地的那一天："
const N4 := "斧頭自己砍倒了樹，掘棒自己翻開了土。"
const ABILITIES := [["讓工具自己動", "希巴拉克覺醒"], ["二段跳", "胡納普覺醒"]]  # 能力名／稱號（SLICE-c2c-8）
const WHITE_SECS := 0.4
const REACH_DX := 40.0  # 取下時胡納普站在繩結右邊多遠（面向左）
const MEND_GAP := 70.0  # 裝回時希巴拉克站在哥哥左邊多遠（面向右）

var skip_stop := true


func play(cs) -> void:
	var f = cs.host
	Audio.play_music(&"mus_s01")  # 神通覺醒（MV-SLICE-001d1a）
	cs.view(Palace.VIEW)
	var hu: Node2D = cs.cast_of(TwinAnimator.CHARS[0])
	var xb: Node2D = cs.cast_of(TwinAnimator.CHARS[1])
	if hu == null or xb == null:
		Teeth.spawn_twins(cs)
		hu = cs.cast_of(TwinAnimator.CHARS[0])
		xb = cs.cast_of(TwinAnimator.CHARS[1])
	var knot_x: float = f.scenery.ROPE_KNOT.x
	await cs.together([cs.walk.bind(hu, knot_x + REACH_DX), cs.walk.bind(xb, knot_x + REACH_DX + MEND_GAP * 2.0)])
	hu.facing = -1
	await cs.together([_take.bind(cs, f, hu), cs.narrate.bind(N1)])
	cs.silhouette(true)
	await cs.walk(xb, hu.position.x - MEND_GAP)
	xb.facing = 1
	await cs.together([_mend.bind(cs, hu, xb), cs.narrate.bind(N2)])
	cs.silhouette(false)
	# 閃回：白光淡入開墾田地的一角，工具自己工作
	await cs.fade_to_white(WHITE_SECS)
	var fb: Control = Flashback.make()
	cs.show_layer(fb)
	await cs.fade_in(WHITE_SECS)
	await cs.together([fb.play.bind(cs), _lines.bind(cs, [N3, N4])])
	await cs.fade_to_white(WHITE_SECS)
	fb.queue_free()
	await cs.fade_in(WHITE_SECS)
	for a in ABILITIES:
		await cs.title(a[0], a[1])


func _lines(cs, lines: Array) -> void:
	for l in lines:
		await cs.narrate(l)


## 伸手取下：繩上的手臂改成拿在他手上
func _take(cs, f, hu: Node2D) -> void:
	await cs.play(hu, "tool_cast")
	await cs.wait(0.3)
	f.scenery.set_arm_hung(false)
	var arm := ArmProp.make()
	arm.rotation = -hu.facing * PI / 2.0  # 橫著捧在身前、朝他面向（道具原點在肩、往下垂）
	hu.hold(arm, "hand_l")
	hu.play("idle")
	await cs.wait(0.4)


## 扶回肩上：道具收掉、手臂顯示
func _mend(cs, hu: Node2D, xb: Node2D) -> void:
	await cs.play(xb, "heal")
	await cs.wait(0.5)
	var arm: Node2D = hu.release()
	if arm != null:
		arm.queue_free()
	cs.sfx(&"cs_arm_restore")  # 扶回肩上（MV-SLICE-001d1b）
	hu.rig.set_arm_visible(true)
	await cs.wait(0.5)
	xb.play("idle")


func end_state(f) -> void:
	f.player.position = Vector2(f.scenery.ROPE_KNOT.x + REACH_DX - MEND_GAP, Palace.GROUND_Y)  # 同希巴拉克替身最後的位置
	f.player.velocity = Vector2.ZERO
	f.player.facing = 1
	f.finish_awakening()
