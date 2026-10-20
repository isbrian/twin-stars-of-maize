extends RefCounted
# 佔位音效：啟動時用程式合成（沿用 P1 sound_bank.gd 的做法），只為手感回饋，不代表正式音色。
# ponytail: native: AudioStreamWAV 程式合成 | upgrade if: 正式音效到位，改為載入檔案

const RATE := 22050.0
const LENGTHS := {
	&"swing": 0.09, &"hit": 0.12, &"dart": 0.05, &"interrupt": 0.18,
	&"hurt": 0.2, &"heal": 0.35, &"pogo": 0.14, &"shatter": 0.25,
	# MV-PROTO-002：避開聲音語彙（不用短促上揚＝前兆、持續低平嗡聲＝危險、乾短空洞敲擊＋回聲＝虛假）
	&"swap": 0.14, &"parry": 0.22, &"double_jump": 0.15, &"tool_out": 0.18,
	&"chop": 0.08, &"barrier_break": 0.3, &"thud": 0.12,
}


static func build_all() -> Dictionary:
	var bank := {}
	for sound in LENGTHS:
		bank[sound] = _make(sound, LENGTHS[sound])
	return bank


static func _make(sound: StringName, length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(sample(sound, i / RATE, length), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = data
	return wav


## s：秒；length：總長
static func sample(sound: StringName, s: float, length: float) -> float:
	var env := 1.0 - s / length
	match sound:
		&"swing":  # 揮擊：漸弱的氣流雜音
			return env * env * 0.5 * (randf() * 2.0 - 1.0)
		&"hit":  # 命中：低頻悶擊
			return exp(-s * 30.0) * sin(TAU * 90.0 * s) + 0.2 * exp(-s * 60.0) * (randf() * 2.0 - 1.0)
		&"dart":  # 吹箭：短促的高頻氣音
			return env * 0.4 * sin(TAU * 1400.0 * s) * (0.6 + 0.4 * randf())
		&"interrupt":  # 打斷：兩聲清脆上揚
			var f := 880.0 if s < length / 2.0 else 1320.0
			return env * 0.5 * sin(TAU * f * s)
		&"hurt":  # 受擊：低沉嗡聲
			return env * 0.6 * signf(sin(TAU * 110.0 * s))
		&"heal":  # 治療完成：上滑音
			return env * 0.4 * sin(TAU * (300.0 + 600.0 * s / length) * s)
		&"pogo":  # 彈跳：彈簧聲
			return env * 0.5 * sin(TAU * (500.0 + 300.0 * sin(TAU * 8.0 * s)) * s)
		&"shatter":  # 碎裂：空洞的玻璃雜音（虛假類）
			return env * env * 0.4 * (randf() * 2.0 - 1.0) * sin(TAU * 2400.0 * s)
		&"swap":  # 換人：兩聲下行（不用上揚，避開前兆）
			var f2 := 660.0 if s < length / 2.0 else 440.0
			return env * 0.35 * sin(TAU * f2 * s)
		&"parry":  # 招架成功：明亮的金屬泛音，自然衰減
			return exp(-s * 14.0) * 0.45 * (sin(TAU * 1200.0 * s) + 0.5 * sin(TAU * 1810.0 * s))
		&"double_jump":  # 二段跳：一口短氣流
			return env * env * 0.35 * (randf() * 2.0 - 1.0)
		&"tool_out":  # 工具飛出：帶音高的呼嘯（不上揚）
			return env * 0.3 * (randf() * 2.0 - 1.0) * sin(TAU * 900.0 * s)
		&"chop":  # 工具砍擊：木頭的短擊，沒有回聲
			return exp(-s * 70.0) * (0.6 * sin(TAU * 280.0 * s) + 0.3 * (randf() * 2.0 - 1.0))
		&"barrier_break":  # 木障碎裂：碎裂的雜音
			return env * 0.5 * (randf() * 2.0 - 1.0) * (0.6 + 0.4 * sin(TAU * 35.0 * s))
		&"thud":  # 打在木障上：低沉、短、沒有回聲
			return exp(-s * 45.0) * 0.7 * sin(TAU * 70.0 * s)
	return 0.0
