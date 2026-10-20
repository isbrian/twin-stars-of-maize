# MV-PROTO-005 聲音語彙盲測 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `prototypes/p5-sound-test/` 做一個問答台：一次播一個第 0 批 WAV、受測者按 1～7 作答，每題寫進 CSV，`--summarize` 彙總出每種聲音正確率、混淆表與通過判定；另有主持人試聽模式。

**Architecture:** `quiz.gd` 是不碰畫面與檔案的純邏輯（類別表、出題、彙總、判定）；`results.gd` 負責 CSV 與 Markdown；`audio_bank.gd` 負責找檔與載入音訊；`quiz_screen.gd`、`catalog_screen.gd` 是兩個畫面；`main.gd` 依命令列參數切換模式。

**Tech Stack:** Godot 4.7.2、GDScript。

**Spec:** [todo/spec/MV-PROTO-005_聲音語彙盲測.md](MV-PROTO-005_聲音語彙盲測.md)

## Global Constraints

- Godot 4.7.2；**不使用 `class_name`**，跨檔引用一律 `preload` 常數。
- 專案在 `prototypes/p5-sound-test/`，獨立、可丟棄，不引用 `prototypes/p1-listening/` 或其他原型的檔案（P1 的慣例用抄的）。
- 素材來源 `assets-test/batch0/audio/`，由 `sync_audio.sh` 複製到 `audio/`；**`audio/`、`results/`、`shots/` 不進版控**。
- 畫面基準 1920×1080、`window/stretch/mode="canvas_items"`；截圖前把視窗設成 1920×1080（MV-PROTO-004 的教訓：截圖抓的是視窗大小）。
- 類別、鍵位、一句話說明、聲音代號照規格書第 1 節的表，一字不改；8 種聲音、每種 3 個變體、檔名 `sfx_voc_<sound>_0N.wav`。
- 通過門檻：每種聲音「答對 ÷ 題數 ≥ 0.8」；前兆↔危險誤判 0；完成 24 題的受測者（不重複代號）少於 2 位＝樣本不足；底線開頭的代號略過。
- 時間：自動播放延遲 0.5 秒；確認後到下一題 0.6 秒。
- 執行期錯誤 Godot 只印 `SCRIPT ERROR` 不會讓測試失敗：驗證一律另外 grep。
- **驗證命令**（每個 Task 的「執行測試」都用這組）：

  ```bash
  cd '<repo>/prototypes/p5-sound-test'
  godot --headless --fixed-fps 60 --quit-after 7200 --path . -- --self-test > /tmp/p5_selftest.txt 2>&1; rc=$?
  grep -E '^SELFTEST (FAIL|SUMMARY)|SELFTEST   x|SCRIPT ERROR|Parse Error' /tmp/p5_selftest.txt; echo "rc=$rc"
  ```

  通過＝`rc=0`、`SELFTEST SUMMARY pass=N fail=0`、沒有 `SCRIPT ERROR`／`Parse Error`。
- 註解繁體中文；捷徑加 `ponytail:` 註解。分支 `feature/MV-PROTO-005_聲音語彙盲測`，每個 Task 一個 commit。

## Review Focus

1. **受測者快速連按兩次 Enter**（或在 0.6 秒間隔中按）：不可跳題、不可重複寫列 → Task 4 `test_enter_during_gap_is_ignored`
2. **還沒播到聲音就按 Enter**（0.5 秒自動播放之前）：不可接受作答；先按 Space 則立即播放、算第一次播放而非重播 → Task 4 `test_enter_before_first_play_is_ignored`、`test_space_before_autoplay_is_first_play`
3. **同一位受測者跑了兩次**（中途 Esc 後重來）：完成人數以不重複代號計，不會讓 1 個人算成 2 位 → Task 2 `test_complete_testers_counted_by_name`
4. **受測者代號含 `/`、空白或中文**：檔名安全、不寫到別的資料夾；全空白時改用時間 → Task 3 `test_sanitize_tester`
5. **`results/` 裡有 `summary.md`、其他檔案或舊格式 CSV**：彙總只讀 `.csv`，壞列略過並報行號 → Task 3 `test_read_dir_skips_bad_rows_and_non_csv`

