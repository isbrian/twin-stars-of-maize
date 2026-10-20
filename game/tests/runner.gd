extends Node
# --self-test：依檔名載入 tests/test_*.gd，每個檔案的 test_ 方法依名稱排序執行。
# 每項印一行 SELFTEST PASS|FAIL <檔名>.<方法>，最後印 SELFTEST SUMMARY（格式同 prototypes/core）。
# 注意：執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，該項會被記為 PASS，驗證時要另外 grep。
# 開發時只跑部分檔案：環境變數 SELFTEST_ONLY=test_rig（檔名含這段字的才跑；驗收一律全跑）。

const DIR := "res://tests/"

var pass_count := 0
var fail_count := 0


func run() -> void:
	var only := OS.get_environment("SELFTEST_ONLY")
	var files: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and (only.is_empty() or only in f):
			files.append(f)
	files.sort()
	for f in files:
		var scr = load(DIR + f)
		if scr == null or not scr.can_instantiate():
			fail_count += 1
			print("SELFTEST FAIL %s（測試檔無法載入）" % f.get_basename())
			continue
		var t: Node = scr.new()
		add_child(t)
		var names: Array = []
		for m in t.get_method_list():
			if String(m.name).begins_with("test_"):
				names.append(m.name)
		names.sort()
		for n in names:
			t._name = n
			t._failed = false
			await t.call(n)
			if t._failed:
				fail_count += 1
			else:
				pass_count += 1
			print("SELFTEST %s %s.%s" % ["FAIL" if t._failed else "PASS", f.get_basename(), n])
		t.queue_free()
		await get_tree().physics_frame
	print("SELFTEST SUMMARY pass=%d fail=%d" % [pass_count, fail_count])
