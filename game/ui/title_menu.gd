extends Control
# 標題畫面與主選單（MV-SLICE-001a Task 12 灰盒 → MV-SLICE-001d2a 正式化）。
# 背景：夜裡的 nance 樹（SubViewport 裡的 SceneryView＋鏡頭緩慢左右移，視差照各層係數）＋樹冠上 Seven Macaw 的剪影。
# 選單：新遊戲／繼續／繪本／製作說明／結束遊戲。讀不到存檔時「繼續」不可選。
# MV-SLICE-001d2b：「繪本」開閱讀器；第一次選新遊戲時先問「要先讀繪本嗎？」（問過一次就記在 book_asked_path，不再問）。
# 有存檔時選「新遊戲」、選「結束遊戲」都要再按一次確認；上下移動或翻滾鍵取消確認。上下選、攻擊鍵或 Enter 決定。

const Save := preload("res://state/save.gd")
const MenuInput := preload("res://ui/menu_input.gd")
const Credits := preload("res://ui/credits.gd")
const BookReader := preload("res://ui/book_reader.gd")
const SceneryView := preload("res://world/scenery_view.gd")
const Actor := preload("res://world/cutscene/actor.gd")
const Nance := preload("res://core/boss/nance_arena.gd")
const ITEMS := ["新遊戲", "繼續", "繪本", "製作說明", "結束遊戲"]
const GAME_TITLE := "雙子星玉米人"  # 正式標題（MV-TITLE-001 定案，MV-RELEASE-001 REL-6）；全專案只此一處
const SUBTITLE := "試玩版"  # 內部代號已含「垂直切片」，副標不重複
const CONFIRM_NEW := "會蓋掉現在的存檔。再按一次確認，翻滾鍵取消"
const CONFIRM_QUIT := "確定要離開嗎？再按一次離開，翻滾鍵取消"
const ASK_TEXT := "要先讀繪本嗎？"
const ASK_ITEMS := ["讀繪本", "直接開始"]
const PAN := 200.0  # 鏡頭左右移動的幅度（px）
const PAN_PERIOD := 20.0  # 一個來回（秒）

signal chosen(mode: String)  # "new"｜"continue"
signal quit_requested

var save_path := Save.PATH
var cursor := 0
var confirming := false  # 新遊戲要蓋掉存檔
var confirming_quit := false
var asking := false  # 新遊戲前的繪本詢問（SLICE-d2b-6）
var ask_cursor := 0  # 0＝讀繪本、1＝直接開始
var quit_enabled := not OS.has_feature("web")  # 網頁版的 quit() 只會讓畫面停住（MV-RELEASE-001）
var book_asked_path := "user://book_asked.json"  # 存在＝問過了；和存檔分開（自測改成 user://test_*）
var credits  # 開著的製作說明（credits.gd）；沒有時 null
var book  # 開著的繪本（book_reader.gd）；沒有時 null
var _left := false  # 已發出 chosen：主程式會移除主選單，這之前不再讀按鍵（只開一次遊戲）
var font: Font = preload("res://art/fonts/NotoSerifTC_ui.ttf")  # 思源宋體精簡版（SLICE-d2a-7；tools/font_subset.py 產生）
var _has_save := false
var _camera: Camera2D
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 已在樹裡：offsets 也要跟著設，否則大小是 0
	_build_background()
	refresh()


## 製作說明的標題：正式標題＋版號（project.godot 的 config/version，MV-RELEASE-001）
static func display_title() -> String:
	return "%s v%s" % [GAME_TITLE, ProjectSettings.get_setting("application/config/version")]


## 背景放在自己的 SubViewport（自己的 World2D 與鏡頭），不影響遊戲世界
func _build_background() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.show_behind_parent = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.world_2d = World2D.new()
	box.add_child(vp)
	var scenery := SceneryView.new()
	vp.add_child(scenery)
	scenery.build_boss()
	scenery.night = true
	var macaw: Node2D = Actor.make("sevenmacaw")
	macaw.position = Nance.PERCH  # 吃果子的低枝：整隻在畫面裡（樹冠在畫面頂端之外，只看得到腳）
	macaw.facing = -1
	vp.add_child(macaw)
	macaw.play("idle_perch")
	macaw.set_black(true)  # 剪影
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_camera.position = Nance.VIEW.position
	vp.add_child(_camera)
	_camera.make_current()


## 重新檢查存檔；有存檔時游標預設在「繼續」
func refresh() -> void:
	_has_save = Save.exists(save_path)
	confirming = false
	confirming_quit = false
	asking = false
	_left = false
	cursor = 1 if _has_save else 0
	Audio.set_ambience(&"amb_01")  # 夜裡森林的風（SLICE-d2a-2）
	queue_redraw()


func can_choose(item: String) -> bool:
	match item:
		"繼續":
			return _has_save
		"結束遊戲":
			return quit_enabled
	return true


## 往上（-1）或往下（1）移到下一個可選的項目（頭尾相接）
func move_cursor(dir: int) -> void:
	for i in ITEMS.size():
		cursor = posmod(cursor + dir, ITEMS.size())
		if can_choose(ITEMS[cursor]):
			break
	confirming = false
	confirming_quit = false
	Audio.play(&"ui_move")
	queue_redraw()