---

## 檔案結構

| 檔案 | 責任 | 建立於 |
|---|---|---|
| `project.godot`、`.gitignore`、`main.tscn`、`main.gd` | 專案設定；進入點（`--self-test`、`--summarize`、`--catalog`、`--screenshot`、預設測驗） | Task 1（之後各 Task 擴充 main.gd） |
| `sync_audio.sh` | 複製素材並匯入 | Task 1 |
| `quiz.gd` | 類別表、檔名、出題、彙總、判定 | Task 1（Task 2 擴充） |
| `audio_bank.gd` | 音檔目錄、缺檔檢查、載入 | Task 1 |
| `results.gd` | 代號清理、CSV 讀寫、Markdown | Task 3 |
| `quiz_screen.gd` | 說明、作答、結束、錯誤畫面 | Task 4 |
| `catalog_screen.gd` | 主持人試聽 | Task 5 |
| `tests/self_test.gd` | 測試執行器＋全部測試 | Task 1（之後追加） |
| `README.md` | 執行、盲測步驟、要唸的說明、結果 | Task 6 |

`audio_bank.gd` 是規格書檔案清單之外新增的小檔：缺檔檢查與載入同時給測驗與試聽用，放在 `quiz.gd` 會違反「純邏輯不碰檔案」。

---

### Task 1: 專案骨架、類別表、音檔同步

**Files:**
- Create: `prototypes/p5-sound-test/project.godot`、`.gitignore`、`main.tscn`、`main.gd`、`sync_audio.sh`、`quiz.gd`、`audio_bank.gd`
- Test: `prototypes/p5-sound-test/tests/self_test.gd`

**Interfaces:**
- Produces：
  - `self_test.gd`：`check(cond: bool, msg: String)`、`frames(n: int)`（async）、`wait_s(t: float)`（async，`await get_tree().create_timer(t).timeout`）、`pass_count`、`fail_count`、`run()`（async，依名稱排序執行所有 `test_` 方法，印 `SELFTEST PASS|FAIL <名>` 與 `SELFTEST SUMMARY pass=N fail=M`）——照 MV-PROTO-004 的 `tests/self_test.gd` 執行器
  - `quiz.gd`（`extends RefCounted`，全部 static／const）：
    - `const VARIANTS := 3`、`const PASS_RATE := 0.8`、`const MIN_TESTERS := 2`、`const TELLS := ["tell_parry", "tell_heavy"]`
    - `const CATEGORIES: Array`：依鍵位順序的 7 個 `{"key": int, "id": String, "label": String, "hint": String}`（值照規格書第 1 節表格）
    - `const SOUNDS: Dictionary`：依此順序 `alive→alive`、`real→real`、`hollow→fake`、`glass→fake`、`danger→danger`、`echo→echo`、`tell_parry→tell_parry`、`tell_heavy→tell_heavy`
    - `const SOUND_LABELS: Dictionary`：`alive 活物`、`real 真實`、`hollow 虛假（木）`、`glass 虛假（假光）`、`danger 危險`、`echo 殘響`、`tell_parry 前兆（可招架）`、`tell_heavy 前兆（不可招架）`
    - `static func file_name(sound: String, variant: int) -> String`（`"sfx_voc_%s_%02d.wav"`）
    - `static func all_files() -> Array`（24 個，SOUNDS 順序 × 變體 1～3）
    - `static func sound_of(file: String) -> String`（從檔名取出 sound 代號）
    - `static func category_for_key(key: int) -> String`（1～7 → 類別 id；其他回 `""`）
    - `static func category_label(id: String) -> String`
  - `audio_bank.gd`（`extends RefCounted`）：`const DIR := "res://audio"`；`static func missing(dir := DIR) -> Array`（`Quiz.all_files()` 中 `ResourceLoader.exists()` 為假的檔名）；`static func load_stream(file: String, dir := DIR) -> AudioStream`
  - `main.gd` 的 `--self-test`

- [ ] **Step 0: 開分支**

```bash
cd '<repo>'
git checkout develop
git checkout -b 'feature/MV-PROTO-005_聲音語彙盲測'
```

