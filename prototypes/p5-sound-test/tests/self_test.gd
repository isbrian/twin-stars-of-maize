extends Node
# --self-test：每個 test_ 開頭的方法是一項測試，依名稱排序執行。
# 執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，驗證時要另外 grep。

const Quiz := preload("res://quiz.gd")
const AudioBank := preload("res://audio_bank.gd")
const Results := preload("res://results.gd")
const TMP := "user://p5_selftest_results"
const QuizScreen := preload("res://quiz_screen.gd")
const CatalogScreen := preload("res://catalog_screen.gd")

var pass_count := 0
var fail_count := 0
var _name := ""
var _failed := false


func run() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m.name).begins_with("test_"):
			names.append(m.name)
	names.sort()
	for n in names:
		_name = n
		_failed = false
		await call(n)
		if _failed:
			fail_count += 1
		else:
			pass_count += 1
		print("SELFTEST %s %s" % ["FAIL" if _failed else "PASS", n])
	print("SELFTEST SUMMARY pass=%d fail=%d" % [pass_count, fail_count])


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		print("SELFTEST   x %s：%s" % [_name, msg])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_s(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ---- Task 1：類別表與音檔 ----

func test_category_table() -> void:
	check(Quiz.CATEGORIES.size() == 7, "應有 7 個作答類別")
	var keys := {}
	for c in Quiz.CATEGORIES:
		keys[c.key] = true
		check(not String(c.hint).is_empty(), "%s 缺一句話說明" % c.id)
	check(keys.keys() == [1, 2, 3, 4, 5, 6, 7], "鍵位應為 1～7 不重複")
	check(Quiz.CATEGORIES[4].hint == "死者留下的、倒著傳來的嘆息", "殘響說明不用「回音」，避免和虛假的一次回聲混淆（第 4 輪）")
	check(Quiz.CATEGORIES[5].hint == "攻擊前的蓄力聲，可以擋", "前兆（可招架）說明照規格書")
	check(Quiz.CATEGORIES[6].hint == "攻擊前的蓄力聲，結尾多一記重擊，擋不住", "前兆（不可招架）說明照規格書")
	check(Quiz.SOUNDS.size() == 8, "應有 8 種聲音")
	check(Quiz.SOUNDS.hollow == "fake" and Quiz.SOUNDS.glass == "fake", "兩種虛假都對應 fake")
	for s in Quiz.SOUNDS:
		check(Quiz.SOUNDS[s] in Quiz.CATEGORIES.map(func(c): return c.id), "%s 對應到不存在的類別" % s)
		check(Quiz.SOUND_LABELS.has(s), "%s 缺顯示名稱" % s)
	check(Quiz.category_for_key(6) == "tell_parry" and Quiz.category_for_key(8) == "", "鍵位對應錯誤")


func test_file_names() -> void:
	var files := Quiz.all_files()
	check(files.size() == 24, "應有 24 個檔名，實際 %d" % files.size())
	check(files[0] == "sfx_voc_alive_01.wav" and files[23] == "sfx_voc_tell_heavy_03.wav", "檔名順序或格式錯誤")
	check(Quiz.sound_of("sfx_voc_tell_parry_02.wav") == "tell_parry", "sound_of 應取出 tell_parry")


func test_audio_synced_and_imported() -> void:
	var miss := AudioBank.missing()
	check(miss.is_empty(), "缺少音檔（先執行 ./sync_audio.sh）：%s" % [miss])
	if miss.is_empty():
		check(AudioBank.load_stream("sfx_voc_echo_02.wav") is AudioStream, "載入音檔失敗")


func test_missing_reports_absent_dir() -> void:
	check(AudioBank.missing("res://no_such_dir").size() == 24, "目錄不存在時 24 個都算缺")


# ---- Task 2：出題與彙總 ----

# 模擬一位受測者答完 24 題；wrong 是 {file: guess} 指定答錯的題目
func sim_rows(tester: String, wrong := {}, count := 24) -> Array:
	var rows := []
	var files := Quiz.all_files()
	for i in count:
		var f: String = files[i]
		var guess: String = wrong.get(f, Quiz.SOUNDS[Quiz.sound_of(f)])
		rows.append(Quiz.make_row(tester, "20261003-100000", i + 1, f, guess, 1, 2.0))
	return rows


const ONLY := ["real", "glass", "echo", "tell_parry", "tell_heavy"]


func sim_rows_only(tester: String, only: Array, wrong := {}) -> Array:
	var rows := []
	var files := Quiz.files_for(only)
	for i in files.size():
		var f: String = files[i]
		rows.append(Quiz.make_row(tester, "20261006-100000", i + 1, f, wrong.get(f, Quiz.SOUNDS[Quiz.sound_of(f)]), 0, 2.0))
	return rows


func test_make_trials_only() -> void:
	var a := Quiz.make_trials(1, ONLY)
	check(a.size() == 15, "只測 5 種應出 15 題，實際 %d" % a.size())
	check(a.all(func(f): return Quiz.sound_of(f) in ONLY), "只出指定的聲音")
	check(Quiz.make_trials(1, []).size() == 24, "沒指定時照舊 24 題")


func test_parse_only() -> void:
	check(Quiz.parse_only(PackedStringArray(["--tester", "brian"])) == [], "沒給 --only 回傳空陣列")
	check(Quiz.parse_only(PackedStringArray(["--only", "real,glass"])) == ["real", "glass"], "逗號分隔")
	check(Quiz.parse_only(PackedStringArray(["--only", "real,typo"])) == null, "未知名稱回傳 null")
	check(Quiz.parse_only(PackedStringArray(["--only"])) == null, "缺值回傳 null")


func test_summarize_only() -> void:
	var s := Quiz.summarize(sim_rows_only("brian", ONLY), ONLY)
	check(s.complete_testers == 1, "15 題答完就算完成")
	check(s.verdict == "pass" and s.redo.is_empty(), "指定的都對應通過，沒測的不列入重做，實際 %s" % [s.redo])
	check(not s.sounds.alive.tested and s.sounds.real.tested, "沒測的聲音標記為未測")
	s = Quiz.summarize(sim_rows_only("brian", ONLY, {"sfx_voc_echo_01.wav": "real"}), ONLY)
	check(s.verdict == "fail" and s.redo == ["echo"], "只列出指定範圍內未達標的，實際 %s" % [s.redo])
	var md := Results.render_markdown(s)
	check(md.contains("| brian | 20261006-100000 | 15/15 |"), "受測者表的分母是 15")
	check(md.contains("| 活物 | 活物 | — | — | 未測 |"), "沒測的聲音顯示未測")


func test_make_trials() -> void:
	var a := Quiz.make_trials(1)
	check(a.size() == 24, "應出 24 題")
	var sorted_a := a.duplicate()
	sorted_a.sort()
	var all := Quiz.all_files()
	all.sort()
	check(sorted_a == all, "每個檔案剛好出現一次")
	check(a == Quiz.make_trials(1), "同一種子順序應相同")
	check(a != Quiz.make_trials(2), "不同種子順序應不同")
	check(a != Quiz.all_files(), "順序應被打亂")


func test_make_row() -> void:
	var r := Quiz.make_row("A", "s", 3, "sfx_voc_glass_02.wav", "fake", 2, 3.5)
	check(r.sound == "glass" and r.actual == "fake" and r.correct == true, "glass 答 fake 應算對")
	check(Quiz.make_row("A", "s", 1, "sfx_voc_danger_01.wav", "tell_heavy", 0, 1.0).correct == false, "danger 答 tell_heavy 應算錯")


func test_summarize_all_correct_passes() -> void:
	var s := Quiz.summarize(sim_rows("A") + sim_rows("B"))
	check(s.complete_testers == 2, "應有 2 位完成")
	check(s.sounds.hollow.total == 6 and is_equal_approx(s.sounds.hollow.rate, 1.0), "hollow 應 6/6")
	check(s.confusion.glass.fake == 6, "glass 答 fake 應有 6 次")
	check(s.tell_danger == 0 and s.tell_swap == 0, "不應有誤判")
	check(s.verdict == "pass" and s.redo.is_empty(), "全對應通過")


func test_summarize_low_rate_fails() -> void:
	# A、B 各答錯 echo_01（4/6 < 0.8）
	var w := {"sfx_voc_echo_01.wav": "real"}
	var s := Quiz.summarize(sim_rows("A", w) + sim_rows("B", w))
	check(s.sounds.echo.correct == 4 and not s.sounds.echo.pass, "echo 應 4/6 未達標")
	check(s.verdict == "fail" and s.redo == ["echo"], "應不通過並列出 echo，實際 %s" % [s.redo])


func test_summarize_tell_danger_fails_even_above_rate() -> void:
	# 只有 B 把一題 tell_heavy 答成 danger：5/6 ≥ 0.8，但前兆↔危險誤判 1 次
	var s := Quiz.summarize(sim_rows("A") + sim_rows("B", {"sfx_voc_tell_heavy_01.wav": "danger"}))
	check(s.sounds.tell_heavy.pass, "tell_heavy 5/6 應達標")
	check(s.tell_danger == 1, "前兆↔危險誤判應為 1")
	check(s.verdict == "fail" and s.redo == ["tell_heavy"], "誤判 1 次應不通過並列出 tell_heavy")


func test_summarize_counts_tell_swap() -> void:
	var s := Quiz.summarize(sim_rows("A", {"sfx_voc_tell_parry_01.wav": "tell_heavy", "sfx_voc_danger_02.wav": "tell_parry"}) + sim_rows("B"))
	check(s.tell_swap == 1, "前兆兩變體互相誤判應為 1")
	check(s.tell_danger == 1, "danger 答成 tell_parry 應算前兆↔危險誤判")


func test_summarize_insufficient_and_underscore() -> void:
	var s := Quiz.summarize(sim_rows("A") + sim_rows("_brian") + sim_rows("C", {}, 10))
	check(s.complete_testers == 1, "底線代號略過、未完成不算，應只有 1 位完成")
	check(s.verdict == "pass", "Brian 獨自盲測（PROTO-3 變更）：1 位完成就下結論")
	check(Quiz.summarize(sim_rows("_brian") + sim_rows("C", {}, 10)).verdict == "insufficient", "沒有人完成時應為樣本不足")
	check(s.testers.size() == 2 and s.testers[1].answered == 10 and not s.testers[1].complete, "未完成場次應列出並標記")
	check(s.sounds.glass.total == 3 + 1 and s.sounds.alive.total == 3 + 3, "未完成場次已答的題目照樣計入")


func test_complete_testers_counted_by_name() -> void:
	var again := sim_rows("A")
	for r in again:
		r.session = "20261003-110000"
	var s := Quiz.summarize(sim_rows("A") + again)
	check(s.complete_testers == 1, "同一代號跑兩次只算 1 位完成")
	check(s.verdict == "pass", "同一代號跑兩次仍是 1 位，1 位即可下結論")


# ---- Task 3：CSV 與彙總 ----

func clean_tmp() -> void:
	var d := DirAccess.open("user://")
	if d.dir_exists("p5_selftest_results"):
		for f in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP.path_join(f)))
	else:
		d.make_dir("p5_selftest_results")