func choose_item(item: String) -> void:
	if not can_choose(item):
		return
	if item != "繪本":  # 開繪本只播翻頁聲，不和確認聲疊在一起（MV-SLICE-001d2b2）
		Audio.play(&"ui_confirm")  # MV-SLICE-001d1b
	match item:
		"新遊戲":
			if _has_save and not confirming:
				confirming = true
				queue_redraw()
				return
			confirming = false
			_start_new()
		"繼續":
			_leave("continue")
		"繪本":
			_open_book(false)
		"製作說明":
			_open_credits()
		"結束遊戲":
			if not confirming_quit:
				confirming_quit = true
				queue_redraw()
				return
			confirming_quit = false
			quit_requested.emit()


## 問過繪本就直接開始；沒問過先問（SLICE-d2b-6）
func _start_new() -> void:
	if FileAccess.file_exists(book_asked_path):
		_leave("new")
		return
	asking = true
	ask_cursor = 0
	queue_redraw()


## 回答詢問：不論選哪個都先記下「問過了」（寫不進去就算了，下次再問一次）
func answer_ask(read: bool) -> void:
	asking = false
	var f := FileAccess.open(book_asked_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"asked": true}))
		f.close()
	if read:
		_open_book(true)
	else:
		_leave("new")


## then_new：從新遊戲詢問進來的，讀完或離開都直接開始新遊戲（SLICE-d2b-7）
func _open_book(then_new: bool) -> void:
	book = BookReader.new()
	add_child(book)
	book.open()
	book.closed.connect(func():
		book.queue_free()
		book = null
		if then_new:
			_leave("new")
		else:
			queue_redraw())
	queue_redraw()


func _leave(mode: String) -> void:
	_left = true
	MenuInput.swallow()
	chosen.emit(mode)


func _open_credits() -> void:
	credits = Credits.new()
	credits.mode = "manual"
	credits.title = display_title()
	credits.font = font
	add_child(credits)
	credits.closed.connect(func():
		credits.queue_free()
		credits = null
		queue_redraw())
	MenuInput.swallow()


func _process(delta: float) -> void:
	_t += delta
	if _camera != null:
		_camera.position.x = Nance.VIEW.position.x - PAN * (0.5 - 0.5 * cos(TAU * _t / PAN_PERIOD))
	if credits != null or book != null or _left:
		return
	if asking:
		if MenuInput.just(&"look_up") or MenuInput.just(&"look_down"):
			ask_cursor = 1 - ask_cursor
			Audio.play(&"ui_move")
			queue_redraw()
		elif MenuInput.just(&"attack") or MenuInput.just(&"ui_accept"):
			if ask_cursor != 0:  # 讀繪本只播翻頁聲（MV-SLICE-001d2b2）
				Audio.play(&"ui_confirm")
			answer_ask(ask_cursor == 0)
		elif MenuInput.just(&"roll") or MenuInput.just(&"pause"):
			# 取消：回主選單、不記錄問過，和覆蓋確認的「翻滾＝取消」一致（MV-SLICE-001d2b2）
			asking = false
			Audio.play(&"ui_back")
			queue_redraw()
		return
	if MenuInput.just(&"look_up"):
		move_cursor(-1)
	elif MenuInput.just(&"look_down"):
		move_cursor(1)
	elif MenuInput.just(&"attack") or MenuInput.just(&"ui_accept"):
		choose_item(ITEMS[cursor])
	elif MenuInput.just(&"roll") or MenuInput.just(&"pause"):
		if confirming or confirming_quit:
			Audio.play(&"ui_back")
		confirming = false
		confirming_quit = false
		queue_redraw()


func _draw() -> void:
	if credits != null or book != null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))  # 壓暗一點，讓字浮出來
	draw_string(font, Vector2(0, size.y * 0.3), GAME_TITLE, HORIZONTAL_ALIGNMENT_CENTER, size.x, 76, Color(1, 0.92, 0.75))
	draw_string(font, Vector2(0, size.y * 0.3 + 56), SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.9, 0.85, 0.75, 0.8))
	for i in ITEMS.size():
		var mark := "▶ " if i == cursor else "　"
		var a := 1.0 if can_choose(ITEMS[i]) else 0.3
		draw_string(font, Vector2(size.x / 2.0 - 120, size.y * 0.5 + i * 60), mark + ITEMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, a))
	var y := size.y * 0.5 + ITEMS.size() * 60 + 40
	if asking:
		draw_string(font, Vector2(0, y), ASK_TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(1, 0.92, 0.75))
		for i in ASK_ITEMS.size():
			var mark := "▶ " if i == ask_cursor else "　"
			draw_string(font, Vector2(size.x / 2.0 - 90, y + 50 + i * 44), mark + ASK_ITEMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		return
	var msg := CONFIRM_NEW if confirming else (CONFIRM_QUIT if confirming_quit else "")
	if msg != "":
		draw_string(font, Vector2(0, y), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 0.7, 0.6))