- [ ] **Step 1: 專案設定、進入點與測試**

`project.godot`：`config/name="MV-PROTO-005 聲音語彙盲測"`、`run/main_scene="res://main.tscn"`、`config/features=PackedStringArray("4.7")`；`[display]` 同 MV-PROTO-004（viewport 1920×1080、window override 1280×720、`canvas_items`、`keep`）；`[rendering]` `environment/defaults/default_clear_color=Color(0.1, 0.12, 0.14, 1)`。`.gitignore`：`.godot/`、`audio/`、`results/`、`shots/`。`main.tscn`：單一 `Node2D` 掛 `main.gd`。`main.gd` 只處理 `--self-test`（同 MV-PROTO-004 Task 1）。

`tests/self_test.gd`：執行器（見 Interfaces）＋下列測試。

```gdscript
const Quiz := preload("res://quiz.gd")
const AudioBank := preload("res://audio_bank.gd")

func test_category_table() -> void:
	check(Quiz.CATEGORIES.size() == 7, "應有 7 個作答類別")
	var keys := {}
	for c in Quiz.CATEGORIES:
		keys[c.key] = true
		check(not String(c.hint).is_empty(), "%s 缺一句話說明" % c.id)
	check(keys.keys() == [1, 2, 3, 4, 5, 6, 7], "鍵位應為 1～7 不重複")
	check(Quiz.CATEGORIES[5].hint == "攻擊前的蓄力聲，可以擋", "前兆（可招架）說明照規格書")
	check(Quiz.CATEGORIES[6].hint == "攻擊前的蓄力聲，多一層低沉共鳴，擋不住", "前兆（不可招架）說明照規格書")
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
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://quiz.gd` 不存在）。

- [ ] **Step 3: 實作 `quiz.gd`、`audio_bank.gd`、`sync_audio.sh`**

`sync_audio.sh` 照 MV-PROTO-004 的 `sync_art.sh`：來源 `$HERE/../../assets-test/batch0/audio`、目的 `$HERE/audio`、複製 `*.wav`、`godot --headless --path "$HERE" --import`、最後印 `SYNC ok: N 個 WAV`。

```bash
cd '<repo>/prototypes/p5-sound-test'
chmod +x sync_audio.sh && ./sync_audio.sh > /tmp/p5_sync.txt 2>&1; rc=$?; tail -1 /tmp/p5_sync.txt; echo "rc=$rc"
```

Expected：`SYNC ok: 24 個 WAV`、`rc=0`。

- [ ] **Step 4: 執行測試，確認通過**

Expected：4 項 PASS，`SUMMARY pass=4 fail=0`。

- [ ] **Step 5: Commit**

```bash
cd '<repo>'
git add prototypes/p5-sound-test
git commit -m "Scaffold sound blind test with category table and audio sync (MV-PROTO-005)"
```

---

### Task 2: 出題與彙總判定

**Files:**
- Modify: `prototypes/p5-sound-test/quiz.gd`
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：Task 1 的 `quiz.gd`
- Produces（`quiz.gd`）：
  - `static func make_trials(seed: int) -> Array`：`all_files()` 以 `RandomNumberGenerator`（`seed` 設定後）做 Fisher–Yates 打亂後回傳
  - 作答列（row）的格式：`{"tester": String, "session": String, "trial": int, "file": String, "sound": String, "actual": String, "guess": String, "correct": bool, "replays": int, "seconds": float}`
  - `static func make_row(tester: String, session: String, trial: int, file: String, guess: String, replays: int, seconds: float) -> Dictionary`（由 file 推出 sound、actual，算出 correct）
  - `static func summarize(rows: Array) -> Dictionary`，回傳：
    - `"testers"`：依出現順序的 `{"tester", "session", "answered": int, "correct": int, "complete": bool}`（每個 tester＋session 一筆；`complete`＝answered ≥ 24）
    - `"sounds"`：SOUNDS 順序的 `{sound: {"correct": int, "total": int, "rate": float, "pass": bool, "mean_replays": float, "mean_seconds": float}}`（total 為 0 時 rate 0、pass false）
    - `"confusion"`：`{sound: {category_id: int}}`，8 × 7 全部鍵都在（沒出現為 0）
    - `"tell_danger"`：int；`"tell_swap"`：int
    - `"complete_testers"`：int（有至少一個完成場次的不重複代號數）
    - `"redo"`：Array（SOUNDS 順序；rate < 0.8 的聲音，加上發生前兆↔危險誤判那幾列的 actual 聲音）
    - `"verdict"`：`"insufficient"`（complete_testers < 2）／`"pass"`（redo 為空）／`"fail"`
    - 底線開頭的 tester 整列略過