func test_sanitize_tester() -> void:
	check(Results.sanitize_tester("A/B") == "A_B", "斜線應被替換，實際 %s" % Results.sanitize_tester("A/B"))
	check(Results.sanitize_tester(" 小明 ") == "小明", "中文保留、前後空白去掉")
	check(Results.sanitize_tester("a b") == "a_b", "中間空白換成底線")
	check(Results.sanitize_tester("   ") == "", "全空白回空字串（由呼叫端改用時間）")
	check(not Results.session_path(TMP, Results.sanitize_tester("../x"), "s").get_base_dir().ends_with(".."), "不可寫到上層資料夾")


func test_csv_round_trip() -> void:
	clean_tmp()
	var path := Results.session_path(TMP, "A", "20261003-100000")
	var rows := sim_rows("A", {"sfx_voc_glass_01.wav": "echo"}, 5)
	for r in rows:
		check(Results.append_row(path, r) == OK, "寫入失敗")
	var got: Dictionary = Results.read_dir(TMP)
	check(got.files == 1 and got.rows.size() == 5 and got.skipped.is_empty(), "應讀回 1 檔 5 列")
	check(got.rows[3].file == rows[3].file and got.rows[3].correct == rows[3].correct and got.rows[3].trial == 4, "讀回內容不一致")
	check(FileAccess.get_file_as_string(path).begins_with(",".join(Results.COLUMNS)), "第一列應為標題列")


