extends RefCounted
# 地面房間的舞台（MV-SLICE-001c3a，SLICE-c3-13）：交給 cutscene.gd 的 host（同 BossFight 的欄位，boss 為 null）。
# 演出腳本的 end_state(host) 另外用 room、gs、runner 設旗標、夜晚與房間狀態。

var player
var boss = null
var world: Node  # 凍結的節點＝房間（過場節點本身設成 PROCESS_MODE_ALWAYS）
var scenery
var camera: Camera2D
var hud
var room
var gs
var runner


static func of(p_room, p_runner) -> RefCounted:
	var st = new()
	st.room = p_room
	st.player = p_room.player
	st.world = p_room
	st.scenery = p_room.scenery
	st.camera = p_room.camera
	st.runner = p_runner
	st.gs = p_runner.gs
	st.hud = p_runner.hud
	return st
