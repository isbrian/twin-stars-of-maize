extends RefCounted
# 把 GameState 套到角色身上（MV-SLICE-001a Task 3）：武器、血量、治療次數、熱湯、技能回充、覺醒。
# 角色每次換房都會重建，換房前用 store() 把血量寫回 GameState。

const Player := preload("res://core/player/player.gd")
const SkillUser := preload("res://core/player/skill_user.gd")
const TwinAnimator := preload("res://world/twin_animator.gd")


## 建角色並在它 _ready 之後套上 gs（health 在 _ready 才建立）
static func make_player(gs, tn) -> Node:
	var p := Player.new()
	p.tn = tn
	p.ready.connect(func():
		apply(p, gs)
		TwinAnimator.attach(p)  # MV-SLICE-001b2a：骨架與動作（取代 b1 的靜態立繪）
		p.portrait_drawn = true, CONNECT_ONE_SHOT)
	return p


static func apply(player, gs) -> void:
	apply_weapons(player, gs)
	player.health.max_hp = gs.max_hp_now()  # 血量碎片（MV-SLICE-001c4a）
	player.health.hp = gs.hp
	player.health.heal_charges = gs.heal_charges
	player.abilities_enabled = gs.awakened
	player.soup_source = gs
	if not player.hit_landed.is_connected(gs.on_weapon_hit_from):
		player.hit_landed.connect(gs.on_weapon_hit_from)
	if not player.has_node("SkillUser"):
		var su := SkillUser.new()
		su.name = "SkillUser"
		su.gs = gs
		player.add_child(su)


## 只套武器（Boss 段落死亡重試時 respawn 會把武器重置回原型預設）
static func apply_weapons(player, gs) -> void:
	for i in 2:
		var t = player.twins[i]
		if gs.equip[i] == -1:
			t.weapon_enabled = false
		else:
			t.weapon = gs.equip[i]
			t.weapon_enabled = true


static func store(player, gs) -> void:
	gs.hp = player.health.hp
	gs.heal_charges = player.health.heal_charges
