extends RefCounted
# 五類聲音語彙的佔位音效：啟動時用程式合成成可循環的 WAV（見 AUDIO_SPEC.md 第 2 節）。
# ponytail: native: AudioStreamWAV 程式合成 | upgrade if: AUD-002 的正式音效到位，改為載入檔案

const RATE := 22050.0
# 每類的循環長度（秒）；取整數週期，確保循環無縫
const LENGTHS := {"alive": 1.0, "real": 2.0, "fake": 1.6, "danger": 2.0, "echo": 1.8}
const ECHO_SWELL := 1.4  # 殘響的發聲段長度；其餘為短暫無聲


static func build_all() -> Dictionary:
	var bank := {}
	for kind in LENGTHS:
		bank[kind] = _make_wav(kind, LENGTHS[kind])
	return bank


static func _make_wav(kind: String, length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(sample(kind, i / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


# s：循環內的時間（秒）
static func sample(kind: String, s: float) -> float:
	match kind:
		"alive":  # 活物：低頻心跳「咚—咚」
			return _thump(s, 0.0, 55.0) + 0.7 * _thump(s, 0.22, 62.0)
		"real":  # 真實：飽滿共振、自然長尾音
			var env_real := exp(-s * 2.5)
			return env_real * (0.55 * sin(TAU * 220.0 * s) + 0.3 * sin(TAU * 440.0 * s) + 0.15 * sin(TAU * 660.0 * s))
		"fake":  # 虛假：中空木頭的乾短敲擊，帶一次回聲
			return _knock(s) + 0.35 * _knock(s - 0.18)
		"danger":  # 危險：持續低頻嗡聲，帶顫動
			var trem := 0.75 + 0.25 * sin(TAU * 6.0 * s)
			return trem * (0.5 * sin(TAU * 55.0 * s) + 0.25 * sin(TAU * 110.0 * s + 0.3))
		"echo":  # 殘響：倒轉包絡（漸強後驟停），兩個微差頻率形成搖曳
			if s > ECHO_SWELL:
				return 0.0
			var env_echo := pow(s / ECHO_SWELL, 2.0)
			return env_echo * 0.45 * (sin(TAU * 330.0 * s) + sin(TAU * 333.0 * s))
	return 0.0


static func _thump(s: float, start: float, freq: float) -> float:
	var x := s - start
	if x < 0.0 or x > 0.25:
		return 0.0
	return exp(-x * 18.0) * sin(TAU * freq * x)


static func _knock(x: float) -> float:
	if x < 0.0 or x > 0.06:
		return 0.0
	var env := exp(-x * 90.0)
	return env * (0.5 * sin(TAU * 520.0 * x) + 0.35 * (randf() * 2.0 - 1.0))