- [ ] **Step 1: 寫測試**

```gdscript
# 模擬一位受測者答完 24 題；wrong 是 {file: guess} 指定答錯的題目
func sim_rows(tester: String, wrong := {}, count := 24) -> Array:
	var rows := []
	var files := Quiz.all_files()
	for i in count:
		var f: String = files[i]
		var guess: String = wrong.get(f, Quiz.SOUNDS[Quiz.sound_of(f)])
		rows.append(Quiz.make_row(tester, "20261003-100000", i + 1, f, guess, 1, 2.0))
	return rows


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
	check(s.verdict == "insufficient", "完成者不足 2 位應為樣本不足")
	check(s.testers.size() == 2 and s.testers[1].answered == 10 and not s.testers[1].complete, "未完成場次應列出並標記")
	check(s.sounds.alive.total == 3 + 1, "未完成場次已答的題目照樣計入")


func test_complete_testers_counted_by_name() -> void:
	var again := sim_rows("A")
	for r in again:
		r.session = "20261003-110000"
	var s := Quiz.summarize(sim_rows("A") + again)
	check(s.complete_testers == 1, "同一代號跑兩次只算 1 位完成")
	check(s.verdict == "insufficient", "只有 1 位時應為樣本不足")
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`SCRIPT ERROR`（`make_trials`、`make_row`、`summarize` 不存在）。

- [ ] **Step 3: 實作 `make_trials`、`make_row`、`summarize`**

前兆↔危險誤判的定義：`actual in TELLS and guess == "danger"`，或 `actual == "danger" and guess in TELLS`。前兆兩變體互相誤判：`actual in TELLS and guess in TELLS and actual != guess`。

- [ ] **Step 4: 執行測試，確認通過**

Expected：8 項新測試 PASS，`SUMMARY pass=12 fail=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/p5-sound-test
git commit -m "Shuffle trials and summarize accuracy, confusion and verdict (MV-PROTO-005)"
```

---

### Task 3: CSV、Markdown 彙總與 `--summarize`

**Files:**
- Create: `prototypes/p5-sound-test/results.gd`
- Modify: `prototypes/p5-sound-test/main.gd`（加 `--summarize`）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：Task 2 的 row 格式與 `Quiz.summarize()`
- Produces（`results.gd`，`extends RefCounted`）：
  - `const DIR := "res://results"`、`const COLUMNS := ["tester", "session", "trial", "file", "sound", "actual", "guess", "correct", "replays", "seconds"]`
  - `static func sanitize_tester(name: String) -> String`：`strip_edges()` 後 `validate_filename()`，再把空白換成 `_`
  - `static func session_stamp() -> String`：`YYYYMMDD-HHMMSS`（本機時間）
  - `static func session_path(dir: String, tester: String, session: String) -> String`：`dir.path_join("%s_%s.csv" % [tester, session])`
  - `static func append_row(path: String, row: Dictionary) -> Error`：目錄不存在就建立；檔案不存在先寫標題列；用 `store_csv_line` 寫一列（`correct` 寫 `1`／`0`，`seconds` 取小數 2 位）
  - `static func read_dir(dir: String) -> Dictionary`：`{"rows": Array, "skipped": Array, "files": int}`；只讀副檔名 `.csv`（依檔名排序），用 `get_csv_line`；略過標題列；讀回的列轉成 Task 2 的 row 型別（`trial`、`replays` 為 int，`correct` 為 bool，`seconds` 為 float）；欄數不是 10、`trial` 不是整數、`correct` 不是 0/1、`sound` 不在 `Quiz.SOUNDS`、`guess` 不是類別 id 的列放進 `skipped`（格式 `"<檔名>:<行號>"`，行號從 1 起算、含標題列）
  - `static func render_markdown(summary: Dictionary) -> String`：依序 `## 受測者`、`## 每種聲音`、`## 混淆表`、`## 前兆與危險`、`## 結論` 五節；結論一行為 `**通過**`、`**不通過**：重做 <聲音顯示名稱，以「、」連接>`、`**樣本不足**：完成 24 題的受測者 N 位，至少要 2 位` 之一
  - `main.gd`：`--summarize` → `read_dir(DIR)`；`files == 0` 時 `printerr("SUMMARY 找不到 results/*.csv")` 並以結束碼 1 結束；否則每個 skipped 印 `SUMMARY 略過 <檔名:行號>`，印出 Markdown、寫入 `results/summary.md`，結束碼 0

