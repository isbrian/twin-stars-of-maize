extends "res://tests/base_test.gd"
# MV-RELEASE-002：發行版不跑自測、不寫 Boss 戰紀錄（規格 R2-3）。

const DIR := "user://selftest_release2"


func test_selftest_only_in_debug() -> void:
	var args := PackedStringArray(["--self-test"])
	check(LaunchArgs.parse(args, true).mode == "selftest", "開發版：--self-test 進自測")
	check(LaunchArgs.parse(args, false).mode == "title", "發行版：忽略 --self-test，進主選單")


func test_unopened_log_close_writes_nothing() -> void:
	var path := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(path)
	var before := DirAccess.get_files_at(path).size()
	var log = FightLog.new()
	log.add(1.0, "setup")
	log.close(2.0, "quit")
	check(log.closed and log.events.size() == 2, "沒開檔時事件照樣記在記憶體")
	check(log.path_base.is_empty() and DirAccess.get_files_at(path).size() == before, "沒開檔時 close() 不寫檔")
	DirAccess.remove_absolute(path)


func test_boss_fight_without_log_writes_nothing() -> void:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tester = "selftest"
	f.log_dir = DIR + "/fight"
	f.write_log = false
	f.player_scripted = true
	add_child(f)
	await frames(3)
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(f.log_dir)), "write_log=false：不建資料夾、不開檔")
	f._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(f.log_dir)), "離開時也不寫摘要")
	f.queue_free()
	await frames(2)
