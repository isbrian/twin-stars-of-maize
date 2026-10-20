extends RefCounted
# 第 2 段開場（MV-SLICE-001c2b，SLICE-c2b-1；MV-BOSS-001「第 2 段開場」）：第一次進宮殿。
# 他在寶座前捧著下顎哀嚎、奇瑪瑪特在寶座旁 → 他看見老人身後的兩個孩子，轉身展翅、收翅 → 開打。台詞照 card_text 的 toothache 卡。

const Palace := preload("res://core/boss/palace_arena.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")
const Teeth := preload("res://world/cutscene/teeth.gd")

const N1 := "七金剛鸚鵡坐在寶座邊上，牙痛得不停哭喊。"
const N2 := "奇瑪瑪特在寶座旁。"
const N3 := "他看見老人身後的兩個孩子，猛然站了起來。"
const SIT_X := 15250.0  # 寶座前
const HEAD_JAWHURT := 1
const TWIN_GAP := 90.0
const SPREAD_OPEN := 0.4  # spread 張到最開的時間：收翅從這裡倒著播
const FOLD_SECS := 0.4
const SETTLE := 0.2  # 收翅後站定待機一下再開打（畫面上交還前最後是待機姿勢）


func play(cs) -> void:
	var f = cs.host
	cs.view(Palace.VIEW)
	var me: Node2D = cs.spawn(TwinAnimator.CHARS[f.player.twin_index], Vector2(f.player.position.x, Palace.GROUND_Y))
	cs.spawn(TwinAnimator.CHARS[1 - f.player.twin_index], me.position - Vector2(TWIN_GAP, 0))
	var macaw: Node2D = cs.spawn("sevenmacaw", Vector2(SIT_X, Palace.GROUND_Y))
	macaw.set_head(HEAD_JAWHURT)
	macaw.facing = 1  # 面向寶座
	macaw.play("wail")
	cs.sfx(&"boss_sm_wail")
	await cs.narrate(N1)
	await cs.narrate(N2)
	Teeth.face_player(cs, macaw)  # 轉向入口的孩子
	# 展翅時往後退到起始位置 HOME（面向不變），交還時接得上真正的 Boss
	await cs.together([cs.fly.bind(macaw, Palace.HOME, macaw.anim_length("spread"), "spread", false), cs.narrate.bind(N3)])
	await cs.rewind(macaw, "spread", SPREAD_OPEN, FOLD_SECS)  # 收翅回待機：交還時同真正 Boss 的姿勢
	await cs.wait(SETTLE)


func end_state(f) -> void:
	f.palace_card_seen = true
	f.boss.park(2)  # 在 HOME、面向玩家：同替身最後的樣子
