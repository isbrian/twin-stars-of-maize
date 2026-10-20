extends RefCounted
# 天亮（MV-SLICE-001c3a，SLICE-c3-10）：撿起球具 → 淡出 →「第二天早上」→ 祖母家變回白天、祖母醒來 → 淡入 → gear_obtained。

const TEXT := "第二天早上，兄弟倆出發了。"


func play(cs) -> void:
	var r = cs.host.room
	await cs.fade_to_black(0.8)
	await cs.narrate(TEXT)
	if r.scenery != null:
		r.scenery.night = false
	else:
		r.modulate = Color.WHITE
	r.npc_asleep = false
	await cs.wait(0.5)
	await cs.fade_in(0.8)
	await cs.wait(0.3)


func end_state(host) -> void:
	host.gs.set_flag("gear_obtained")
	host.runner.apply_night(host.room)
	host.room.npc_asleep = false
