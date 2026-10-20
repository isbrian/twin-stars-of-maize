extends Node2D
# MV-PROTO-005 聲音語彙盲測（獨立、可丟棄）。規格：todo/spec/MV-PROTO-005_聲音語彙盲測.md
# 沒有模式參數時開啟測驗畫面。使用者參數（放在 -- 之後）：
#   --self-test   執行自動測試後結束（結束碼 0＝全部通過）
#   --tester <代號> 測驗模式的受測者代號（底線開頭＝主持人試跑，彙總時略過）
#   --catalog     主持人試聽：按 1～8 播放 8 種聲音
#   --screenshot <資料夾>  以 1920×1080 輸出 intro.png、trial.png、catalog.png 後結束（需有視窗）
#   --summarize   彙總 results/*.csv，印出 Markdown 並寫入 results/summary.md（沒有 CSV 時結束碼 1）
#   --only <聲音,...>  測驗與彙總只用指定的聲音（例：real,glass,echo,tell_parry,tell_heavy），重做後只重測該類

const SelfTest := preload("res://tests/self_test.gd")
const Quiz := preload("res://quiz.gd")
const Results := preload("res://results.gd")
const AudioBank := preload("res://audio_bank.gd")
const QuizScreen := preload("res://quiz_screen.gd")
const CatalogScreen := preload("res://catalog_screen.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only = Quiz.parse_only(args)
	if only == null:
		printerr("--only 要接逗號分隔的聲音名稱：%s" % ", ".join(PackedStringArray(Quiz.SOUNDS.keys())))
		get_tree().quit(1)
		return
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	if "--summarize" in args:
		get_tree().quit(_summarize(only))
		return
	var shot := args.find("--screenshot")
	if shot != -1 and shot + 1 < args.size():
		await _screenshots(args[shot + 1])
		get_tree().quit()
		return
	if "--catalog" in args:
		add_child(CatalogScreen.new())
		return
	var screen := QuizScreen.new()
	var t := args.find("--tester")
	screen.setup(args[t + 1] if t != -1 and t + 1 < args.size() else "", Results.DIR, -1, AudioBank.DIR, only)
	add_child(screen)


func _summarize(only: Array) -> int:
	var got: Dictionary = Results.read_dir(Results.DIR)
	if got.files == 0:
		printerr("SUMMARY 找不到 results/*.csv")
		return 1
	for x in got.skipped:
		print("SUMMARY 略過 %s" % x)
	var md := Results.render_markdown(Quiz.summarize(got.rows, only))
	print(md)
	var f := FileAccess.open(Results.DIR.path_join("summary.md"), FileAccess.WRITE)
	f.store_string(md)
	return 0


func _screenshots(dir: String) -> void:
	get_window().size = Vector2i(1920, 1080)
	for i in 2:
		await get_tree().process_frame
	var quiz := QuizScreen.new()
	quiz.setup("_screenshot", "user://p5_screenshot_results", 1)  # 不確認作答，不會寫 CSV
	add_child(quiz)
	await _capture(dir.path_join("intro.png"))
	quiz.press(KEY_ENTER)
	quiz.press(KEY_SPACE)
	quiz.press(KEY_3)
	await _capture(dir.path_join("trial.png"))
	quiz.queue_free()
	var cat := CatalogScreen.new()
	add_child(cat)
	await get_tree().process_frame
	cat.press(KEY_4)
	await _capture(dir.path_join("catalog.png"))


func _capture(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s err=%d" % [path, err])