- [ ] **Step 1: 寫測試**

```gdscript
const Results := preload("res://results.gd")
const TMP := "user://p5_selftest_results"

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
	check(Results.render_markdown(Quiz.summarize(sim_rows("A"))).contains("**樣本不足**"), "1 位時應為樣本不足")
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://results.gd` 不存在）。

- [ ] **Step 3: 實作 `results.gd` 與 `main.gd` 的 `--summarize`**

- [ ] **Step 4: 執行測試，確認通過**

Expected：4 項新測試 PASS，`SUMMARY pass=16 fail=0`。再驗 `--summarize` 找不到 CSV：

```bash
cd '<repo>/prototypes/p5-sound-test'
rm -rf results && godot --headless --path . -- --summarize > /tmp/p5_sum.txt 2>&1; echo "rc=$?"; grep SUMMARY /tmp/p5_sum.txt
```

Expected：`rc=1`、`SUMMARY 找不到 results/*.csv`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/p5-sound-test
git commit -m "Write per-tester CSV and summarize results to Markdown (MV-PROTO-005)"
```

---

### Task 4: 測驗畫面

**Files:**
- Create: `prototypes/p5-sound-test/quiz_screen.gd`
- Modify: `prototypes/p5-sound-test/main.gd`（預設啟動測驗、`--tester`）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：`Quiz`、`Results`、`AudioBank`
- Produces（`quiz_screen.gd`，`extends Control`，全螢幕）：
  - `const AUTO_PLAY_DELAY := 0.5`、`const NEXT_DELAY := 0.6`；`var auto_play_delay := AUTO_PLAY_DELAY`、`var next_delay := NEXT_DELAY`（測試可調短）
  - `func setup(tester: String, results_dir := Results.DIR, seed := -1, audio_dir := AudioBank.DIR) -> void`：在 `add_child` 之前呼叫；`tester` 先經 `sanitize_tester`，空字串時用 `session_stamp()`；`seed == -1` 時用 `Time.get_ticks_usec()`
  - 狀態欄位：`var state: String`（`"intro"`、`"wait"`（等自動播放）、`"trial"`、`"gap"`、`"done"`、`"error"`）、`var trials: Array`、`var trial_index: int`（從 0）、`var selected: String`、`var play_count: int`（本題播放次數）、`var csv_path: String`、`var error_text: String`、`var rows: Array`（本場已寫入的列）
  - `func press(keycode: Key, echo := false) -> void`：`_unhandled_input` 只把非 echo 的按下事件轉給它；`echo == true` 直接忽略
  - 按鍵規則：`intro` 時 Enter → 進第 1 題；`wait`／`trial` 時 Space → 立即播放（`play_count += 1`；若在 `wait` 則取消自動播放並進 `trial`），1～7 → `selected`，Enter → 只有 `state == "trial"` 且 `selected != ""` 才確認；確認時先寫 `Quiz.make_row(..., replays = play_count - 1, seconds = 自第一次播放起經過的秒數)`；`append_row` 失敗則 `state = "error"`、`error_text` 寫明路徑，不加進 `rows`、不前進；成功才加進 `rows`、`trial_index += 1`、印 `ANSWER tester=… trial=… sound=… actual=… guess=… correct=…`、停止播放、進 `gap`，`next_delay` 後下一題（第 24 題後進 `done`）；任何狀態 Esc → `get_tree().quit()`（測試不按 Esc）
  - 缺音檔時 `setup` 後的 `_ready` 進 `error`，`error_text` 列出缺少的檔名與「先執行 ./sync_audio.sh」，不建立 CSV
  - 畫面：說明頁與作答頁都顯示 7 類「鍵位 類別：一句話說明」；作答頁顯示「第 N／24 題」、目前選擇的那格高亮、「Space 重播　Enter 確認」；不顯示對錯；`done` 顯示「完成，謝謝」、本場每種聲音的答對／題數（`Quiz.summarize(rows).sounds`）與 CSV 路徑；`error` 顯示 `error_text`
  - `main.gd`：沒有其他模式參數時建立 `QuizScreen`，`--tester <代號>` 傳入 `setup`

- [ ] **Step 1: 寫測試**

```gdscript
const QuizScreen := preload("res://quiz_screen.gd")

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
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://quiz_screen.gd` 不存在）。

