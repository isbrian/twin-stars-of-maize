extends RefCounted
# Boss 戰測試日誌（MV-PROTO-003 規格書第 7 節、PROTO3-5、計畫 D7）：
# 每次進 Boss 戰寫一份 <代號>_<YYYYMMDD_HHMMSS>.jsonl（每行一筆事件）；離開時另寫同名 .md 摘要。
# 摘要由純邏輯 summarize() 從事件清單算出。

const STALL_SECONDS := 60.0
const PROGRESS := ["gauge_full", "glow_hit", "setup"]  # 「有進展」的事件；換段一定伴隨 setup

var events: Array = []
var tester := ""
var stamp := ""
var keep_phase := false
var path_base := ""  # 不含副檔名
var closed := false
var _file: FileAccess


func open(p_tester: String, p_stamp: String, dir: String) -> Error:
	tester = p_tester
	stamp = p_stamp
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	path_base = "%s/%s_%s" % [dir, tester, stamp]
	_file = FileAccess.open(path_base + ".jsonl", FileAccess.WRITE)
	return OK if _file != null else FileAccess.get_open_error()


func add(t: float, type: String, data := {}) -> void:
	if closed:
		return
	var ev := {"t": t, "type": type}
	ev.merge(data)
	events.append(ev)
	if _file != null:
		_file.store_line(JSON.stringify(ev))
		_file.flush()


## 離開 Boss 戰：end_type 為 "clear" 或 "quit"；只生效一次
func close(t: float, end_type: String) -> void:
	if closed:
		return
	add(t, end_type)
	closed = true
	if _file != null:
		_file.close()
	var md := FileAccess.open(path_base + ".md", FileAccess.WRITE)
	if md != null:
		md.store_string(summary_markdown(t))
		md.close()


static func summarize(evs: Array, end_t: float) -> Dictionary:
	var deaths := 0
	var cleared := false
	var phase_attempts := [0, 0, 0]
	var phase_time := [0.0, 0.0, 0.0]
	var counts := {}
	var open_phase := 0
	var open_t := 0.0
	for e in evs:
		counts[e.type] = counts.get(e.type, 0) + 1
		match e.type:
			"attempt_start":
				open_phase = e.phase
				open_t = e.t
				phase_attempts[open_phase - 1] += 1
			"death", "setup", "clear", "quit":
				deaths += 1 if e.type == "death" else 0
				cleared = cleared or e.type == "clear"
				if open_phase > 0:
					phase_time[open_phase - 1] += e.t - open_t
					open_phase = 0
	if open_phase > 0:
		phase_time[open_phase - 1] += end_t - open_t
	var stalls := []
	if not evs.is_empty():
		var pts := [evs[0].t]
		for e in evs:
			if e.type in PROGRESS:
				pts.append(e.t)
		pts.append(end_t)
		for i in range(1, pts.size()):
			if pts[i] - pts[i - 1] > STALL_SECONDS:
				stalls.append({"from": pts[i - 1], "to": pts[i], "phase": _phase_before(evs, pts[i])})
	return {"attempts": deaths + 1, "deaths": deaths, "cleared": cleared, "phase_attempts": phase_attempts,
		"phase_time": phase_time, "stalls": stalls, "counts": counts}


## t 之前最後一筆帶段的事件的段（計畫 D7）
static func _phase_before(evs: Array, t: float) -> int:
	var ph := 0
	for e in evs:
		if e.t < t and e.has("phase"):
			ph = e.phase
	return ph


func summary_markdown(end_t: float) -> String:
	var s := summarize(events, end_t)
	var result := "通關" if s.cleared else ("中途離開" if closed else "進行中")
	var lines := PackedStringArray([
		"# Boss 戰測試日誌摘要：%s" % tester, "",
		"- 開始：%s" % stamp,
		"- 段落保留：%s" % ("開" if keep_phase else "關"),
		"- 結果：%s" % result,
		"- 總嘗試次數：%d（死亡 %d 次）" % [s.attempts, s.deaths], "",
		"## 各段", "", "| 段 | 嘗試 | 累計時間（秒） |", "|---|---|---|",
	])
	for i in 3:
		lines.append("| %d | %d | %.1f |" % [i + 1, s.phase_attempts[i], s.phase_time[i]])
	lines.append_array(["", "## 超過 60 秒沒有進展", ""])
	if s.stalls.is_empty():
		lines.append("（無）")
	else:
		lines.append_array(["| 起（秒） | 訖（秒） | 段 |", "|---|---|---|"])
		for st in s.stalls:
			lines.append("| %.1f | %.1f | %d |" % [st.from, st.to, st.phase])
	lines.append_array(["", "## 事件次數", "", "| 事件 | 次數 |", "|---|---|"])
	for k in s.counts:
		lines.append("| %s | %d |" % [k, s.counts[k]])
	return "\n".join(lines) + "\n"


static func stamp_from(dt: Dictionary) -> String:
	return "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]


## 測試者代號轉成安全的檔名片段；空的用 anon
static func safe_name(code: String) -> String:
	var out := code.strip_edges()
	for ch in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		out = out.replace(ch, "_")
	return out if out != "" else "anon"
