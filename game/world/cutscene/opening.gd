extends RefCounted
# 開場（MV-SLICE-001c2a，SLICE-c2-9～11；MV-BOSS-001 BOSS-9d）：第一次進 nance 場地。
# 雙胞胎走進前景草叢蹲下 → 旁白 → 他飛到低枝、下顎微亮地吃果子 → 察覺、展翅，兩人跳出 → 名號 → 他飛回樹冠，開打。

const Nance := preload("res://core/boss/nance_arena.gd")
const Light := preload("res://core/boss/light_source.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")

const HIDE_X := Nance.LEFT + 520.0  # 前景草叢（操作中的那位）；另一位在左邊 TWIN_GAP
const TWIN_GAP := 90.0
const NARRATION := "七金剛鸚鵡每天飛到 nance 樹上吃果子。兄弟倆躲在樹下的葉叢裡，等著他。"
const BOSS_NAME := "七金剛鸚鵡"
const EPITHET := "自稱是太陽，也是月亮"
const SKY := Vector2(Nance.PERCH.x + 300.0, Nance.VIEW.position.y - 400.0)  # 從畫面上方飛來
const EAT_SECS := 1.5


func play(cs) -> void:
	var f = cs.host
	cs.view(Nance.VIEW)
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[f.player.twin_index], Vector2(f.player.position.x, Nance.GROUND_Y))
	var other: Node2D = cs.spawn(TwinAnimator.CHARS[1 - f.player.twin_index], me.position - Vector2(TWIN_GAP, 0))
	cs.walk(other, HIDE_X - TWIN_GAP)
	await cs.walk(me, HIDE_X)
	cs.sfx(&"cs_grass_crouch")  # 蹲進草叢（MV-SLICE-001d1b）
	for t in [me, other]:
		t.facing = 1
		t.play("crouch")
	await cs.narrate(NARRATION)
	var macaw: Node2D = cs.spawn("sevenmacaw", SKY)
	macaw.facing = -1
	var light: Node2D = macaw.add_light()
	await cs.fly(macaw, Nance.PERCH, 1.2)
	macaw.play("eat")
	cs.sfx(&"boss_sm_eat")
	light.state = Light.State.GLOW
	await cs.wait(EAT_SECS)
	light.state = Light.State.OFF
	for t in [me, other]:
		t.play("jump_up")
	await cs.play(macaw, "spread")
	for t in [me, other]:
		t.play("land")
	await cs.title(BOSS_NAME, EPITHET)
	await cs.fly(macaw, Nance.CANOPY, 1.0)


func end_state(f) -> void:
	f.intro_seen = true
	f.player.position = Vector2(HIDE_X, Nance.GROUND_Y)
	f.player.velocity = Vector2.ZERO
	f.boss.park(1)  # 樹冠、光源熄滅；開打由 _enter_arena 接著 _start_fight