func test_read_dir_skips_bad_rows_and_non_csv() -> void:
	clean_tmp()
	var path := Results.session_path(TMP, "A", "s1")
	Results.append_row(path, sim_rows("A", {}, 1)[0])
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("A,s1,x,sfx_voc_alive_01.wav,alive,alive,alive,1,0,1.0")  # trial 不是整數
	f.store_line("A,s1,3,too,few")
	f.close()
	FileAccess.open(TMP.path_join("summary.md"), FileAccess.WRITE).store_string("# 舊彙總")
	var got: Dictionary = Results.read_dir(TMP)
	check(got.files == 1, "只應讀 .csv")
	check(got.rows.size() == 1, "壞列不應讀入")
	check(got.skipped == ["A_s1.csv:3", "A_s1.csv:4"], "應報出壞列的行號，實際 %s" % [got.skipped])


func test_render_markdown() -> void:
	var md := Results.render_markdown(Quiz.summarize(sim_rows("A", {"sfx_voc_echo_01.wav": "real"}) + sim_rows("B", {"sfx_voc_echo_01.wav": "real"})))
	for h in ["## 受測者", "## 每種聲音", "## 混淆表", "## 前兆與危險", "## 結論"]:
		check(md.contains(h), "缺少章節 %s" % h)
	check(md.contains("**不通過**：重做 殘響"), "結論應列出要重做的殘響")
	check(md.contains("虛假（假光）"), "每種聲音應用顯示名稱")
	check(Results.render_markdown(Quiz.summarize(sim_rows("A"))).contains("**通過**"), "1 位全對應為通過")
	check(Results.render_markdown(Quiz.summarize(sim_rows("A", {}, 10))).contains("**樣本不足**"), "沒有人完成時應為樣本不足")


