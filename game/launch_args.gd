extends RefCounted
# 啟動參數解析（放在 -- 之後）。獨立成檔：main.gd 已 preload 測試，測試不能再 preload main.gd。
# MV-SLICE-001a：移除原型的展示模式與測試代號；新增 --room（開發版才生效，由 main.gd 判斷）。
# MV-SLICE-001b1：--shots <資料夾>（截圖模式，同樣只在開發版生效）。
# MV-SLICE-001b2a：--rig-view（雙胞胎的動作展示畫面，同樣只在開發版生效）。
# MV-SLICE-001c1：--fx-view（Boss 特效展示畫面，同樣只在開發版生效；同樣接受 --frames）。
# MV-SLICE-001c2a：--cutscene <名稱>（直接播 Boss 戰的某段演出，同樣只在開發版生效；同樣接受 --frames）。


## 回傳 {"mode": "selftest"|"sound_tour"|"title_tour"|"shots"|"rig_view"|"fx_view"|"cutscene"|"boss"|"room"|"title", "boss_phase": int, "room": String, "shots_dir": String, "frames_dir": String, "cutscene": String}
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {"mode": "title", "boss_phase": 0, "room": "", "shots_dir": "", "frames_dir": "", "cutscene": ""}
	if "--self-test" in args:
		out.mode = "selftest"
		return out
	if "--sound-tour" in args:  # MV-SLICE-001d1a：聲音展示（開發版才生效）
		out.mode = "sound_tour"
		return out
	if "--title-tour" in args:  # MV-SLICE-001d2a：標題畫面展示（開發版才生效）
		out.mode = "title_tour"
		return out
	if "--rig-view" in args or "--fx-view" in args:
		out.mode = "rig_view" if "--rig-view" in args else "fx_view"
		var f := args.find("--frames")
		if f >= 0 and f + 1 < args.size():
			out.frames_dir = args[f + 1]
		return out
	var c := args.find("--cutscene")
	if c >= 0 and c + 1 < args.size():
		out.mode = "cutscene"
		out.cutscene = args[c + 1]
		var f := args.find("--frames")
		if f >= 0 and f + 1 < args.size():
			out.frames_dir = args[f + 1]
		return out
	var s := args.find("--shots")
	if s >= 0:
		if s + 1 < args.size():
			out.mode = "shots"
			out.shots_dir = args[s + 1]
		return out
	var i := args.find("--room")
	if i >= 0:
		if i + 1 < args.size():
			out.mode = "room"
			out.room = args[i + 1]
		return out
	i = args.find("--boss-phase")
	if i >= 0:
		out.mode = "boss"
		if i + 1 < args.size() and args[i + 1].is_valid_int() and int(args[i + 1]) >= 1 and int(args[i + 1]) <= 4:
			out.boss_phase = int(args[i + 1])
	elif "--boss" in args:
		out.mode = "boss"
	return out
