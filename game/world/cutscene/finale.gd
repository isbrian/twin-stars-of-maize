extends RefCounted
# 結尾（MV-SLICE-001c2c，SLICE-c2c-11）：走上出口高台。兩兄弟在高台頂端回頭望宮殿（地上是他的身體）
# → 旁白 → 轉身往右走出畫面、淡出到黑。黑畫面保持到換房（keep_black），接著是出口房間的結束畫面。

const Palace := preload("res://core/boss/palace_arena.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")

const N1 := "七金剛鸚鵡的驕傲被拿走了。"
const VIEW := Rect2(15100, Palace.GROUND_Y - 960, 1920, 1080)  # 高台與宮殿右半（含地上的身體）
const TWIN_GAP := 90.0
const EDGE := 40.0  # 替身離高台兩端至少這麼遠
const OUT_X := Palace.EXIT_RIGHT + 200.0
const FADE_DELAY := 0.5
const FADE_SECS := 1.0

var keep_black := true


func play(cs) -> void:
	var f = cs.host
	cs.view(VIEW)
	var lo := Palace.EXIT_LEDGE.position.x + EDGE
	var hi := Palace.EXIT_RIGHT - EDGE
	var top := Palace.EXIT_LEDGE.position.y
	var me_x := clampf(f.player.position.x, lo + TWIN_GAP, hi)
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[f.player.twin_index], Vector2(me_x, top))
	var other: Node2D = cs.spawn(TwinAnimator.CHARS[1 - f.player.twin_index], Vector2(me_x - TWIN_GAP, top))
	for a in [me, other]:
		a.facing = -1  # 回頭望宮殿
	await cs.narrate(N1)
	await cs.together([cs.walk.bind(me, OUT_X), cs.walk.bind(other, OUT_X - TWIN_GAP), _fade_out.bind(cs)])


func _fade_out(cs) -> void:
	await cs.wait(FADE_DELAY)
	await cs.fade_to_black(FADE_SECS)


func end_state(_f) -> void:
	pass
