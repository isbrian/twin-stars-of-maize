extends RefCounted
# 紀錄與彙總：受測者代號清理、每人一個 CSV（每答一題寫一列）、讀回全部 CSV、產生 Markdown。

const Quiz := preload("res://quiz.gd")
const DIR := "res://results"
const COLUMNS := ["tester", "session", "trial", "file", "sound", "actual", "guess", "correct", "replays", "seconds"]


## 只保留可當檔名的字元；全空白回空字串（呼叫端改用時間）。
## 開頭不可是「.」（隱藏檔，彙總讀不到）；開頭的「_」只保留給原本就這樣打的主持人代號
static func sanitize_tester(name: String) -> String:
	var raw := name.strip_edges()
	# ponytail: stdlib: String.validate_filename() 替換路徑字元 | upgrade if: 要限制成英數
	var s := raw.validate_filename().replace(" ", "_").lstrip(".")
	if not raw.begins_with("_"):
		s = s.lstrip("_.")
	return s


static func session_stamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]


static func session_path(dir: String, tester: String, session: String) -> String:
	return dir.path_join("%s_%s.csv" % [tester, session])


## 寫一列；檔案不存在時先寫標題列
static func append_row(path: String, row: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var is_new := not FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.seek_end()
	if is_new:
		f.store_csv_line(PackedStringArray(COLUMNS))
	f.store_csv_line(PackedStringArray([
		row.tester, row.session, str(row.trial), row.file, row.sound, row.actual, row.guess,
		"1" if row.correct else "0", str(row.replays), "%.2f" % row.seconds,
	]))
	return f.get_error()


## 讀 dir 下所有 .csv；壞列放進 skipped（"檔名:行號"，行號含標題列、從 1 起算）
static func read_dir(dir: String) -> Dictionary:
	var out := {"rows": [], "skipped": [], "files": 0}
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var ids: Array = Quiz.CATEGORIES.map(func(c): return c.id)
	var names := Array(DirAccess.get_files_at(dir)).filter(func(n): return n.get_extension() == "csv")
	names.sort()
	for n in names:
		out.files += 1
		var f := FileAccess.open(dir.path_join(n), FileAccess.READ)
		var line := 0
		while not f.eof_reached():
			var c := f.get_csv_line()
			line += 1
			if c.size() == 1 and c[0] == "":
				continue
			if line == 1 and c[0] == "tester":
				continue
			if c.size() != COLUMNS.size() or not c[2].is_valid_int() or not c[7] in ["0", "1"] \
					or not Quiz.SOUNDS.has(c[4]) or not c[6] in ids or not c[8].is_valid_int() or not c[9].is_valid_float():
				out.skipped.append("%s:%d" % [n, line])
				continue
			out.rows.append({
				"tester": c[0], "session": c[1], "trial": c[2].to_int(), "file": c[3], "sound": c[4],
				"actual": c[5], "guess": c[6], "correct": c[7] == "1", "replays": c[8].to_int(), "seconds": c[9].to_float(),
			})
	return out


static func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100.0)


static func render_markdown(s: Dictionary) -> String:
	var L := PackedStringArray(["# MV-PROTO-005 聲音語彙盲測彙總", ""])
	L.append_array(["## 受測者", "", "| 代號 | 場次 | 答題數 | 正確率 | 完成 |", "|---|---|---|---|---|"])
	var total := Quiz.files_for(s.get("only", [])).size()
	for t in s.testers:
		L.append("| %s | %s | %d/%d | %s | %s |" % [t.tester, t.session, t.answered, total, _pct(float(t.correct) / t.answered), "是" if t.complete else "未完成"])
	L.append_array(["", "## 每種聲音", "", "| 聲音 | 正確類別 | 答對／題數 | 正確率 | ≥ 80% | 平均重播 | 平均秒數 |", "|---|---|---|---|---|---|---|"])
	for snd in Quiz.SOUNDS:
		var x: Dictionary = s.sounds[snd]
		if not x.tested:
			L.append("| %s | %s | — | — | 未測 | — | — |" % [Quiz.SOUND_LABELS[snd], Quiz.category_label(Quiz.SOUNDS[snd])])
			continue
		L.append("| %s | %s | %d/%d | %s | %s | %.1f | %.1f |" % [Quiz.SOUND_LABELS[snd], Quiz.category_label(Quiz.SOUNDS[snd]), x.correct, x.total, _pct(x.rate), "✅" if x.pass else "❌", x.mean_replays, x.mean_seconds])
	var head := "| 聲音＼作答 |"
	var sep := "|---|"
	for c in Quiz.CATEGORIES:
		head += " %s |" % c.label
		sep += "---|"
	L.append_array(["", "## 混淆表", "", head, sep])
	for snd in Quiz.SOUNDS:
		var line := "| %s |" % Quiz.SOUND_LABELS[snd]
		for c in Quiz.CATEGORIES:
			line += " %d |" % s.confusion[snd][c.id]
		L.append(line)
	L.append_array(["", "## 前兆與危險", "",
		"- 前兆↔危險誤判：%d 次（必須為 0）" % s.tell_danger,
		"- 前兆兩變體互相誤判：%d 次（已計入正確率，供參考）" % s.tell_swap])
	L.append_array(["", "## 結論", ""])
	match s.verdict:
		"pass":
			L.append("**通過**")
		"fail":
			L.append("**不通過**：重做 " + "、".join(PackedStringArray(s.redo.map(func(x): return Quiz.SOUND_LABELS[x]))))
		_:
			L.append("**樣本不足**：完成 %d 題的受測者 %d 位，至少要 %d 位" % [total, s.complete_testers, Quiz.MIN_TESTERS])
	return "\n".join(L) + "\n"