- [ ] **Step 3: 實作 `quiz_screen.gd` 與 `main.gd` 預設模式**

- [ ] **Step 4: 執行測試，確認通過**

Expected：8 項新測試 PASS，`SUMMARY pass=24 fail=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/p5-sound-test
git commit -m "Add blind test screen with replay, confirm and per-answer CSV (MV-PROTO-005)"
```

---

### Task 5: 主持人試聽模式與截圖

**Files:**
- Create: `prototypes/p5-sound-test/catalog_screen.gd`
- Modify: `prototypes/p5-sound-test/main.gd`（`--catalog`、`--screenshot`）
- Test: `tests/self_test.gd`（追加）

**Interfaces:**
- Consumes：`Quiz`、`AudioBank`、`QuizScreen`
- Produces：
  - `catalog_screen.gd`（`extends Control`）：`func setup(audio_dir := AudioBank.DIR) -> void`；`var state: String`（`"ready"`／`"error"`）、`var now_playing: String`（檔名）、`var status_text: String`；`func press(keycode: Key, echo := false) -> void`：1～8 依 `Quiz.SOUNDS` 順序播放該聲音，同一鍵連按輪流 01→02→03→01；`status_text` 為 `"正在播：%s %s" % [SOUND_LABELS[sound], 檔名去掉 "sfx_voc_" 與 ".wav"]`（例如「正在播：危險 danger_02」）；畫面列出 8 行「鍵位 顯示名稱」；缺音檔時 `state = "error"` 同測驗畫面；不寫任何檔案
  - `main.gd`：`--catalog` 建立試聽畫面；`--screenshot <資料夾>`：`get_window().size = Vector2i(1920, 1080)`、等 2 幀，依序截 `intro.png`（測驗說明頁）、`trial.png`（作答頁，已按 Space 與 3、未確認）、`catalog.png`（試聽頁，已按 4），每張印 `SHOT <路徑> err=<n>`，然後結束；截圖時測驗畫面的 `results_dir` 用 `user://p5_screenshot_results`，不寫進 `results/`

- [ ] **Step 1: 寫測試**

```gdscript
const CatalogScreen := preload("res://catalog_screen.gd")

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
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected：`Parse Error`（`res://catalog_screen.gd` 不存在）。

- [ ] **Step 3: 實作 `catalog_screen.gd` 與 `main.gd` 的 `--catalog`、`--screenshot`**

- [ ] **Step 4: 執行測試，確認通過**

Expected：2 項新測試 PASS，`SUMMARY pass=26 fail=0`。

- [ ] **Step 5: 截圖並目視檢查**

```bash
cd '<repo>/prototypes/p5-sound-test'
mkdir -p shots && godot --path . -- --screenshot "$PWD/shots" > /tmp/p5_shot.txt 2>&1; rc=$?; grep -E 'SHOT|SCRIPT ERROR|Parse Error' /tmp/p5_shot.txt; echo "rc=$rc"
python3 -c "from PIL import Image; [print(n, Image.open('shots/%s.png' % n).size) for n in ('intro','trial','catalog')]"
```