# ---- Task 4：測驗畫面 ----

func new_screen(fast := true) -> Control:
	clean_tmp()
	var sc := QuizScreen.new()
	sc.setup("T", TMP, 7)
	if fast:
		sc.auto_play_delay = 0.05
		sc.next_delay = 0.05
	add_child(sc)
	await frames(1)
	return sc


func test_screen_only_subset() -> void:
	clean_tmp()
	var sc := QuizScreen.new()
	sc.setup("T", TMP, 7, AudioBank.DIR, ONLY)
	add_child(sc)
	await frames(1)
	check(sc.trials.size() == 15 and sc.trials.all(func(f): return Quiz.sound_of(f) in ONLY), "測驗畫面只出指定的 15 題")
	sc.queue_free()
	await frames(1)


func test_intro_then_autoplay() -> void:
	var sc = await new_screen(false)
	check(sc.state == "intro", "一開始應在說明畫面")
	sc.press(KEY_ENTER)
	check(sc.state == "wait" and sc.play_count == 0, "按 Enter 後等待自動播放")
	await wait_s(QuizScreen.AUTO_PLAY_DELAY + 0.1)
	check(sc.state == "trial" and sc.play_count == 1, "0.5 秒後應自動播一次")
	sc.press(KEY_SPACE)
	check(sc.play_count == 2, "Space 應重播")
	sc.queue_free()
	await frames(1)


