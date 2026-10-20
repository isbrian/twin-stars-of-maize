extends RefCounted
# 盲測的純邏輯：類別表、出題、彙總、判定。不碰畫面、不碰檔案。
# 類別、鍵位、一句話說明照規格書第 1 節（前五類沿用 P1）。

const VARIANTS := 3
const PASS_RATE := 0.8
const MIN_TESTERS := 1  # MV-PROTO-000 PROTO-3 變更（2026-10-05）：Brian 獨自盲測
const TELLS := ["tell_parry", "tell_heavy"]

## 作答類別，依鍵位順序
const CATEGORIES := [
	{"key": 1, "id": "alive", "label": "活物", "hint": "活的東西，有心跳"},
	{"key": 2, "id": "real", "label": "真實", "hint": "真實的東西，會共振"},
	{"key": 3, "id": "fake", "label": "虛假", "hint": "假的東西，裡面是空的"},
	{"key": 4, "id": "danger", "label": "危險", "hint": "危險的東西，會一直低鳴"},
	{"key": 5, "id": "echo", "label": "殘響", "hint": "死者留下的、倒著傳來的嘆息"},
	{"key": 6, "id": "tell_parry", "label": "前兆（可招架）", "hint": "攻擊前的蓄力聲，可以擋"},
	{"key": 7, "id": "tell_heavy", "label": "前兆（不可招架）", "hint": "攻擊前的蓄力聲，結尾多一記重擊，擋不住"},
]
## 聲音（檔名代號）→ 正確類別；順序即彙總與試聽的順序
const SOUNDS := {
	"alive": "alive", "real": "real", "hollow": "fake", "glass": "fake",
	"danger": "danger", "echo": "echo", "tell_parry": "tell_parry", "tell_heavy": "tell_heavy",
}
const SOUND_LABELS := {
	"alive": "活物", "real": "真實", "hollow": "虛假（木）", "glass": "虛假（假光）",
	"danger": "危險", "echo": "殘響", "tell_parry": "前兆（可招架）", "tell_heavy": "前兆（不可招架）",
}


static func file_name(sound: String, variant: int) -> String:
	return "sfx_voc_%s_%02d.wav" % [sound, variant]


static func all_files() -> Array:
	var out := []
	for s in SOUNDS:
		for v in range(1, VARIANTS + 1):
			out.append(file_name(s, v))
	return out


## only 為空＝全部 24 個；否則只取指定聲音的檔案（重做後只重測該類，規格書驗收 3）
static func files_for(only: Array) -> Array:
	return all_files() if only.is_empty() else all_files().filter(func(f): return sound_of(f) in only)


## 「--only real,glass」→ ["real", "glass"]；沒給回傳 []；缺值或有未知名稱回傳 null
static func parse_only(args: PackedStringArray) -> Variant:
	var i := args.find("--only")
	if i == -1:
		return []
	if i + 1 >= args.size():
		return null
	var out := Array(args[i + 1].split(",", false))
	return out if out.all(func(x): return SOUNDS.has(x)) else null


static func sound_of(file: String) -> String:
	return file.trim_prefix("sfx_voc_").get_basename().left(-3)  # 去掉 "_0N"


static func category_for_key(key: int) -> String:
	for c in CATEGORIES:
		if c.key == key:
			return c.id
	return ""


static func category_label(id: String) -> String:
	for c in CATEGORIES:
		if c.id == id:
			return c.label
	return ""


## 每個檔案各一次（預設 24 個，only 指定時只取那些聲音），依種子打亂（Fisher–Yates）
static func make_trials(seed: int, only: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := files_for(only)
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## 一題的作答列（CSV 的一列）
static func make_row(tester: String, session: String, trial: int, file: String, guess: String, replays: int, seconds: float) -> Dictionary:
	var sound := sound_of(file)
	var actual: String = SOUNDS[sound]
	return {
		"tester": tester, "session": session, "trial": trial, "file": file, "sound": sound,
		"actual": actual, "guess": guess, "correct": guess == actual, "replays": replays, "seconds": seconds,
	}


static func _tell_danger(actual: String, guess: String) -> bool:
	return (actual in TELLS and guess == "danger") or (actual == "danger" and guess in TELLS)


## 彙總：每種聲音正確率、混淆表、前兆↔危險誤判、通過判定。底線開頭的受測者略過；
## only 指定時，範圍外的聲音標為未測（tested=false），不列入重做與判定
static func summarize(rows: Array, only: Array = []) -> Dictionary:
	var sessions := {}  # "tester|session" → 受測者表的一筆
	var sounds := {}
	var confusion := {}
	for s in SOUNDS:
		sounds[s] = {"correct": 0, "total": 0, "rate": 0.0, "pass": false, "replays": 0, "seconds": 0.0, "tested": only.is_empty() or s in only}
		confusion[s] = {}
		for c in CATEGORIES:
			confusion[s][c.id] = 0
	var tell_danger := 0
	var tell_swap := 0
	var redo_extra := {}
	for r in rows:
		if String(r.tester).begins_with("_"):
			continue
		var key := "%s|%s" % [r.tester, r.session]
		if not sessions.has(key):
			sessions[key] = {"tester": r.tester, "session": r.session, "answered": 0, "correct": 0, "complete": false}
		sessions[key].answered += 1
		var st: Dictionary = sounds[r.sound]
		st.total += 1
		st.replays += r.replays
		st.seconds += r.seconds
		if r.correct:
			st.correct += 1
			sessions[key].correct += 1
		confusion[r.sound][r.guess] += 1
		if _tell_danger(r.actual, r.guess):
			tell_danger += 1
			redo_extra[r.sound] = true
		elif r.actual in TELLS and r.guess in TELLS and r.actual != r.guess:
			tell_swap += 1
	var redo := []
	for s in SOUNDS:
		var st: Dictionary = sounds[s]
		var n: int = st.total
		st.rate = float(st.correct) / n if n > 0 else 0.0
		st.pass = n > 0 and st.rate >= PASS_RATE
		st["mean_replays"] = float(st.replays) / n if n > 0 else 0.0
		st["mean_seconds"] = st.seconds / n if n > 0 else 0.0
		st.erase("replays")
		st.erase("seconds")
		if st.tested and (not st.pass or redo_extra.has(s)):
			redo.append(s)
	var complete_names := {}
	for k in sessions:
		sessions[k].complete = sessions[k].answered >= files_for(only).size()
		if sessions[k].complete:
			complete_names[sessions[k].tester] = true
	var verdict := "insufficient"
	if complete_names.size() >= MIN_TESTERS:
		verdict = "pass" if redo.is_empty() else "fail"
	return {
		"testers": sessions.values(), "sounds": sounds, "confusion": confusion,
		"tell_danger": tell_danger, "tell_swap": tell_swap,
		"complete_testers": complete_names.size(), "redo": redo, "verdict": verdict, "only": only,
	}
