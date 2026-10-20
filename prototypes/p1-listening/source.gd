extends Node2D
# 外觀完全相同的灰盒方塊；聆聽時才發出所屬類別的聲音並浮現聲紋。
# 聲紋只用形狀與動態區分、全部同色（兼顧色盲，見 PRESENTATION.md 議題 18）。

const SoundBank := preload("res://sound_bank.gd")

var kind := "alive"
var listening := false  # 由 main 每幀設定
var muted := false  # 靜音模式：只看聲紋
var proximity := 0.0  # 0～1，越靠近越大（危險聲紋用）
var answered := false
var focus := 1.0  # 由 main 設定：站在這個方塊前為 1，其他方塊壓低，避免互相干擾

var _t := 0.0
var _gain := 0.0
var _vis := 0.0
var _audio: AudioStreamPlayer2D
var _print_node: Node2D  # 聲紋畫在去色層之上的圖層，才不會被調暗


func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.max_distance = 700.0
	_audio.attenuation = 2.0
	add_child(_audio)
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.follow_viewport_enabled = true
	add_child(layer)
	_print_node = Node2D.new()
	_print_node.draw.connect(_draw_print)
	layer.add_child(_print_node)


func set_kind(new_kind: String, stream: AudioStreamWAV) -> void:
	kind = new_kind
	answered = false
	_t = 0.0
	_audio.stream = stream
	_audio.play()


func _process(delta: float) -> void:
	_t += delta
	var audible := listening and not muted
	_gain = move_toward(_gain, (1.0 if audible else 0.0) * focus, delta * 4.0)
	_audio.volume_db = linear_to_db(maxf(_gain, 0.0001))
	_vis = move_toward(_vis, 1.0 if listening else 0.0, delta * 4.0)
	_print_node.position = global_position
	_print_node.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-30, -80, 60, 80), Color(0.45, 0.45, 0.45))
	if answered:
		draw_rect(Rect2(-30, -80, 60, 80), Color(1, 1, 1, 0.6), false, 2.0)


func _draw_print() -> void:
	var n := _print_node
	if _vis < 0.01:
		return
	var col := Color(1, 1, 1, _vis)
	var center := Vector2(0, -40)
	var cycle: float = SoundBank.LENGTHS[kind]
	var c := fmod(_t, cycle)
	match kind:
		"alive":  # 同心圓隨心跳脈動
			var pulse := exp(-c * 6.0)
			if c > 0.22:
				pulse += 0.7 * exp(-(c - 0.22) * 6.0)
			for k in 3:
				n.draw_arc(center, 50.0 + k * 22.0 + pulse * 18.0, 0.0, TAU, 48, Color(1, 1, 1, _vis * (1.0 - k * 0.3)), 3.0)
		"real":  # 平滑、穩定的波浪環
			var pts_real := PackedVector2Array()
			for i in 65:
				var ang := TAU * i / 64.0
				var r := 70.0 + 6.0 * sin(ang * 6.0 + _t * 2.0)
				pts_real.append(center + Vector2(cos(ang), sin(ang)) * r)
			n.draw_polyline(pts_real, col, 3.0)
		"fake":  # 斷裂虛線環會閃爍，並延遲浮出第二圈（回聲）
			var flick := 1.0 if c < 0.3 else 0.35
			for i in 12:
				var a0 := TAU * i / 12.0
				n.draw_arc(center, 60.0, a0, a0 + TAU / 24.0, 6, Color(1, 1, 1, _vis * flick), 3.0)
			if c > 0.18 and c < 0.6:
				for i in 12:
					var a1 := TAU * i / 12.0 + 0.13
					n.draw_arc(center, 85.0, a1, a1 + TAU / 30.0, 6, Color(1, 1, 1, _vis * 0.35), 2.0)
		"danger":  # 旋轉的尖刺星形，越靠近越大
			var pts_danger := PackedVector2Array()
			for i in 21:
				var ang := _t * 1.5 + PI * i / 10.0
				var r := (60.0 if i % 2 == 0 else 35.0) * (1.0 + proximity * 0.8)
				pts_danger.append(center + Vector2(cos(ang), sin(ang)) * r)
			n.draw_polyline(pts_danger, col, 3.0)
		"echo":  # 殘影：方塊輪廓的淡色複本往左上漂移、漸強後驟停；無聲段留一個很淡的輪廓
			var swell: float = SoundBank.ECHO_SWELL
			var p := c / swell if c < swell else 0.0
			for k in 3:
				var off := (k + 1) * (10.0 + 30.0 * p)
				var alpha := 0.0
				if c < swell:
					alpha = (0.15 + 0.6 * p) * (1.0 - k * 0.3)
				elif k == 0:
					alpha = 0.12
				if alpha > 0.0:
					n.draw_rect(Rect2(-30.0 - off, -80.0 - off * 0.3, 60.0, 80.0), Color(1, 1, 1, _vis * alpha), false, 2.0)
