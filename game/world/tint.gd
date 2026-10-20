extends RefCounted
# 角色外觀的顏色規則（從 b1 的 portrait.gd 抽出，MV-SLICE-001b2a；立繪在 MV-SLICE-001b2b2 全部換成骨架）：照灰盒的規則。
# 受擊閃白（有 flash_left 的造物）、治療中偏綠、翻滾無敵半透明、受擊無敵閃爍。

const FLASH := Color(1.8, 1.8, 1.8)
const HEAL_TINT := Color(0.6, 1.0, 0.7)  # 治療中（灰盒的身體變綠，Player.State.HEAL）


static func of(actor) -> Color:
	var c := Color.WHITE
	var is_player: bool = actor.has_method("is_roll_invulnerable")
	if is_player and actor.state == actor.State.HEAL:
		c = HEAL_TINT
	var fl = actor.get("flash_left")
	if fl != null and fl > 0.0:
		c = FLASH
	if is_player and actor.is_roll_invulnerable():
		c.a = 0.45
	elif actor.get("health") != null and actor.health.invuln_left > 0.0 and int(actor.health.invuln_left * 15.0) % 2 == 0:
		c.a = 0.3
	return c
