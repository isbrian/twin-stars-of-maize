extends RefCounted
# 啟動參數解析（放在 -- 之後；MV-PROTO-003 計畫 D11）。獨立成檔：main.gd 已 preload 測試檔，測試不能再 preload main.gd。

const FightLog := preload("res://boss/fight_log.gd")
const ROOM_DEMOS := ["--demo", "--demo-pit", "--demo-explore", "--demo-parry"]
const BOSS_DEMOS := {"--demo-boss-intro": 0, "--demo-boss-flash": 1, "--demo-boss-p3": 3}


## 回傳 {"mode": "selftest"|"room"|"boss"|"menu", "demo": String, "tester": String, "boss_phase": int}
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {"mode": "menu", "demo": "", "tester": "anon", "boss_phase": 0}
	var i := args.find("--tester")
	if i >= 0 and i + 1 < args.size():
		out.tester = FightLog.safe_name(args[i + 1])
	if "--self-test" in args:
		out.mode = "selftest"
		return out
	for d in ROOM_DEMOS:
		if d in args:
			out.mode = "room"
			out.demo = d
			return out
	for d in BOSS_DEMOS:
		if d in args:
			out.mode = "boss"
			out.demo = d
			out.boss_phase = BOSS_DEMOS[d]
			return out
	i = args.find("--boss-phase")
	if i >= 0:
		out.mode = "boss"
		if i + 1 < args.size() and args[i + 1].is_valid_int() and int(args[i + 1]) >= 1 and int(args[i + 1]) <= 4:
			out.boss_phase = int(args[i + 1])
	elif "--boss" in args:
		out.mode = "boss"
	return out