func test_enter_before_first_play_is_ignored() -> void:
	var sc = await new_screen(false)
	sc.press(KEY_ENTER)
	sc.press(KEY_1)
	sc.press(KEY_ENTER)
	check(sc.state == "wait" and sc.trial_index == 0 and sc.rows.is_empty(), "還沒播放前不可確認作答")
	sc.queue_free()
	await frames(1)


func test_space_before_autoplay_is_first_play() -> void:
	var sc = await new_screen(false)
	sc.press(KEY_ENTER)
	sc.press(KEY_SPACE)
	check(sc.state == "trial" and sc.play_count == 1, "自動播放前按 Space 應立即播放，算第一次")
	await wait_s(QuizScreen.AUTO_PLAY_DELAY + 0.1)
	check(sc.play_count == 1, "自動播放不應再播一次")
	sc.queue_free()
	await frames(1)


func test_confirm_writes_row_and_ignores_echo() -> void:
	var sc = await new_screen()
	sc.press(KEY_ENTER)
	await wait_s(0.1)
	sc.press(KEY_ENTER)
	check(sc.rows.is_empty(), "沒選答案時 Enter 無效")
	sc.press(KEY_4, true)
	check(sc.selected == "", "長按連發不算")
	sc.press(KEY_2)
	sc.press(KEY_4)
	check(sc.selected == "danger", "確認前可以改選")
	sc.press(KEY_SPACE)
	sc.press(KEY_ENTER)
	check(sc.rows.size() == 1 and sc.rows[0].guess == "danger" and sc.rows[0].replays == 1, "應寫入一列、重播 1 次")
	check(Results.read_dir(TMP).rows.size() == 1, "CSV 應已有一列")
	sc.queue_free()
	await frames(1)


func test_enter_during_gap_is_ignored() -> void:
	var sc = await new_screen(false)
	sc.press(KEY_ENTER)
	sc.press(KEY_SPACE)
	sc.press(KEY_1)
	sc.press(KEY_ENTER)
	check(sc.state == "gap", "確認後進入間隔")
	sc.press(KEY_1)
	sc.press(KEY_ENTER)
	sc.press(KEY_ENTER)
	check(sc.rows.size() == 1 and sc.trial_index == 1, "間隔中的按鍵不可寫列或跳題")
	sc.queue_free()
	await frames(1)


func test_full_session_reaches_done() -> void:
	var sc = await new_screen()
	sc.press(KEY_ENTER)
	for i in 24:
		await wait_s(0.15)  # 間隔 0.05＋自動播放 0.05，留餘裕
		sc.press(KEY_3)
		sc.press(KEY_ENTER)
	await wait_s(0.1)
	check(sc.state == "done", "第 24 題後應進結束畫面，實際 %s" % sc.state)
	var got: Dictionary = Results.read_dir(TMP)
	check(got.rows.size() == 24, "CSV 應有 24 列")
	check(Quiz.summarize(got.rows).sounds.hollow.correct == 3, "全答虛假時 hollow 應 3/3")
	sc.queue_free()
	await frames(1)


func test_csv_write_failure_stops() -> void:
	clean_tmp()
	FileAccess.open(TMP.path_join("blocked"), FileAccess.WRITE).store_string("x")  # 同名檔案擋住資料夾
	var sc := QuizScreen.new()
	sc.setup("T", TMP.path_join("blocked"), 7)
	sc.auto_play_delay = 0.05
	add_child(sc)
	await frames(1)
	sc.press(KEY_ENTER)
	await wait_s(0.15)
	sc.press(KEY_1)
	sc.press(KEY_ENTER)
	check(sc.state == "error" and sc.rows.is_empty() and sc.trial_index == 0, "CSV 寫入失敗應停止測驗、不前進")
	sc.queue_free()
	await frames(1)


