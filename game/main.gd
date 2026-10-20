extends Node2D
# 垂直切片的正式專案（MV-SLICE-001a）：主選單 → 遊戲本體（world/game_world.gd）→ 回主選單。
# 開發版才有的參數：--self-test 跑自測、--room <id>、--boss、--boss-phase N、--shots <資料夾>、--rig-view、--fx-view、--cutscene <名稱>、--sound-tour、--title-tour（發行版忽略，直接進主選單）。

const Runner := preload("res://tests/runner.gd")
const LaunchArgs := preload("res://launch_args.gd")
const TitleMenu := preload("res://ui/title_menu.gd")
const GameWorld := preload("res://world/game_world.gd")
const Shots := preload("res://world/shots.gd")
const RigShowcase := preload("res://world/rig_showcase.gd")
const FxShowcase := preload("res://world/fx_showcase.gd")
const CutsceneView := preload("res://world/cutscene_view.gd")
const SoundTour := preload("res://world/sound_tour.gd")
const TitleTour := preload("res://world/title_tour.gd")
const UI_FONT := preload("res://art/fonts/NotoSerifTC_ui.ttf")

var opts := {}
var auto_start := true  # 自測建主程式時關掉，不然 _ready 會照啟動參數再跑一次自測（MV-SLICE-001d2a）
var title: Control
var world: Node


func _ready() -> void:
	# 預設字型的中文後備：網頁版沒有系統字型可借，Windows 也不一定有繁中字型（MV-RELEASE-001）
	if not UI_FONT in ThemeDB.fallback_font.fallbacks:
		ThemeDB.fallback_font.fallbacks = ThemeDB.fallback_font.fallbacks + [UI_FONT]
	if not auto_start:
		return
	opts = LaunchArgs.parse(OS.get_cmdline_user_args())
	if opts.mode == "selftest":
		var t := Runner.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	if OS.is_debug_build() and opts.mode == "sound_tour":
		add_child(SoundTour.new())
		return
	if OS.is_debug_build() and opts.mode == "title_tour":
		add_child(TitleTour.new())
		return
	if OS.is_debug_build() and opts.mode == "shots":
		var s := Shots.new()
		s.dir = opts.shots_dir
		add_child(s)
		return
	if OS.is_debug_build() and (opts.mode == "rig_view" or opts.mode == "fx_view"):
		var sc = RigShowcase.new() if opts.mode == "rig_view" else FxShowcase.new()
		sc.frames_dir = opts.frames_dir
		add_child(sc)
		return
	if OS.is_debug_build() and opts.mode == "cutscene":
		var cv := CutsceneView.new()
		cv.scene_name = opts.cutscene
		cv.frames_dir = opts.frames_dir
		add_child(cv)
		return
	if OS.is_debug_build() and (opts.mode == "room" or opts.mode == "boss"):
		_open_world().dev_start(opts.room if opts.mode == "room" else "boss", opts.boss_phase)
		return
	_show_title()


func _show_title() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = TitleMenu.new()
	layer.add_child(title)
	title.chosen.connect(_on_chosen.bind(layer))
	title.quit_requested.connect(get_tree().quit)  # 主選單「結束遊戲」（MV-SLICE-001d2a）


func _on_chosen(mode: String, layer: Node) -> void:
	layer.queue_free()
	var w := _open_world()
	if mode == "new" or not w.continue_game():
		w.new_game()


func _open_world() -> Node:
	world = GameWorld.new()
	add_child(world)
	world.quit_to_title.connect(_on_quit)
	return world


## 等遊戲世界真的離開場景樹再顯示標題：它的 _exit_tree 會 Audio.stop_all()，
## 先顯示標題的話，標題剛設的環境音會在幀尾被關掉（MV-SLICE-001d2a 最終審查）
func _on_quit() -> void:
	world.tree_exited.connect(_show_title, CONNECT_ONE_SHOT)
	world.queue_free()
	world = null
