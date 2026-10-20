extends RefCounted
# 招架紀錄（MV-PROTO-002 規格書第 8 節、驗收 2）：每按一次招架記一筆，依「從遊戲啟動算起的第 N 分鐘」分段。
# 純邏輯；時間由呼叫端傳入，方便測試。

enum Result { SUCCESS, WHIFF, UNPARRYABLE }

var _entries: Array = []  # [t_sec, result]


func record(t_sec: float, result: int) -> void:
	_entries.append([t_sec, result])


## 第 1 分鐘到最後一個有紀錄的分鐘，每分鐘一列（沒有嘗試的分鐘也列）
func minute_rows() -> Array:
	var rows: Array = []
	for e in _entries:
		var m: int = floori(e[0] / 60.0) + 1
		while rows.size() < m:
			rows.append({"minute": rows.size() + 1, "attempts": 0, "successes": 0})
		rows[m - 1].attempts += 1
		if e[1] == Result.SUCCESS:
			rows[m - 1].successes += 1
	return rows


func report() -> String:
	var lines := PackedStringArray(["| 分鐘 | 嘗試 | 成功 | 成功率 |", "|---|---|---|---|"])
	for r in minute_rows():
		var rate := "—" if r.attempts == 0 else "%d%%" % roundi(100.0 * r.successes / r.attempts)
		lines.append("| %d | %d | %d | %s |" % [r.minute, r.attempts, r.successes, rate])
	var unparryable := 0
	for e in _entries:
		if e[1] == Result.UNPARRYABLE:
			unparryable += 1
	lines.append("")
	lines.append("被不可招架打到：%d 次" % unparryable)
	return "\n".join(lines)