func test_missing_audio_refuses_to_start() -> void:
	clean_tmp()
	var sc := QuizScreen.new()
	sc.setup("T", TMP, 7, "res://no_such_dir")
	add_child(sc)
	await frames(1)
	check(sc.state == "error" and sc.error_text.contains("sync_audio.sh"), "缺音檔應拒絕開始並提示同步")
	sc.press(KEY_ENTER)
	check(sc.state == "error" and DirAccess.get_files_at(TMP).is_empty(), "缺音檔時不可開始也不可建立 CSV")
	sc.queue_free()
	await frames(1)


# ---- Task 5：試聽 ----

func test_catalog_cycles_variants() -> void:
	var sc := CatalogScreen.new()
	sc.setup()
	add_child(sc)
	await frames(1)
	sc.press(KEY_5)
	check(sc.now_playing == "sfx_voc_danger_01.wav", "第 5 鍵第一次應播 danger_01，實際 %s" % sc.now_playing)
	check(sc.status_text == "正在播：危險 danger_01", "顯示文字錯誤：%s" % sc.status_text)
	sc.press(KEY_5)
	check(sc.now_playing == "sfx_voc_danger_02.wav", "連按應輪到 02")
	sc.press(KEY_5)
	sc.press(KEY_5)
	check(sc.now_playing == "sfx_voc_danger_01.wav", "03 之後回到 01")
	sc.press(KEY_4)
	check(sc.status_text == "正在播：虛假（假光） glass_01", "第 4 鍵應為 glass")
	sc.press(KEY_9)
	check(sc.now_playing == "sfx_voc_glass_01.wav", "9 不對應任何聲音")
	sc.queue_free()
	await frames(1)


func test_catalog_missing_audio() -> void:
	var sc := CatalogScreen.new()
	sc.setup("res://no_such_dir")
	add_child(sc)
	await frames(1)
	sc.press(KEY_1)
	check(sc.state == "error" and sc.now_playing == "", "缺音檔時不可播放")
	sc.queue_free()
	await frames(1)


func test_tester_label_is_one_line() -> void:
	# 截圖發現：右上角受測者代號被自動換行拆成一字一行，壓在選項上
	var sc = await new_screen()
	var corner: Label = null
	for l in sc.find_children("*", "Label", true, false):
		if l.text.begins_with("受測者："):
			corner = l
	check(corner != null and corner.get_line_count() == 1, "受測者代號應顯示成一行")
	sc.queue_free()
	await frames(1)


# ---- 最終審查修正 ----

func test_sanitized_names_stay_visible_and_counted() -> void:
	# 審查發現：".x" 會變成隱藏檔（讀不到）、"/bob" 會變成 "_bob"（被當主持人試跑略過）
	clean_tmp()
	var names := [".x", "/bob", "../y"]
	for n in names:
		var t := Results.sanitize_tester(n)
		check(not t.begins_with(".") and not t.begins_with("_"), "%s 清理後是 %s，不可以 . 或 _ 開頭" % [n, t])
		for r in sim_rows(t):
			Results.append_row(Results.session_path(TMP, t, "20261003-120000"), r)
	var got: Dictionary = Results.read_dir(TMP)
	check(got.files == 3, "三個受測者的 CSV 都應被讀到，實際 %d" % got.files)
	check(Quiz.summarize(got.rows).complete_testers == 3, "三人都應計入完成人數")
	check(Results.sanitize_tester("_brian") == "_brian", "原本就以底線開頭的主持人代號要保留")
	check(Results.sanitize_tester(".") == "", "只有點的代號清理後為空（改用時間）")
