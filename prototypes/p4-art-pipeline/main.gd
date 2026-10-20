extends Node2D
# MV-PROTO-004 美術管線（獨立、可丟棄）。規格：todo/spec/MV-PROTO-004_美術管線.md
# 使用者參數（放在 -- 之後）：
#   --self-test             執行自動測試後結束（結束碼 0＝全部通過）
#   --build-rig [--force]   依 rig/{角色}_rig.json 產生 {角色}.tscn（hunahpu、xbalanque）；檔案被手動改過時不覆蓋，除非加 --force
#   --screenshot <資料夾>   輸出 showcase.png、showcase_gray.png、consistency.png 後結束（需有視窗）
# 沒有參數時開啟展示畫面。

const SelfTest := preload("res://tests/self_test.gd")
const Rig := preload("res://rig/rig.gd")
const Build := preload("res://rig/build_rig.gd")
const Showcase := preload("res://showcase.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	if "--build-rig" in args:
		get_tree().quit(_build_rig("--force" in args))
		return
	var sc := Showcase.new()
	add_child(sc)
	var shot := args.find("--screenshot")
	if shot != -1 and shot + 1 < args.size():
		await _screenshots(sc, args[shot + 1])
		get_tree().quit()


func _build_rig(force: bool) -> int:
	var rc := 0
	for c in Rig.CHARS:
		var rig := Rig.new()
		if rig.load_file(Rig.path_for(c)) != OK:
			printerr("BUILD 讀不到 %s" % Rig.path_for(c))
			rc = 1
			continue
		var root := Build.build(rig)
		if root == null:
			rc = 1
			continue
		var err := Build.save_scene(root, Build.out_for(c), Build.hash_for(c), force)
		root.free()
		print("BUILD %s err=%d" % [Build.out_for(c), err])
		if err != OK:
			rc = 1
	return rc


func _screenshots(sc, dir: String) -> void:
	for i in 10:
		await get_tree().process_frame
	sc.freeze_for_capture()
	for i in 2:  # 等視窗改尺寸後重新排版
		await get_tree().process_frame
	await sc.capture_image(dir.path_join("showcase.png"))
	sc.toggle_gray()
	await sc.capture_image(dir.path_join("showcase_gray.png"))
	sc.toggle_gray()
	sc.set_view("consistency")
	await sc.capture_image(dir.path_join("consistency.png"))