Expected：三行 `SHOT … err=0`、`rc=0`、三張都是 `(1920, 1080)`。用 Read 逐張看：中文字沒有變方框；說明頁 7 行說明與規格書一字不差；作答頁顯示「第 1／24 題」、第 3 格高亮、**沒有任何對錯或類別提示**；試聽頁 8 行並顯示「正在播：虛假（假光） glass_01」。字太小或擠在一起時調字級（說明文字至少 28 px），重新截圖。

- [ ] **Step 6: Commit**

```bash
git add prototypes/p5-sound-test
git commit -m "Add host catalog mode and 1080p screenshots (MV-PROTO-005)"
```

---

### Task 6: README、模擬彙總、報告、交給 Brian

**Files:**
- Create: `prototypes/p5-sound-test/README.md`、`report/MV-PROTO-005_聲音語彙盲測_<YYYY-MM-DD_HHmm>_執行報告.md`
- Modify: `todo/spec/MV-PROTO-005_聲音語彙盲測.md`（只填「Git Commit」）、`todo/todo.md`（MV-PROTO-005 狀態）、根目錄 `README.md`（原型表加一列）

- [ ] **Step 1: 寫 README**

章節：要回答的問題（規格書兩題）；第一次執行（`./sync_audio.sh`、`godot --path .`）；操作表（測驗：Enter／1～7／Space／Esc；試聽：1～8）；**盲測步驟**（照規格書「盲測步驟」5 點，含 `--tester` 與底線代號的用途）；**要唸的說明**（類別表 7 行，與 `Quiz.CATEGORIES` 一字不差）；紀錄與彙總（CSV 欄位、`--summarize`、通過條件）；自動驗證與截圖命令；結果（Brian 測完後填）。註明要戴耳機、檢視時全螢幕。

- [ ] **Step 2: 模擬彙總**

用暫時的 Python 腳本在 `results/` 寫 3 份模擬 CSV（欄位照 `Results.COLUMNS`）：A、B 全對；C 把 `tell_heavy_01` 答成 `danger`、`echo_01` 答成 `real`。執行 `--summarize`。預期 echo 8/9（0.89）達標、tell_heavy 8/9 達標但前兆↔危險誤判 1 次，所以只列出前兆（不可招架）。比對後**刪除模擬 CSV 與 `summary.md`**，避免和真正的盲測資料混在一起；結論行寫進 ledger。

Expected：`**不通過**：重做 前兆（不可招架）`；前兆↔危險誤判 1。

- [ ] **Step 3: 完整驗證**

執行驗證命令，Expected `SUMMARY pass=26 fail=0`、`rc=0`、無 `SCRIPT ERROR`；重跑 Task 5 Step 5 的截圖，三張 `err=0`。

- [ ] **Step 4: 執行報告與派工單**

- 新增 `report/MV-PROTO-005_聲音語彙盲測_<YYYY-MM-DD_HHmm>_執行報告.md`（frontmatter：`type: task-report`、`id: MV-PROTO-005`、`name: 聲音語彙盲測（獨立）`、`status: ⏸️ 暫停`、`retry_count: 0`、`pause_reason: 等待人工決策（外人盲測）`、`started_at`、`generated_at`）。內容：產出檔案表、自動驗證結果、三張截圖的目視結論、模擬彙總的結論、與規格書／MV-PROTO-000 的差異（新專案、`audio_bank.gd`）、交接備註（Brian 先用 `--catalog` 自聽，再找 2～3 位外人，測完把 `results/summary.md` 交給 AI）。
- `todo/spec/MV-PROTO-005_聲音語彙盲測.md`：「（實作完成後填寫）」換成 `git log --oneline develop..HEAD` 的清單。
- 根目錄 `README.md` 原型表加一列：`| [prototypes/p5-sound-test/](prototypes/p5-sound-test/) | MV-PROTO-005 聲音語彙盲測（獨立）：實作完成，待外人盲測 |`
- `todo/todo.md` 的 MV-PROTO-005：狀態改 `⏸️ 暫停`，暫停原因 `等待人工決策（外人盲測）`，說明欄加執行報告連結。

- [ ] **Step 5: Commit**

```bash
cd '<repo>'
git add prototypes/p5-sound-test README.md todo report
git commit -m "Document sound blind test and hand off for outside testers (MV-PROTO-005)"
```
