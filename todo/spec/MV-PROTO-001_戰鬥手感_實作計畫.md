# MV-PROTO-001 戰鬥手感 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `prototypes/core/` 建立灰盒戰鬥手感原型（單一角色、斧頭三方向、翻滾、下劈彈跳、吹箭、治療、兩種假光造物、測試房間），附 `--self-test` 自動驗證，交給 Brian 自評。

**Architecture:** 純程式建構的 Godot 專案（沿用 P1 寫法）：所有數值集中在一個 Resource（autoload `Tune` 持有），角色與敵人是各自帶狀態機的 `CharacterBody2D`，攻擊／受擊用 `Area2D` 判定框每幀掃描重疊。測試執行器用 `test_` 開頭的方法逐項跑，透過「腳本操控的意圖（intent）」驅動角色，不依賴實體輸入。

**Tech Stack:** Godot 4.7.2、GDScript；不使用外部套件。

**Spec:** [todo/spec/MV-PROTO-001_戰鬥手感.md](MV-PROTO-001_戰鬥手感.md)

## Global Constraints

- Godot 4.7.2、GDScript；**不使用 `class_name`**，跨檔引用一律 `preload` 常數（新專案沒有 `.godot` 快取時 headless 也能跑；2026-10-02 spike 已驗證 preload 常數可當型別、可 `@export`、可用 `is` 判斷）。
- 畫面基準 1920×1080、`window/stretch/mode="canvas_items"`；角色灰盒 60×180 px，原點在腳底中央。
- 數值一律從 `tn`（預設 `Tune.data`）讀取，每幀讀、不快取。**初始值寫在 `combat_tuning.gd` 的預設值**；`combat_tuning.tres` 只存 F9 存回的調整值（Godot 只寫入與預設不同的值，spike 已驗證）；遊戲一律從 `.tres` 載入。
- 測試一律用 `fresh_tuning()` 的獨立參數（命中停頓關閉），不改 `Tune.data`、不寫入 `.tres`。
- 碰撞層只用 `combat/layers.gd` 的常數。
- **驗證標準**（每個 Task 的「執行測試」都用這組命令）：

  ```bash
  cd '<repo>'
  godot --headless --fixed-fps 60 --quit-after 7200 --path prototypes/core -- --self-test > /tmp/core_selftest.txt 2>&1; rc=$?
  grep -E 'SELFTEST|SCRIPT ERROR|Parse Error' /tmp/core_selftest.txt; echo "rc=$rc"
  ```

  通過＝`rc=0`、最後一行 `SELFTEST SUMMARY pass=N fail=0`、**沒有任何 `SCRIPT ERROR` 或 `Parse Error`**（執行期錯誤時 Godot 只印錯誤並繼續，測試會被誤記為 PASS，所以必須另外 grep）。`--fixed-fps 60` 讓模擬不受真實時間限制、跑得快；`--quit-after 7200` 防止卡死。規格書的 `godot --headless --path prototypes/core -- --self-test` 也能跑，只是較慢。
- 註解用繁體中文；用到捷徑時加 `ponytail:` 註解。
- 分支 `feature/MV-PROTO-001_戰鬥手感`；每個 Task 一個 commit。
- 不做：換人、技能、Boss、招架、美術、音樂。

## Review Focus

1. **受擊無敵中掉進坑**：應仍扣 1 血並回到坑邊（不能變成無敵中免費重來）→ Task 6 `test_pit_damages_even_when_invulnerable`
2. **連續命中造成多次停頓**：時間必須恢復為 1，畫面不能卡住 → Task 10 `test_hitstop_always_recovers`
3. **碰到沒在攻擊的敵人身體**：不受傷（PROTO1-4）→ Task 8 `test_touching_enemy_body_does_no_damage`
4. **滿血時按治療**：不進入治療、不扣次數 → Task 6 `test_heal_at_full_hp_does_nothing`（`Health` 層另見 Task 2）
5. **射速限制內連按吹箭**：只發一發 → Task 7 `test_blowgun_rate_limit`

---

## 檔案結構

| 檔案 | 責任 | 建立於 |
|---|---|---|
| `prototypes/core/project.godot`、`.gitignore`、`main.tscn` | 專案設定、autoload | Task 1（Task 4 加 autoload） |
| `prototypes/core/main.gd` | 進入點：`--self-test`、組裝房間與 HUD、除錯鍵、`--demo` | Task 1（Task 9 擴充） |
| `prototypes/core/tests/self_test.gd` | 測試執行器＋全部測試 | Task 1（之後每個 Task 追加） |
| `prototypes/core/combat/layers.gd` | 碰撞層常數 | Task 1 |
| `prototypes/core/tuning/combat_tuning.gd`、`.tres`、`tune.gd` | 數值定義、存檔、數值表 | Task 1 |
| `prototypes/core/combat/health.gd` | 血量、無敵、治療次數（純邏輯） | Task 2 |
| `prototypes/core/combat/hitbox.gd`、`hurtbox.gd` | 攻擊／受擊判定 | Task 3 |
| `prototypes/core/input_setup.gd`、`player/intent.gd` | 按鍵登記、一幀的操作意圖 | Task 4 |
| `prototypes/core/player/player.gd` | 角色狀態機 | Task 4（Task 5～7 擴充） |
| `prototypes/core/level/pogo_crystal.gd` | 彈跳物 | Task 5 |
| `prototypes/core/player/blowgun.gd`、`dart.gd` | 吹箭 | Task 7 |
| `prototypes/core/enemies/enemy.gd`、`crawler.gd`、`flyer.gd` | 假光造物 | Task 8 |
| `prototypes/core/level/test_room.gd`、`ui/hud.gd` | 測試房間、HUD | Task 9 |
| `prototypes/core/fx/feedback.gd`、`sfx.gd`、`shatter.gd` | 命中回饋、佔位音效、碎裂 | Task 10 |
| `prototypes/core/README.md` | 執行、操作、自評、試玩紀錄 | Task 11 |

---

### Task 1: 專案骨架、測試執行器、參數檔

**Files:**
- Create: `prototypes/core/project.godot`、`prototypes/core/.gitignore`、`prototypes/core/main.tscn`、`prototypes/core/main.gd`
- Create: `prototypes/core/combat/layers.gd`
- Create: `prototypes/core/tuning/combat_tuning.gd`、`prototypes/core/tuning/combat_tuning.tres`、`prototypes/core/tuning/tune.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Consumes: 無
- Produces:
  - autoload `Tune`：`Tune.data`（combat_tuning 實例）、`Tune.PATH`、`Tune.save(t = null, path = PATH) -> Error`、`Tune.table(t = null) -> String`
  - `combat_tuning.gd`：第 7 節全部 `@export` 參數（名稱見 Step 3），以及 `gravity() -> float`、`jump_velocity() -> float`、`roll_speed() -> float`
  - `layers.gd`：`WORLD=1`、`PLAYER_BODY=2`、`ENEMY_BODY=4`、`PLAYER_HURT=8`、`ENEMY_HURT=16`、`POGO=32`
  - `self_test.gd` 輔助：`check(cond, msg)`、`fresh_tuning()`、`make_world() -> Node2D`（地板頂端 y=0）、`frames(n)`、`wait_until(cond: Callable, max_frames := 120) -> bool`、`free_world(w)`；`pass_count`、`fail_count`
  - `main.gd`：`--self-test` 時跑完測試以 `fail_count` 決定結束碼

- [ ] **Step 0: 開分支**

```bash
cd '<repo>'
git checkout develop
git checkout -b 'feature/MV-PROTO-001_戰鬥手感'
```

- [ ] **Step 1: 寫專案設定、進入點與測試執行器（含本 Task 的測試）**

`prototypes/core/project.godot`：

```ini
config_version=5

[application]

config/name="MV Core｜MV-PROTO-001 戰鬥手感"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7")

[autoload]

Tune="*res://tuning/tune.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]

environment/defaults/default_clear_color=Color(0.1, 0.12, 0.14, 1)
```

`prototypes/core/.gitignore`：

```text
.godot/
```

`prototypes/core/main.tscn`：

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

`prototypes/core/main.gd`：

```gdscript
extends Node2D
# MV-PROTO-001 戰鬥手感（核心專案，之後 MV-PROTO-002、003 在此延續）。
# 規格：todo/spec/MV-PROTO-001_戰鬥手感.md
# 使用者參數（放在 -- 之後）：
#   --self-test   執行自動測試後結束（結束碼 0＝全部通過）

const SelfTest := preload("res://tests/self_test.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
```

`prototypes/core/tests/self_test.gd`：

```gdscript
extends Node
# --self-test：每個 test_ 開頭的方法是一項測試，依名稱排序執行。
# 每項印一行 SELFTEST PASS|FAIL，最後印 SELFTEST SUMMARY。
# 測試一律用 fresh_tuning() 的獨立參數（命中停頓關閉），不動 Tune.data、不寫 .tres。
# 注意：執行期錯誤時 Godot 只印 SCRIPT ERROR 並繼續，該項會被記為 PASS，驗證時要另外 grep。

const Tuning := preload("res://tuning/combat_tuning.gd")
const L := preload("res://combat/layers.gd")

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


func fresh_tuning() -> Tuning:
	var t := Tuning.new()
	t.hitstop_time = 0.0
	return t


## 有地板的測試世界：地板頂端在 y=0，x 從 -3000 到 3000
func make_world() -> Node2D:
	var w := Node2D.new()
	add_child(w)
	var ground := StaticBody2D.new()
	ground.collision_layer = L.WORLD
	ground.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6000, 200)
	cs.shape = r
	cs.position = Vector2(0, 100)
	ground.add_child(cs)
	w.add_child(ground)
	return w


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## 每幀檢查 cond，成立就回傳 true；超過 max_frames 回傳 cond 最後的結果
func wait_until(cond: Callable, max_frames := 120) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


func free_world(w: Node) -> void:
	w.queue_free()
	await frames(1)


# ---- Task 1：參數檔 ----

func test_tuning_loads_from_tres() -> void:
	check(Tune.data != null, "Tune.data 沒有載入")
	check(Tune.data.resource_path == Tune.PATH, "Tune.data 應從 %s 載入，實際 %s" % [Tune.PATH, Tune.data.resource_path])
	check(is_equal_approx(fresh_tuning().run_speed, 900.0), "跑速初始值應為 900")


func test_tuning_derived_values() -> void:
	var t := fresh_tuning()
	check(is_equal_approx(t.gravity(), 5000.0), "重力應為 2×400/0.4² = 5000，實際 %s" % t.gravity())
	check(is_equal_approx(t.jump_velocity(), 2000.0), "起跳速度應為 2000，實際 %s" % t.jump_velocity())
	check(is_equal_approx(t.roll_speed(), 1200.0), "翻滾速度應為 360/0.3 = 1200，實際 %s" % t.roll_speed())


func test_tuning_table_lists_groups_and_values() -> void:
	var table := Tune.table(fresh_tuning())
	check(table.begins_with("| 分組 | 參數 | 值 |"), "數值表缺表頭")
	check(table.contains("| 移動 | run_speed | 900.0 |"), "數值表缺「移動／run_speed」")
	check(table.contains("| 斧頭 | axe_damage | 4 |"), "數值表缺「斧頭／axe_damage」")
	check(table.contains("| 吹箭 | dart_interrupt_cooldown | 3.0 |"), "數值表缺「吹箭／dart_interrupt_cooldown」")


func test_tuning_save_roundtrip() -> void:
	var t := fresh_tuning()
	t.run_speed = 777.0
	var path := "user://selftest_tuning.tres"
	check(Tune.save(t, path) == OK, "存檔應成功")
	var back = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(back != null and is_equal_approx(back.run_speed, 777.0), "存回後重新載入應保留調整值")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 2: 執行測試，確認失敗**

執行 Global Constraints 的驗證命令。
Expected: 出現 `Parse Error`（`res://tuning/tune.gd`、`res://tuning/combat_tuning.gd`、`res://combat/layers.gd` 不存在），沒有 `SELFTEST SUMMARY`。

- [ ] **Step 3: 建立碰撞層與參數檔**

`prototypes/core/combat/layers.gd`：

```gdscript
extends RefCounted
# 碰撞層（位元值），一律透過 preload 常數取用。

const WORLD := 1  # 地形
const PLAYER_BODY := 2  # 角色身體；不與敵人身體碰撞（PROTO1-4：可穿過敵人）
const ENEMY_BODY := 4  # 敵人身體
const PLAYER_HURT := 8  # 角色受擊判定
const ENEMY_HURT := 16  # 敵人受擊判定
const POGO := 32  # 彈跳物
```

`prototypes/core/tuning/combat_tuning.gd`：

```gdscript
extends Resource
# MV-PROTO-001 的全部數值（規格書第 7 節）。
# 初始值寫在這裡；F9 把調整後的值存進 combat_tuning.tres（Godot 只寫入與預設不同的值）。
# 遊戲一律從 .tres 載入（Tune.data）；數值表以 F9 印出的有效值為準。

@export_group("移動")
@export var run_speed := 900.0
@export var accel_time := 0.05
@export var decel_time := 0.04

@export_group("跳躍")
@export var jump_height := 400.0
@export var jump_apex_time := 0.4
@export var jump_cut_multiplier := 0.4
@export var fall_gravity_multiplier := 1.5
@export var max_fall_speed := 2200.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.1

@export_group("翻滾")
@export var roll_distance := 360.0
@export var roll_time := 0.3
@export var roll_iframe_start := 0.03
@export var roll_iframe_end := 0.25
@export var roll_cooldown := 0.35

@export_group("斧頭")
@export var axe_startup := 0.06
@export var axe_active := 0.08
@export var axe_recovery := 0.18
@export var axe_damage := 4
@export var axe_side_box := Vector2(140, 120)
@export var axe_up_box := Vector2(120, 150)
@export var axe_down_box := Vector2(120, 150)
@export var pogo_velocity := 1700.0
@export var side_hit_recoil := 220.0
@export var side_hit_recoil_time := 0.08

@export_group("吹箭")
@export var dart_damage := 1
@export var dart_interval := 0.35
@export var dart_speed := 2400.0
@export var dart_range := 1400.0
@export var dart_stagger_time := 0.6
@export var dart_interrupt_cooldown := 3.0
@export var aim_deadzone := 0.3

@export_group("血量與治療")
@export var max_hp := 5
@export var hurt_stun_time := 0.25
@export var hurt_invuln_time := 1.0
@export var hurt_knockback := Vector2(500, -500)
@export var heal_charges := 2
@export var heal_amount := 2
@export var heal_time := 1.0

@export_group("回饋")
@export var hitstop_time := 0.05
@export var shake_strength := 8.0
@export var shake_time := 0.12

@export_group("敵人共用")
@export var enemy_rest := 0.2
@export var enemy_flash_time := 0.08

@export_group("爬行型")
@export var crawler_hp := 12
@export var crawler_damage := 1
@export var crawler_detect_range := 450.0
@export var crawler_patrol_speed := 150.0
@export var crawler_patrol_range := 200.0
@export var crawler_telegraph := 0.6
@export var crawler_lunge_speed := 1100.0
@export var crawler_lunge_time := 0.35
@export var crawler_recover := 0.8

@export_group("飛行型")
@export var flyer_hp := 8
@export var flyer_damage := 1
@export var flyer_detect_range := 700.0
@export var flyer_hover_offset := Vector2(250, -350)
@export var flyer_hover_speed := 300.0
@export var flyer_telegraph := 0.7
@export var flyer_dive_speed := 1400.0
@export var flyer_dive_max := 900.0
@export var flyer_recover := 0.8

@export_group("場地")
@export var pit_damage := 1


## 由跳躍高度與上升時間推出重力（px/s²）
func gravity() -> float:
	return 2.0 * jump_height / (jump_apex_time * jump_apex_time)


## 起跳速度（px/s，正值；使用時取負號向上）
func jump_velocity() -> float:
	return 2.0 * jump_height / jump_apex_time


func roll_speed() -> float:
	return roll_distance / roll_time
```

`prototypes/core/tuning/combat_tuning.tres`：

```text
[gd_resource type="Resource" format=3]

[ext_resource type="Script" path="res://tuning/combat_tuning.gd" id="1"]

[resource]
script = ExtResource("1")
```

`prototypes/core/tuning/tune.gd`：

```gdscript
extends Node
# 全域參數（autoload「Tune」）。從編輯器 F5 執行時，在「遠端」場景樹選 /root/Tune，
# 檢查器裡展開 data 即可邊玩邊改；程式每幀讀取、不快取（PROTO1-1）。

const Tuning := preload("res://tuning/combat_tuning.gd")
const PATH := "res://tuning/combat_tuning.tres"

@export var data: Tuning = load(PATH)


## F9：存回參數檔；t、path 省略時把 data 存到 PATH（測試用其他路徑）
func save(t: Tuning = null, path: String = PATH) -> Error:
	if t == null:
		t = data
	return ResourceSaver.save(t, path)


## 有效值的 Markdown 數值表（貼進原型驗證計畫，驗收 5）；t 省略時用 data
func table(t: Tuning = null) -> String:
	if t == null:
		t = data
	var lines := PackedStringArray(["| 分組 | 參數 | 值 |", "|---|---|---|"])
	var group := ""
	for p in t.get_property_list():
		if p.usage & PROPERTY_USAGE_GROUP:
			group = p.name
		elif p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			lines.append("| %s | %s | %s |" % [group, p.name, str(t.get(p.name))])
	return "\n".join(lines)
```

- [ ] **Step 4: 執行測試，確認通過**

執行驗證命令。
Expected: `SELFTEST PASS test_tuning_derived_values`、`SELFTEST PASS test_tuning_loads_from_tres`、`SELFTEST PASS test_tuning_save_roundtrip`、`SELFTEST PASS test_tuning_table_lists_groups_and_values`、`SELFTEST SUMMARY pass=4 fail=0`、`rc=0`，無 `SCRIPT ERROR`／`Parse Error`。

- [ ] **Step 5: Commit**

```bash
cd '<repo>'
git add prototypes/core
git commit -m "Scaffold core prototype with tuning resource and self-test runner (MV-PROTO-001)"
```

---

### Task 2: 血量、無敵、治療次數（純邏輯）

**Files:**
- Create: `prototypes/core/combat/health.gd`
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: 無
- Produces: `health.gd`（RefCounted）：`Health.new(max_hp: int, heal_charges := 0)`；欄位 `max_hp`、`hp`、`invuln_left`、`heal_charges`；`take_damage(amount: int, invuln_after := 0.0, ignore_invuln := false) -> bool`、`tick(delta: float)`、`begin_heal() -> bool`、`finish_heal(amount: int)`、`is_dead() -> bool`

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 `const L := ...` 下一行加入：

```gdscript
const Health := preload("res://combat/health.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 2：血量 ----

func test_health_damage_and_invuln() -> void:
	var h := Health.new(5, 2)
	check(h.take_damage(1, 1.0), "第一次受擊應扣血")
	check(h.hp == 4, "受擊後血量應為 4，實際 %d" % h.hp)
	check(not h.take_damage(1, 1.0), "無敵中第二次受擊不應扣血")
	h.tick(0.5)
	check(not h.take_damage(1, 1.0), "無敵剩 0.5 秒時仍不應扣血")
	h.tick(0.6)
	check(h.take_damage(1, 1.0) and h.hp == 3, "無敵結束後應再扣血")
	check(h.take_damage(1, 1.0, true) and h.hp == 2, "ignore_invuln 應無視無敵（掉坑用）")


func test_health_heal_rules() -> void:
	var h := Health.new(5, 2)
	check(not h.begin_heal(), "滿血不能開始治療")
	check(h.heal_charges == 2, "滿血按治療不應扣次數")
	h.hp = 2
	check(h.begin_heal() and h.heal_charges == 1, "開始治療應立即扣一次（PROTO1-6）")
	h.finish_heal(2)
	check(h.hp == 4, "回 2 點後應為 4，實際 %d" % h.hp)
	check(h.begin_heal(), "還有 1 次應可治療")
	h.finish_heal(2)
	check(h.hp == 5, "回血不應超過上限，實際 %d" % h.hp)
	h.hp = 1
	check(not h.begin_heal(), "次數用完不能治療")
	h.hp = 0
	h.heal_charges = 1
	check(not h.begin_heal(), "已死不能治療")
	check(not h.take_damage(1), "已死不再扣血")
```

- [ ] **Step 2: 執行測試，確認失敗**

執行驗證命令。Expected: `Parse Error`（`res://combat/health.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/combat/health.gd`：

```gdscript
extends RefCounted
# 血量、受擊無敵、治療次數的純邏輯（不依賴物理，--self-test 直接測）。

var max_hp: int
var hp: int
var invuln_left := 0.0
var heal_charges: int


func _init(p_max_hp: int, p_heal_charges: int = 0) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	heal_charges = p_heal_charges


## 扣血；回傳是否真的扣到（受擊無敵中或已死回傳 false）。ignore_invuln：掉坑等場地傷害
func take_damage(amount: int, invuln_after: float = 0.0, ignore_invuln: bool = false) -> bool:
	if hp <= 0 or (invuln_left > 0.0 and not ignore_invuln):
		return false
	hp = maxi(hp - amount, 0)
	invuln_left = maxf(invuln_left, invuln_after)
	return true


func tick(delta: float) -> void:
	invuln_left = maxf(invuln_left - delta, 0.0)


## 開始治療：按下就扣一次（PROTO1-6）；沒有次數、滿血、已死都不能開始
func begin_heal() -> bool:
	if heal_charges <= 0 or hp >= max_hp or hp <= 0:
		return false
	heal_charges -= 1
	return true


## 治療硬直結束時呼叫；回血不超過上限
func finish_heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


func is_dead() -> bool:
	return hp <= 0
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 `SELFTEST PASS test_health_damage_and_invuln`、`SELFTEST PASS test_health_heal_rules`；`SELFTEST SUMMARY pass=6 fail=0`；`rc=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add health, invulnerability and heal-charge logic (MV-PROTO-001)"
```

---

### Task 3: 攻擊判定與受擊判定

**Files:**
- Create: `prototypes/core/combat/hurtbox.gd`、`prototypes/core/combat/hitbox.gd`
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: `layers.gd`
- Produces:
  - `hurtbox.gd`（Area2D）：`signal hurt(amount: int, source: Node, kind: StringName)`；`setup(size: Vector2, offset: Vector2, layer_bit: int)`（在加入場景前呼叫）；`receive(amount: int, source: Node, kind: StringName)`。`kind` 用 `&"melee"`、`&"dart"`、`&"enemy"`
  - `hitbox.gd`（Area2D）：欄位 `shape: CollisionShape2D`、`rect: RectangleShape2D`、`active: bool`；`configure(size: Vector2, offset: Vector2, mask: int)`、`start()`、`stop()`、`collect() -> Array`（本幀新打中的 Hurtbox，每次 `start()` 後每個目標只回傳一次）

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const Hitbox := preload("res://combat/hitbox.gd")
const Hurtbox := preload("res://combat/hurtbox.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 3：判定框 ----

func test_hitbox_hits_each_target_once_per_swing() -> void:
	var w := make_world()
	var target := Hurtbox.new()
	target.setup(Vector2(100, 100), Vector2.ZERO, L.ENEMY_HURT)
	target.position = Vector2(0, -300)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	var hb := Hitbox.new()
	hb.configure(Vector2(100, 100), Vector2.ZERO, L.ENEMY_HURT)
	hb.position = Vector2(30, -300)
	w.add_child(hb)
	await frames(3)
	check(hb.collect().is_empty(), "未啟用時不應打中")
	hb.start()
	for h in hb.collect():
		h.receive(4, hb, &"melee")
	for h in hb.collect():
		h.receive(4, hb, &"melee")
	check(got.size() == 1 and got[0][0] == 4 and got[0][1] == &"melee", "同一次揮擊只應打中一次，實際 %s" % [got])
	hb.stop()
	hb.start()
	for h in hb.collect():
		h.receive(4, hb, &"melee")
	check(got.size() == 2, "重新揮擊應可再打中，實際 %d 次" % got.size())
	await free_world(w)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`hitbox.gd`、`hurtbox.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/combat/hurtbox.gd`：

```gdscript
extends Area2D
# 受擊判定：只被偵測、不偵測別人。攻擊方呼叫 receive()，擁有者連接 hurt 訊號處理扣血。

signal hurt(amount: int, source: Node, kind: StringName)


## 加入場景前呼叫
func setup(size: Vector2, offset: Vector2, layer_bit: int) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	add_child(cs)
	collision_layer = layer_bit
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive(amount: int, source: Node, kind: StringName) -> void:
	hurt.emit(amount, source, kind)
```

`prototypes/core/combat/hitbox.gd`：

```gdscript
extends Area2D
# 攻擊判定：啟用期間由擁有者每個物理幀呼叫 collect()，掃描重疊的受擊判定；
# 每次 start() 後每個目標只回傳一次。重疊清單在物理步進後才更新，
# 所以 configure() 要在判定開始前至少 2 個物理幀呼叫（出招期間）。

const Hurtbox := preload("res://combat/hurtbox.gd")

var shape := CollisionShape2D.new()
var rect := RectangleShape2D.new()
var active := false
var _already: Array = []


func _init() -> void:
	shape.shape = rect
	add_child(shape)
	monitorable = false


func configure(size: Vector2, offset: Vector2, mask: int) -> void:
	rect.size = size
	shape.position = offset
	collision_layer = 0
	collision_mask = mask


func start() -> void:
	active = true
	_already.clear()


func stop() -> void:
	active = false


func collect() -> Array:
	var hits := []
	if not active:
		return hits
	for a in get_overlapping_areas():
		if a is Hurtbox and not _already.has(a):
			_already.append(a)
			hits.append(a)
	return hits
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: `SELFTEST PASS test_hitbox_hits_each_target_once_per_swing`；`SELFTEST SUMMARY pass=7 fail=0`；`rc=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add hitbox and hurtbox areas (MV-PROTO-001)"
```

---

### Task 4: 按鍵、操作意圖、角色移動與翻滾

**Files:**
- Create: `prototypes/core/input_setup.gd`、`prototypes/core/player/intent.gd`、`prototypes/core/player/player.gd`
- Modify: `prototypes/core/project.godot`（`[autoload]` 加 `InputSetup`）
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: `Tune.data`、`combat_tuning.gd`、`health.gd`、`hitbox.gd`、`hurtbox.gd`、`layers.gd`
- Produces:
  - autoload `InputSetup`：方案 A 的 actions（`move_left`、`move_right`、`look_up`、`look_down`、`jump`、`roll`、`attack`、`dart`、`heal`、`aim_left`、`aim_right`、`aim_up`、`aim_down`、`debug_save`、`debug_reset`）；`uses_mouse() -> bool`
  - `intent.gd`：常數 `MUZZLE := Vector2(0, -120)`；欄位 `move_x`、`up`、`down`、`jump_pressed`、`jump_held`、`roll_pressed`、`attack_pressed`、`heal_pressed`、`dart_pressed`、`aim`；`read_from_input(who: Node2D)`、`clear_presses()`
  - `player.gd`（CharacterBody2D）：
    - signals：`swung`、`hit_landed(target: Node)`、`dart_fired`、`hurt_taken`、`healed`、`died`
    - enums：`State { FREE, ATTACK, ROLL, HEAL, HURT }`、`AttackDir { SIDE, UP, DOWN }`、`Phase { STARTUP, ACTIVE, RECOVERY }`
    - 常數 `SIZE := Vector2(60, 180)`
    - 欄位：`tn`、`health`、`intent`、`scripted`、`state`、`state_time`、`facing`、`attack_dir`、`attack_phase`、`hurtbox`、`hitbox`
    - 方法：`is_roll_invulnerable() -> bool`；內部 `_enter(s)`、`_state_free(delta)`、`_apply_horizontal(delta, dir)`、`_apply_gravity(delta)`、`_try_jump() -> bool`、`_try_roll() -> bool`、`_state_roll(delta)`
  - `self_test.gd` 輔助：`make_player(w, at := Vector2.ZERO) -> Node`（scripted、fresh_tuning、站穩 3 幀）

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const Player := preload("res://player/player.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 4：按鍵、移動、翻滾 ----

## 在測試世界放一個由測試操控的角色，等它站穩
func make_player(w: Node2D, at := Vector2.ZERO) -> Node:
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = at
	w.add_child(p)
	await frames(3)
	return p


func test_input_scheme_a_registered() -> void:
	var expect := {
		"move_left": 3, "move_right": 3, "look_up": 3, "look_down": 3,
		"jump": 2, "roll": 2, "attack": 2, "dart": 2, "heal": 2,
		"aim_left": 1, "aim_right": 1, "aim_up": 1, "aim_down": 1,
		"debug_save": 1, "debug_reset": 1,
	}
	for action in expect:
		check(InputMap.has_action(action), "缺少按鍵動作 %s" % action)
		if InputMap.has_action(action):
			var n := InputMap.action_get_events(action).size()
			check(n == expect[action], "%s 應有 %d 個按鍵，實際 %d" % [action, expect[action], n])


func test_player_full_jump_height() -> void:
	var w := make_world()
	var p = await make_player(w)
	var floor_y: float = p.position.y
	p.intent.jump_pressed = true
	var top := floor_y
	for i in 60:
		p.intent.jump_held = true
		await frames(1)
		top = minf(top, p.position.y)
	var h := floor_y - top
	check(h > 360.0 and h < 440.0, "按住跳的高度應約 400 px，實際 %.1f" % h)
	check(p.is_on_floor(), "1 秒內應落回地面")
	await free_world(w)


func test_player_short_hop_is_lower() -> void:
	var w := make_world()
	var p = await make_player(w)
	var floor_y: float = p.position.y
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(3)
	p.intent.jump_held = false
	var top := floor_y
	for i in 40:
		await frames(1)
		top = minf(top, p.position.y)
	var h := floor_y - top
	check(h < 250.0, "輕按跳應明顯較低（< 250 px），實際 %.1f" % h)
	await free_world(w)


func test_player_jump_buffer_before_landing() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(0, -300))
	await wait_until(func(): return p.position.y >= -80.0, 120)  # 落地前 2～3 幀
	check(not p.is_on_floor(), "前提：按跳時還在空中")
	p.intent.jump_pressed = true
	var jumped := false
	for i in 8:
		p.intent.jump_held = true
		await frames(1)
		if p.velocity.y < -1000.0:
			jumped = true
	check(jumped, "落地前 0.1 秒內按跳，落地時應自動起跳")
	await free_world(w)


func test_roll_only_on_ground() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(0, -400))
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state != Player.State.ROLL, "空中按翻滾應無效（PROTO1-2）")
	await free_world(w)


func test_roll_distance_and_cooldown() -> void:
	var w := make_world()
	var p = await make_player(w)
	var x0: float = p.position.x
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ROLL, "地面按翻滾應進入翻滾")
	await frames(25)
	var dist: float = p.position.x - x0
	check(dist > 320.0 and dist < 420.0, "翻滾距離應約 360 px，實際 %.1f" % dist)
	check(p.state == Player.State.FREE, "翻滾 0.3 秒後應回到自由狀態")
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state != Player.State.ROLL, "冷卻中不能再翻滾")
	await free_world(w)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`res://player/player.gd` 不存在）。

- [ ] **Step 3: 實作按鍵、意圖、角色**

修改 `prototypes/core/project.godot` 的 `[autoload]` 區塊為：

```ini
[autoload]

Tune="*res://tuning/tune.gd"
InputSetup="*res://input_setup.gd"
```

`prototypes/core/input_setup.gd`：

```gdscript
extends Node
# 方案 A 按鍵（討論紀錄 E6），用程式登記；單獨執行任何場景時也有效。
# 同時記錄最後使用的裝置：滑鼠或鍵盤 → 吹箭朝游標；手把 → 右搖桿或面向。

var _last_pad := false


func _ready() -> void:
	_keys("move_left", [KEY_A, KEY_LEFT])
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_keys("look_up", [KEY_W, KEY_UP])
	_pad_axis("look_up", JOY_AXIS_LEFT_Y, -1.0)
	_keys("look_down", [KEY_S, KEY_DOWN])
	_pad_axis("look_down", JOY_AXIS_LEFT_Y, 1.0)
	_keys("jump", [KEY_SPACE])
	_pad_button("jump", JOY_BUTTON_A)
	_keys("roll", [KEY_SHIFT])
	_pad_button("roll", JOY_BUTTON_B)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_pad_button("attack", JOY_BUTTON_X)
	_mouse("dart", MOUSE_BUTTON_RIGHT)
	_pad_axis("dart", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_keys("heal", [KEY_R])
	_pad_button("heal", JOY_BUTTON_DPAD_UP)
	_pad_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_keys("debug_save", [KEY_F9])
	_keys("debug_reset", [KEY_F10])


func uses_mouse() -> bool:
	return not _last_pad


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_last_pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_last_pad = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey:
		_last_pad = false


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)  # 搖桿死區


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _pad_button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
```

`prototypes/core/player/intent.gd`：

```gdscript
extends RefCounted
# 一幀的操作意圖。實體輸入由 read_from_input() 填入；--self-test 與展示模式直接填欄位。
# 「按下」類欄位只維持一幀，player 在每幀結尾呼叫 clear_presses()。

const MUZZLE := Vector2(0, -120)  # 吹箭口相對腳底的位置

var move_x := 0.0  # -1、0、1（類比搖桿也數位化成全速，HK 手感）
var up := false
var down := false
var jump_pressed := false
var jump_held := false
var roll_pressed := false
var attack_pressed := false
var heal_pressed := false
var dart_pressed := false
var aim := Vector2.ZERO  # 零向量＝朝面向


func read_from_input(who: Node2D) -> void:
	move_x = signf(Input.get_axis("move_left", "move_right"))
	up = Input.is_action_pressed("look_up")
	down = Input.is_action_pressed("look_down")
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	roll_pressed = Input.is_action_just_pressed("roll")
	attack_pressed = Input.is_action_just_pressed("attack")
	heal_pressed = Input.is_action_just_pressed("heal")
	dart_pressed = Input.is_action_just_pressed("dart")
	aim = _read_aim(who)


func _read_aim(who: Node2D) -> Vector2:
	if InputSetup.uses_mouse():
		return (who.get_global_mouse_position() - (who.global_position + MUZZLE)).normalized()
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	return stick.normalized() if stick.length() > Tune.data.aim_deadzone else Vector2.ZERO


func clear_presses() -> void:
	jump_pressed = false
	roll_pressed = false
	attack_pressed = false
	heal_pressed = false
	dart_pressed = false
```

`prototypes/core/player/player.gd`：

```gdscript
extends CharacterBody2D
# 灰盒角色（MV-PROTO-001）：移動、跳躍、翻滾、斧頭三方向、下劈彈跳、吹箭、治療、受擊。
# 規格：todo/spec/MV-PROTO-001_戰鬥手感.md 第 3、4 節。原點在腳底中央。

const Tuning := preload("res://tuning/combat_tuning.gd")
const Health := preload("res://combat/health.gd")
const Hitbox := preload("res://combat/hitbox.gd")
const Hurtbox := preload("res://combat/hurtbox.gd")
const Intent := preload("res://player/intent.gd")
const L := preload("res://combat/layers.gd")

signal swung
signal hit_landed(target: Node)
signal dart_fired
signal hurt_taken
signal healed
signal died

enum State { FREE, ATTACK, ROLL, HEAL, HURT }
enum AttackDir { SIDE, UP, DOWN }
enum Phase { STARTUP, ACTIVE, RECOVERY }

const SIZE := Vector2(60, 180)
const COLOR := Color(0.85, 0.55, 0.25)  # Hunahpu 暖色（ART-8）

var tn: Tuning = Tune.data
var health: Health
var intent := Intent.new()
var scripted := false  # true：不讀實體輸入，由測試或展示模式填 intent

var state := State.FREE
var state_time := 0.0
var facing := 1
var jumping := false  # 上升中、放開跳躍鍵時要削減速度
var coyote_left := 0.0
var jump_buffer_left := 0.0
var roll_dir := 1
var roll_cooldown_left := 0.0
var attack_dir := AttackDir.SIDE
var attack_phase := Phase.STARTUP
var recoil_left := 0.0
var hurtbox: Hurtbox
var hitbox: Hitbox


func _ready() -> void:
	health = Health.new(tn.max_hp, tn.heal_charges)
	collision_layer = L.PLAYER_BODY
	collision_mask = L.WORLD
	var body := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	body.shape = rect
	body.position = Vector2(0, -SIZE.y / 2.0)
	add_child(body)
	hurtbox = Hurtbox.new()
	hurtbox.setup(SIZE * Vector2(0.8, 0.9), Vector2(0, -SIZE.y / 2.0), L.PLAYER_HURT)
	add_child(hurtbox)
	hitbox = Hitbox.new()
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	if not scripted:
		intent.read_from_input(self)
	health.tick(delta)
	roll_cooldown_left = maxf(roll_cooldown_left - delta, 0.0)
	_update_jump_timers(delta)
	state_time += delta
	match state:
		State.FREE:
			_state_free(delta)
		State.ROLL:
			_state_roll(delta)
	move_and_slide()
	intent.clear_presses()
	queue_redraw()


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		coyote_left = tn.coyote_time
	else:
		coyote_left = maxf(coyote_left - delta, 0.0)
	if intent.jump_pressed:
		jump_buffer_left = tn.jump_buffer
	else:
		jump_buffer_left = maxf(jump_buffer_left - delta, 0.0)


func _enter(s: State) -> void:
	if state == State.ATTACK and s != State.ATTACK:
		hitbox.stop()
	state = s
	state_time = 0.0


# ---- 自由狀態 ----

func _state_free(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)
	_apply_gravity(delta)
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	if _try_jump():
		return
	if intent.roll_pressed and _try_roll():
		return


func _apply_horizontal(delta: float, dir: float) -> void:
	var target := dir * tn.run_speed
	var t := tn.accel_time if target != 0.0 else tn.decel_time
	velocity.x = move_toward(velocity.x, target, tn.run_speed * delta / maxf(t, 0.0001))


func _apply_gravity(delta: float) -> void:
	if jumping and velocity.y < 0.0 and not intent.jump_held:
		velocity.y *= tn.jump_cut_multiplier  # 可變跳躍高度
		jumping = false
	if velocity.y >= 0.0:
		jumping = false
	var g := tn.gravity()
	if velocity.y > 0.0:
		g *= tn.fall_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, tn.max_fall_speed)


## 土狼時間＋跳躍緩衝：兩者同時有效才起跳
func _try_jump() -> bool:
	if jump_buffer_left <= 0.0 or coyote_left <= 0.0:
		return false
	velocity.y = -tn.jump_velocity()
	jump_buffer_left = 0.0
	coyote_left = 0.0
	jumping = true
	return true


# ---- 翻滾（PROTO1-2：只能在地面）----

func _try_roll() -> bool:
	if not is_on_floor() or roll_cooldown_left > 0.0:
		return false
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	roll_dir = facing
	_enter(State.ROLL)
	return true


func _state_roll(delta: float) -> void:
	velocity.x = roll_dir * tn.roll_speed()
	_apply_gravity(delta)
	if state_time >= tn.roll_time:
		roll_cooldown_left = tn.roll_cooldown
		_enter(State.FREE)


func is_roll_invulnerable() -> bool:
	return state == State.ROLL and state_time >= tn.roll_iframe_start and state_time <= tn.roll_iframe_end


# ---- 灰盒繪圖 ----

func _draw() -> void:
	var alpha := 1.0
	if is_roll_invulnerable():
		alpha = 0.45
	elif health.invuln_left > 0.0 and int(health.invuln_left * 15.0) % 2 == 0:
		alpha = 0.3
	var col := COLOR
	if state == State.HEAL:
		col = Color(0.5, 0.9, 0.6)
	var body := Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y)
	if state == State.ROLL:
		body = Rect2(-SIZE.x / 2.0 - 20.0, -SIZE.y * 0.5, SIZE.x + 40.0, SIZE.y * 0.5)
	draw_rect(body, Color(col, alpha))
	draw_rect(Rect2(facing * 14.0 - 6.0, body.position.y + 16.0, 12.0, 12.0), Color(0, 0, 0, alpha))  # 眼睛＝面向
	if state == State.ATTACK and attack_phase != Phase.STARTUP:
		var a := 0.65 if attack_phase == Phase.ACTIVE else 0.2
		draw_rect(Rect2(hitbox.shape.position - hitbox.rect.size / 2.0, hitbox.rect.size), Color(1, 1, 1, a))
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 6 項 PASS（`test_input_scheme_a_registered`、`test_player_full_jump_height`、`test_player_jump_buffer_before_landing`、`test_player_short_hop_is_lower`、`test_roll_distance_and_cooldown`、`test_roll_only_on_ground`）；`SELFTEST SUMMARY pass=13 fail=0`；`rc=0`。

若 `test_player_full_jump_height` 落在 360～440 之外：先印出實際高度確認是積分誤差還是重力公式錯（理論值約 416 px：起跳幀不扣重力），不要直接放寬範圍。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add input scheme A, player movement, jump and ground roll (MV-PROTO-001)"
```

---

### Task 5: 斧頭三方向、取消規則、下劈彈跳

**Files:**
- Create: `prototypes/core/level/pogo_crystal.gd`
- Modify: `prototypes/core/player/player.gd`（`_physics_process`、`_state_free`、`_apply_horizontal` 整個替換；檔案末尾加攻擊函式）
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: Task 4 的 `player.gd`（`_enter`、`_try_jump`、`_try_roll`、`_apply_gravity`、`hitbox`、`SIZE`、`facing`）、`hitbox.gd`、`hurtbox.gd`
- Produces:
  - `player.gd`：`_start_attack()`、`_state_attack(delta)`、`_process_hits()`；命中時 `hit_landed.emit(hurtbox)`、揮擊時 `swung.emit()`
  - `pogo_crystal.gd`（Node2D）：常數 `SIZE := Vector2(70, 70)`；內含 POGO 層的 Hurtbox

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const PogoCrystal := preload("res://level/pogo_crystal.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 5：攻擊 ----

func test_attack_cancel_only_in_recovery() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK and p.attack_phase == Player.Phase.STARTUP, "按攻擊應進入出招")
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK, "出招中按翻滾應無效")
	await wait_until(func(): return p.attack_phase == Player.Phase.ACTIVE, 30)
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ATTACK, "判定中按翻滾應無效")
	await wait_until(func(): return p.attack_phase == Player.Phase.RECOVERY, 30)
	p.intent.roll_pressed = true
	await frames(1)
	check(p.state == Player.State.ROLL, "收招中按翻滾應立刻翻滾（PROTO1-3）")
	await free_world(w)


func test_side_attack_damages_target_by_axe_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	var target := Hurtbox.new()
	target.setup(Vector2(80, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(110, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	p.intent.attack_pressed = true
	await frames(15)
	check(got.size() == 1 and got[0][0] == 4 and got[0][1] == &"melee", "側攻應打中一次、傷害 4，實際 %s" % [got])
	await free_world(w)


func test_down_slash_on_crystal_bounces() -> void:
	var w := make_world()
	var c := PogoCrystal.new()
	c.position = Vector2(0, -600)
	w.add_child(c)
	var p = await make_player(w, Vector2(0, -660))
	p.velocity = Vector2.ZERO
	p.intent.down = true
	p.intent.attack_pressed = true
	var bounced: bool = await wait_until(func(): return p.velocity.y < 0.0, 30)
	check(bounced, "下劈打中彈跳物後應向上彈（B8）")
	check(absf(p.velocity.y + 1700.0) < 1.0, "彈跳速度應為 -1700，實際 %.1f" % p.velocity.y)
	await free_world(w)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`res://level/pogo_crystal.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/level/pogo_crystal.gd`：

```gdscript
extends Node2D
# 彈跳物（假光結晶）：懸空、站不上去、碰到不傷人；只會被攻擊判定打中，供下劈彈跳（B8）。

const Hurtbox := preload("res://combat/hurtbox.gd")
const L := preload("res://combat/layers.gd")
const SIZE := Vector2(70, 70)

var flash_left := 0.0


func _ready() -> void:
	var hb := Hurtbox.new()
	hb.setup(SIZE, Vector2.ZERO, L.POGO)
	hb.hurt.connect(_on_hit)
	add_child(hb)


func _on_hit(_amount: int, _source: Node, _kind: StringName) -> void:
	flash_left = 0.1


func _process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var h := SIZE / 2.0
	var pts := PackedVector2Array([Vector2(0, -h.y), Vector2(h.x, 0), Vector2(0, h.y), Vector2(-h.x, 0)])
	draw_colored_polygon(pts, Color.WHITE if flash_left > 0.0 else Color(0.7, 0.9, 1.0))
```

`player.gd`：把 `_physics_process` 整個替換為：

```gdscript
func _physics_process(delta: float) -> void:
	if not scripted:
		intent.read_from_input(self)
	health.tick(delta)
	roll_cooldown_left = maxf(roll_cooldown_left - delta, 0.0)
	recoil_left = maxf(recoil_left - delta, 0.0)
	_update_jump_timers(delta)
	state_time += delta
	match state:
		State.FREE:
			_state_free(delta)
		State.ROLL:
			_state_roll(delta)
		State.ATTACK:
			_state_attack(delta)
	move_and_slide()
	_process_hits()
	intent.clear_presses()
	queue_redraw()
```

`player.gd`：把 `_state_free` 整個替換為：

```gdscript
func _state_free(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)
	_apply_gravity(delta)
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	if _try_jump():
		return
	if intent.roll_pressed and _try_roll():
		return
	if intent.attack_pressed:
		_start_attack()
		return
```

`player.gd`：把 `_apply_horizontal` 整個替換為：

```gdscript
func _apply_horizontal(delta: float, dir: float) -> void:
	if recoil_left > 0.0:  # 側攻命中後退
		velocity.x = -facing * tn.side_hit_recoil
		return
	var target := dir * tn.run_speed
	var t := tn.accel_time if target != 0.0 else tn.decel_time
	velocity.x = move_toward(velocity.x, target, tn.run_speed * delta / maxf(t, 0.0001))
```

`player.gd`：在 `is_roll_invulnerable()` 之後、`# ---- 灰盒繪圖 ----` 之前加入：

```gdscript
# ---- 斧頭（PROTO1-3：只有收招能被翻滾或跳躍取消）----

func _start_attack() -> void:
	if intent.down and not is_on_floor():
		attack_dir = AttackDir.DOWN
	elif intent.up:
		attack_dir = AttackDir.UP
	else:
		attack_dir = AttackDir.SIDE
	var box: Vector2
	var offset: Vector2
	match attack_dir:
		AttackDir.SIDE:
			box = tn.axe_side_box
			offset = Vector2(facing * (SIZE.x + box.x) / 2.0, -SIZE.y * 0.55)
		AttackDir.UP:
			box = tn.axe_up_box
			offset = Vector2(0, -SIZE.y - box.y / 2.0)
		AttackDir.DOWN:
			box = tn.axe_down_box
			offset = Vector2(0, box.y / 2.0)
	hitbox.configure(box, offset, L.ENEMY_HURT | L.POGO)
	attack_phase = Phase.STARTUP
	_enter(State.ATTACK)
	swung.emit()


func _state_attack(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)  # 攻擊中仍可左右移動（HK），面向不變
	_apply_gravity(delta)
	var active_at := tn.axe_startup
	var recovery_at := active_at + tn.axe_active
	var end_at := recovery_at + tn.axe_recovery
	if attack_phase == Phase.STARTUP and state_time >= active_at:
		attack_phase = Phase.ACTIVE
		hitbox.start()
	if attack_phase == Phase.ACTIVE and state_time >= recovery_at:
		attack_phase = Phase.RECOVERY
		hitbox.stop()
	if attack_phase != Phase.RECOVERY:
		return
	if intent.roll_pressed and _try_roll():
		return
	if _try_jump():
		_enter(State.FREE)
		return
	if state_time >= end_at:
		_enter(State.FREE)


func _process_hits() -> void:
	for hb in hitbox.collect():
		hb.receive(tn.axe_damage, self, &"melee")
		hit_landed.emit(hb)
		if attack_dir == AttackDir.DOWN:
			velocity.y = -tn.pogo_velocity  # 下劈彈跳（B8）
			jumping = false
		elif attack_dir == AttackDir.SIDE:
			recoil_left = tn.side_hit_recoil_time
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 3 項 PASS；`SELFTEST SUMMARY pass=16 fail=0`；`rc=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add three-way axe attacks, recovery-only cancel and pogo bounce (MV-PROTO-001)"
```

---

### Task 6: 受擊、治療、掉坑、重生

**Files:**
- Modify: `prototypes/core/player/player.gd`（`_ready` 加一行、`_physics_process` 與 `_state_free` 整個替換、檔案加函式）
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: Task 5 的 `player.gd`、`health.gd`
- Produces: `player.gd`：`_on_hurt(amount, source, kind)`（接在 `hurtbox.hurt`）、`fall_into_pit(respawn_at: Vector2)`、`respawn(at: Vector2)`；受擊發 `hurt_taken`、死亡發 `died`、治療完成發 `healed`

- [ ] **Step 1: 寫測試**

在檔案末尾加入：

```gdscript
# ---- Task 6：受擊、治療、掉坑 ----

func test_player_hurt_invuln() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.hurtbox.receive(1, null, &"enemy")
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 4, "受擊後無敵時間內再被打不應扣血，實際血量 %d" % p.health.hp)
	check(p.state == Player.State.HURT, "受擊應進入受擊狀態")
	await frames(70)
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 3, "無敵結束後應再扣血，實際血量 %d" % p.health.hp)
	await free_world(w)


func test_roll_iframes_window() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.roll_pressed = true
	await frames(1)
	check(not p.is_roll_invulnerable(), "翻滾第 0 幀還沒到無敵區間")
	await wait_until(func(): return p.state_time >= 0.1, 30)
	check(p.is_roll_invulnerable(), "翻滾 0.1 秒時應無敵")
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 5 and p.state == Player.State.ROLL, "無敵區間內受擊不應扣血、不中斷翻滾")
	await free_world(w)


func test_roll_outside_iframes_takes_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.roll_pressed = true
	await frames(1)
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.hp == 4, "翻滾無敵區間外受擊應扣血")
	await free_world(w)


func test_heal_restores_after_stiffness() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.health.hp = 2
	p.intent.heal_pressed = true
	await frames(1)
	check(p.state == Player.State.HEAL and p.health.heal_charges == 1, "按治療應進入治療並立即扣次數")
	await frames(30)
	check(p.health.hp == 2, "硬直結束前不應回血")
	await frames(35)
	check(p.health.hp == 4 and p.state == Player.State.FREE, "硬直 1 秒後應回 2 點並恢復自由，實際血量 %d" % p.health.hp)
	await free_world(w)


func test_heal_interrupted_is_lost() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.health.hp = 3
	p.intent.heal_pressed = true
	await frames(20)
	p.hurtbox.receive(1, null, &"enemy")
	await frames(70)
	check(p.health.hp == 2, "治療中被打應中斷、不回血，實際血量 %d" % p.health.hp)
	check(p.health.heal_charges == 1, "被中斷的治療次數照扣（PROTO1-6）")
	await free_world(w)


func test_heal_at_full_hp_does_nothing() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.heal_pressed = true
	await frames(1)
	check(p.state == Player.State.FREE and p.health.heal_charges == 2, "滿血按治療不應進入治療、不扣次數")
	await free_world(w)


func test_pit_damages_even_when_invulnerable() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.hurtbox.receive(1, null, &"enemy")
	check(p.health.invuln_left > 0.0, "前提：受擊無敵中")
	p.fall_into_pit(Vector2(500, 0))
	check(p.health.hp == 3, "無敵中掉坑仍應扣 1 血，實際血量 %d" % p.health.hp)
	check(p.position == Vector2(500, 0), "掉坑後應回到坑邊")
	await free_world(w)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `SELFTEST FAIL` 的有 `test_player_hurt_invuln`、`test_roll_outside_iframes_takes_damage`、`test_heal_restores_after_stiffness`、`test_heal_interrupted_is_lost`（受擊判定還沒接上、治療還沒實作）；`test_pit_damages_even_when_invulnerable` 出現 `SCRIPT ERROR`（`fall_into_pit` 不存在）。`test_roll_iframes_window` 與 `test_heal_at_full_hp_does_nothing` 這時會 PASS（行為剛好與「沒接上」一致），不算異常。

- [ ] **Step 3: 實作**

`player.gd` 的 `_ready`：在 `hurtbox.setup(...)` 那一行之後加入：

```gdscript
	hurtbox.hurt.connect(_on_hurt)
```

`player.gd`：把 `_physics_process` 整個替換為：

```gdscript
func _physics_process(delta: float) -> void:
	if not scripted:
		intent.read_from_input(self)
	health.tick(delta)
	roll_cooldown_left = maxf(roll_cooldown_left - delta, 0.0)
	recoil_left = maxf(recoil_left - delta, 0.0)
	_update_jump_timers(delta)
	state_time += delta
	match state:
		State.FREE:
			_state_free(delta)
		State.ROLL:
			_state_roll(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HEAL:
			_state_heal(delta)
		State.HURT:
			_state_hurt(delta)
	move_and_slide()
	_process_hits()
	intent.clear_presses()
	queue_redraw()
```

`player.gd`：把 `_state_free` 整個替換為：

```gdscript
func _state_free(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)
	_apply_gravity(delta)
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	if _try_jump():
		return
	if intent.roll_pressed and _try_roll():
		return
	if intent.heal_pressed and _try_heal():
		return
	if intent.attack_pressed:
		_start_attack()
		return
```

`player.gd`：在 `_process_hits()` 之後、`# ---- 灰盒繪圖 ----` 之前加入：

```gdscript
# ---- 治療（PROTO1-6：按下就扣次數，硬直結束才回血，被打就中斷）----

func _try_heal() -> bool:
	if not is_on_floor() or not health.begin_heal():
		return false
	_enter(State.HEAL)
	return true


func _state_heal(delta: float) -> void:
	velocity.x = 0.0
	_apply_gravity(delta)
	if state_time >= tn.heal_time:
		health.finish_heal(tn.heal_amount)
		healed.emit()
		_enter(State.FREE)


# ---- 受擊 ----

func _on_hurt(amount: int, source: Node, _kind: StringName) -> void:
	if is_roll_invulnerable():
		return
	if not health.take_damage(amount, tn.hurt_invuln_time):
		return
	var dir := -facing
	if source is Node2D:
		dir = 1 if global_position.x >= source.global_position.x else -1
	velocity = Vector2(dir * tn.hurt_knockback.x, tn.hurt_knockback.y)
	jumping = false
	_enter(State.HURT)  # 治療中被打 → 離開 HEAL，這次治療作廢
	hurt_taken.emit()
	if health.is_dead():
		died.emit()


func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, tn.run_speed * delta / maxf(tn.hurt_stun_time, 0.0001))
	if state_time >= tn.hurt_stun_time:
		_enter(State.FREE)


## 掉進坑：扣血（無視受擊無敵，避免無敵中免費重來），回到指定位置
func fall_into_pit(respawn_at: Vector2) -> void:
	health.take_damage(tn.pit_damage, tn.hurt_invuln_time, true)
	hurt_taken.emit()
	if health.is_dead():
		died.emit()
		return
	position = respawn_at
	velocity = Vector2.ZERO
	_enter(State.FREE)


## 重置：血量、治療次數補滿，回到指定位置
func respawn(at: Vector2) -> void:
	health = Health.new(tn.max_hp, tn.heal_charges)
	position = at
	velocity = Vector2.ZERO
	roll_cooldown_left = 0.0
	recoil_left = 0.0
	_enter(State.FREE)
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 7 項 PASS；`SELFTEST SUMMARY pass=23 fail=0`；`rc=0`；無 `SCRIPT ERROR`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add hurt, interruptible heal, pit fall and respawn (MV-PROTO-001)"
```

---

### Task 7: 吹箭與飛鏢

**Files:**
- Create: `prototypes/core/player/blowgun.gd`、`prototypes/core/player/dart.gd`
- Modify: `prototypes/core/player/player.gd`（`_ready` 加吹箭、`_state_free` 整個替換、加 `_fire_dart`、加欄位）
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: `player.gd`（`tn`、`facing`、`dart_fired`）、`intent.gd` 的 `MUZZLE`、`hurtbox.gd`、`layers.gd`
- Produces:
  - `blowgun.gd`（Node）：欄位 `player`、`cooldown_left`；`try_fire(aim: Vector2) -> Node`（冷卻中回傳 null；飛鏢加到角色的父節點）
  - `dart.gd`（Area2D）：欄位 `tn`、`direction`、`traveled`；打中 ENEMY_HURT 時 `receive(tn.dart_damage, self, &"dart")` 後消失
  - `player.gd`：欄位 `blowgun`；`_fire_dart()`（只在自由狀態呼叫，攻擊、翻滾、治療、受擊中都不能射）

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const Dart := preload("res://player/dart.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 7：吹箭 ----

func count_darts(w: Node) -> int:
	var n := 0
	for c in w.get_children():
		if c is Dart:
			n += 1
	return n


func test_blowgun_rate_limit() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.dart_pressed = true
	await frames(1)
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 1, "射速限制內連按只應發出一發，實際 %d" % count_darts(w))
	await frames(25)
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 2, "0.35 秒後應可再發，實際 %d" % count_darts(w))
	await free_world(w)


func test_dart_hits_enemy_hurtbox_for_dart_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	var target := Hurtbox.new()
	target.setup(Vector2(80, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(600, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	p.intent.dart_pressed = true
	await frames(20)
	check(got.size() == 1 and got[0][0] == 1 and got[0][1] == &"dart", "飛鏢應打中一次、傷害 1、類型 dart，實際 %s" % [got])
	check(count_darts(w) == 0, "打中後飛鏢應消失")
	await free_world(w)


func test_no_dart_during_attack() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await frames(2)
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 0, "攻擊中不能射吹箭")
	await free_world(w)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`res://player/dart.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/player/dart.gd`：

```gdscript
extends Area2D
# 飛鏢：直線飛行；碰到敵人受擊判定 → 扣血（打斷與否由敵人判斷）；碰到地形或飛滿射程就消失。

const Hurtbox := preload("res://combat/hurtbox.gd")
const L := preload("res://combat/layers.gd")

var tn
var direction := Vector2.RIGHT
var traveled := 0.0


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 8)
	cs.shape = r
	add_child(cs)
	rotation = direction.angle()
	collision_layer = 0
	collision_mask = L.ENEMY_HURT | L.WORLD
	monitorable = false


func _physics_process(delta: float) -> void:
	for a in get_overlapping_areas():
		if a is Hurtbox:
			a.receive(tn.dart_damage, self, &"dart")
			queue_free()
			return
	if not get_overlapping_bodies().is_empty():
		queue_free()
		return
	var step: Vector2 = direction * tn.dart_speed * delta  # tn 未標型別，不能用 := 推斷
	position += step
	traveled += step.length()
	if traveled >= tn.dart_range:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-14, -2, 28, 4), Color(0.95, 0.9, 0.7))
```

`prototypes/core/player/blowgun.gd`：

```gdscript
extends Node
# 吹箭：射速限制、自由瞄準；沒瞄準時朝面向（B3、B3-1）。只負責發射，飛行與命中在 dart.gd。

const Dart := preload("res://player/dart.gd")
const Intent := preload("res://player/intent.gd")

var player  # 擁有者 player.gd（不標型別，避免互相預載）
var cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


## 發射一發；射速冷卻中回傳 null。飛鏢加到角色的父節點（不跟著角色移動）
func try_fire(aim: Vector2) -> Node:
	if cooldown_left > 0.0:
		return null
	cooldown_left = player.tn.dart_interval
	var d := Dart.new()
	d.tn = player.tn
	d.direction = aim.normalized() if aim != Vector2.ZERO else Vector2(player.facing, 0)
	player.get_parent().add_child(d)
	d.global_position = player.global_position + Intent.MUZZLE
	return d
```

`player.gd` 的 preload 區加入：

```gdscript
const Blowgun := preload("res://player/blowgun.gd")
```

`player.gd` 的欄位區（`var hitbox: Hitbox` 之後）加入：

```gdscript
var blowgun: Blowgun
```

`player.gd` 的 `_ready` 末尾（`add_child(hitbox)` 之後）加入：

```gdscript
	blowgun = Blowgun.new()
	blowgun.player = self
	add_child(blowgun)
```

`player.gd`：把 `_state_free` 整個替換為：

```gdscript
func _state_free(delta: float) -> void:
	_apply_horizontal(delta, intent.move_x)
	_apply_gravity(delta)
	if intent.move_x != 0.0:
		facing = 1 if intent.move_x > 0.0 else -1
	if _try_jump():
		return
	if intent.roll_pressed and _try_roll():
		return
	if intent.heal_pressed and _try_heal():
		return
	if intent.attack_pressed:
		_start_attack()
		return
	if intent.dart_pressed:
		_fire_dart()
```

`player.gd`：在 `respawn()` 之後加入：

```gdscript
# ---- 吹箭（只在自由狀態可射；B3）----

func _fire_dart() -> void:
	if blowgun.try_fire(intent.aim) != null:
		dart_fired.emit()
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 3 項 PASS；`SELFTEST SUMMARY pass=26 fail=0`；`rc=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add blowgun with rate limit and darts (MV-PROTO-001)"
```

---

### Task 8: 假光造物（爬行型、飛行型）

**Files:**
- Create: `prototypes/core/enemies/enemy.gd`、`prototypes/core/enemies/crawler.gd`、`prototypes/core/enemies/flyer.gd`
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: `Tune.data`、`health.gd`、`hitbox.gd`、`hurtbox.gd`、`layers.gd`；目標（玩家）只用 `global_position`，受擊經 Hurtbox
- Produces:
  - `enemy.gd`（CharacterBody2D）：signals `interrupted(enemy: Node)`、`died(enemy: Node)`；enum `State { IDLE, TELEGRAPH, ATTACK, RECOVER, STAGGER, DEAD }`；欄位 `tn`、`target`、`health`、`state`、`state_time`、`interrupt_cooldown_left`、`facing`、`size`、`parryable`、`hitbox`、`hurtbox`；`start_telegraph()`
  - `crawler.gd`、`flyer.gd`：`extends "res://enemies/enemy.gd"`；flyer 另有 `dive_target: Vector2`

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const Enemy := preload("res://enemies/enemy.gd")
const Crawler := preload("res://enemies/crawler.gd")
const Flyer := preload("res://enemies/flyer.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 8：假光造物 ----

## 放一隻敵人；target 省略時給遠處的假人（敵人只會巡邏）
func make_enemy(w: Node2D, scr, at: Vector2, target: Node2D = null) -> Node:
	var e = scr.new()
	e.tn = fresh_tuning()
	e.position = at
	if target == null:
		target = Node2D.new()
		target.position = Vector2(100000, 0)
		w.add_child(target)
	e.target = target
	w.add_child(e)
	await frames(3)
	return e


func test_dart_interrupts_telegraph_with_cooldown() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(0, 0))
	e.start_telegraph()
	e.hurtbox.receive(1, null, &"dart")
	check(e.state == Enemy.State.STAGGER, "前搖中被吹箭射中應進入硬直")
	check(e.health.hp == 11, "吹箭應扣 1 血，實際 %d" % e.health.hp)
	await wait_until(func(): return e.state == Enemy.State.IDLE, 60)
	e.start_telegraph()
	e.hurtbox.receive(1, null, &"dart")
	check(e.state == Enemy.State.TELEGRAPH, "打斷冷卻中再被射中不應硬直（PROTO1-5）")
	check(e.health.hp == 10, "冷卻中射中仍應扣血")
	await free_world(w)


func test_melee_does_not_interrupt() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(0, 0))
	e.start_telegraph()
	e.hurtbox.receive(4, null, &"melee")
	check(e.state == Enemy.State.TELEGRAPH, "斧頭打中前搖中的敵人不應打斷（打斷是吹箭專屬）")
	check(e.health.hp == 8, "斧頭應扣 4 血，實際 %d" % e.health.hp)
	await free_world(w)


func test_touching_enemy_body_does_no_damage() -> void:
	var w := make_world()
	var p = await make_player(w)
	await make_enemy(w, Crawler, Vector2(0, 0))
	await frames(60)
	check(p.health.hp == 5, "碰到沒在攻擊的敵人身體不應受傷（PROTO1-4），實際血量 %d" % p.health.hp)
	await free_world(w)


func test_crawler_lunge_hits_player() -> void:
	var w := make_world()
	var p = await make_player(w)
	await make_enemy(w, Crawler, Vector2(300, 0), p)
	var hit: bool = await wait_until(func(): return p.health.hp < 5, 120)
	check(hit, "爬行型發現玩家後應前搖、撲擊並打中")
	check(p.health.hp == 4, "爬行型傷害應為 1，實際血量 %d" % p.health.hp)
	await free_world(w)


func test_flyer_dives_at_telegraph_position() -> void:
	var w := make_world()
	var p = await make_player(w)
	var e = await make_enemy(w, Flyer, Vector2(250, -350), p)
	var started: bool = await wait_until(func(): return e.state == Enemy.State.TELEGRAPH, 120)
	check(started, "飛行型就位後應開始前搖")
	check(e.dive_target == p.global_position, "俯衝目標應是前搖開始時玩家的位置")
	check(not e.parryable, "飛行型的訊號應為不可招架（暗紫鋸齒）")
	var landed: bool = await wait_until(func(): return e.state == Enemy.State.RECOVER, 120)
	check(landed and e.is_on_floor(), "俯衝後應在地面收招")
	await free_world(w)


func test_enemy_dies_at_zero_hp() -> void:
	var w := make_world()
	var e = await make_enemy(w, Crawler, Vector2(0, 0))
	var deaths := []
	e.died.connect(func(who): deaths.append(who))
	for i in 3:
		e.hurtbox.receive(4, null, &"melee")
	check(deaths.size() == 1, "血量歸零應發出一次 died，實際 %d 次" % deaths.size())
	await frames(1)
	check(not is_instance_valid(e), "死亡後應被移除")
	await free_world(w)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`res://enemies/enemy.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/enemies/enemy.gd`：

```gdscript
extends CharacterBody2D
# 假光造物共用邏輯（規格書第 4、5 節）：前搖訊號、吹箭打斷與冷卻、硬直、受擊閃白、死亡。
# 碰觸身體不傷人，只有攻擊中的判定會傷人（PROTO1-4）。子類別覆寫 _ 開頭的行為函式。

const Tuning := preload("res://tuning/combat_tuning.gd")
const Health := preload("res://combat/health.gd")
const Hitbox := preload("res://combat/hitbox.gd")
const Hurtbox := preload("res://combat/hurtbox.gd")
const L := preload("res://combat/layers.gd")

signal interrupted(enemy: Node)
signal died(enemy: Node)

enum State { IDLE, TELEGRAPH, ATTACK, RECOVER, STAGGER, DEAD }

const BASE_COLOR := Color(0.95, 0.8, 0.35)  # 假光造物：珠寶金

var tn: Tuning = Tune.data
var target: Node2D  # 玩家；null 時不會出招
var health: Health
var state := State.IDLE
var state_time := 0.0
var interrupt_cooldown_left := 0.0
var flash_left := 0.0
var facing := -1
var size := Vector2(100, 70)  # 子類別在 _init 覆寫
var parryable := true  # 前搖訊號：true＝白色圓形，false＝暗紫鋸齒
var hitbox: Hitbox
var hurtbox: Hurtbox


# ---- 子類別覆寫 ----

func _max_hp() -> int:
	return 1


func _telegraph_time() -> float:
	return 0.5


func _recover_time() -> float:
	return 0.5


func _damage() -> int:
	return 1


func _uses_gravity() -> bool:
	return true


func _idle(_delta: float) -> void:
	pass


func _begin_attack() -> void:
	pass


## 攻擊中每幀呼叫；結束時呼叫 _end_attack()
func _attack(_delta: float) -> void:
	_end_attack()


# ---- 共用 ----

func _ready() -> void:
	health = Health.new(_max_hp())
	collision_layer = L.ENEMY_BODY
	collision_mask = L.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = Vector2(0, -size.y / 2.0)
	add_child(cs)
	hurtbox = Hurtbox.new()
	hurtbox.setup(size, Vector2(0, -size.y / 2.0), L.ENEMY_HURT)
	hurtbox.hurt.connect(_on_hurt)
	add_child(hurtbox)
	hitbox = Hitbox.new()
	hitbox.configure(size * 1.1, Vector2(0, -size.y / 2.0), L.PLAYER_HURT)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	state_time += delta
	interrupt_cooldown_left = maxf(interrupt_cooldown_left - delta, 0.0)
	flash_left = maxf(flash_left - delta, 0.0)
	match state:
		State.IDLE:
			_idle(delta)
		State.TELEGRAPH:
			velocity = Vector2(0.0, velocity.y if _uses_gravity() else 0.0)
			if state_time >= _telegraph_time():
				_enter(State.ATTACK)
				hitbox.start()
				_begin_attack()
		State.ATTACK:
			_attack(delta)
		State.RECOVER, State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 4000.0 * delta)
			if not _uses_gravity():
				velocity.y = 0.0
			var limit := _recover_time() if state == State.RECOVER else tn.dart_stagger_time
			if state_time >= limit:
				_enter(State.IDLE)
	if _uses_gravity():
		velocity.y = minf(velocity.y + tn.gravity() * delta, tn.max_fall_speed)
	move_and_slide()
	for hb in hitbox.collect():
		hb.receive(_damage(), self, &"enemy")
	queue_redraw()


## 開始前搖：面向目標
func start_telegraph() -> void:
	if target != null:
		facing = 1 if target.global_position.x >= global_position.x else -1
	_enter(State.TELEGRAPH)


func _end_attack() -> void:
	_enter(State.RECOVER)


func _enter(s: State) -> void:
	if state == State.ATTACK and s != State.ATTACK:
		hitbox.stop()
	state = s
	state_time = 0.0


func _on_hurt(amount: int, _source: Node, kind: StringName) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount)
	flash_left = tn.enemy_flash_time
	if health.is_dead():
		_die()
		return
	# PROTO1-5：前搖中被吹箭射中就打斷，同一隻有冷卻；近戰不打斷（B3：打斷是吹箭專屬）
	if kind == &"dart" and state == State.TELEGRAPH and interrupt_cooldown_left <= 0.0:
		interrupt_cooldown_left = tn.dart_interrupt_cooldown
		_enter(State.STAGGER)
		interrupted.emit(self)


func _die() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	died.emit(self)
	queue_free()


# ---- 灰盒繪圖 ----

func _draw() -> void:
	var rect := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	draw_rect(rect, Color.WHITE if flash_left > 0.0 else BASE_COLOR)
	draw_rect(Rect2(facing * size.x * 0.3 - 5.0, -size.y * 0.75, 10.0, 10.0), Color.BLACK)
	if state == State.TELEGRAPH:
		draw_rect(rect, Color.WHITE, false, 5.0)  # 輪廓亮起
		_draw_signal(Vector2(0, -size.y - 50.0))
	elif state == State.STAGGER:
		draw_rect(rect, Color(0.5, 0.6, 1.0, 0.5))
	if interrupt_cooldown_left > 0.0:
		draw_circle(Vector2(size.x / 2.0 - 10.0, -size.y - 14.0), 9.0, Color(0.15, 0.15, 0.25, 0.9))  # 打斷冷卻中


func _draw_signal(at: Vector2) -> void:
	if parryable:
		draw_circle(at, 24.0, Color(1, 1, 1, 0.95))  # 可招架＝白色圓形
		return
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		var rad := 32.0 if i % 2 == 0 else 14.0
		pts.append(at + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Color(0.35, 0.1, 0.45))  # 不可招架＝暗紫鋸齒
```

`prototypes/core/enemies/crawler.gd`：

```gdscript
extends "res://enemies/enemy.gd"
# 爬行型（規格書第 5 節）：地面巡邏 → 前搖（白色圓形，可招架）→ 往前撲 → 收招（近戰空檔）。

const SIGHT_HEIGHT := 250.0  # 與玩家的高低差超過這個就看不到

var home_x := 0.0
var patrol_dir := 1


func _init() -> void:
	size = Vector2(110, 70)
	parryable = true


func _ready() -> void:
	super()
	home_x = position.x


func _max_hp() -> int:
	return tn.crawler_hp


func _telegraph_time() -> float:
	return tn.crawler_telegraph


func _recover_time() -> float:
	return tn.crawler_recover


func _damage() -> int:
	return tn.crawler_damage


func _idle(_delta: float) -> void:
	if target != null and state_time >= tn.enemy_rest and _sees_target():
		start_telegraph()
		return
	if position.x > home_x + tn.crawler_patrol_range:
		patrol_dir = -1
	elif position.x < home_x - tn.crawler_patrol_range:
		patrol_dir = 1
	facing = patrol_dir
	velocity.x = patrol_dir * tn.crawler_patrol_speed


func _sees_target() -> bool:
	var d := target.global_position - global_position
	return absf(d.x) <= tn.crawler_detect_range and absf(d.y) < SIGHT_HEIGHT


func _begin_attack() -> void:
	velocity.x = facing * tn.crawler_lunge_speed


func _attack(_delta: float) -> void:
	velocity.x = facing * tn.crawler_lunge_speed
	if state_time >= tn.crawler_lunge_time:
		_end_attack()
```

`prototypes/core/enemies/flyer.gd`：

```gdscript
extends "res://enemies/enemy.gd"
# 飛行型（規格書第 5 節）：在玩家斜上方盤旋 → 前搖（暗紫鋸齒，不可招架）
# → 朝「前搖開始時玩家的位置」俯衝 → 在地面收招（近戰空檔）→ 飛回盤旋位置。

const ARRIVE := 60.0  # 離盤旋點多近算就位、可以出招

var dive_target := Vector2.ZERO
var dive_dir := Vector2.ZERO
var dived := 0.0


func _init() -> void:
	size = Vector2(90, 60)
	parryable = false


func _max_hp() -> int:
	return tn.flyer_hp


func _telegraph_time() -> float:
	return tn.flyer_telegraph


func _recover_time() -> float:
	return tn.flyer_recover


func _damage() -> int:
	return tn.flyer_damage


func _uses_gravity() -> bool:
	return false


func _idle(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return
	var side := 1.0 if global_position.x >= target.global_position.x else -1.0
	var hover := target.global_position + Vector2(side * tn.flyer_hover_offset.x, tn.flyer_hover_offset.y)
	velocity = (hover - global_position).limit_length(tn.flyer_hover_speed)  # 越近越慢，平滑就位
	facing = 1 if target.global_position.x >= global_position.x else -1
	var near := global_position.distance_to(hover) <= ARRIVE
	var in_range := global_position.distance_to(target.global_position) <= tn.flyer_detect_range
	if near and in_range and state_time >= tn.enemy_rest:
		start_telegraph()


func start_telegraph() -> void:
	dive_target = target.global_position
	super()


func _begin_attack() -> void:
	dive_dir = global_position.direction_to(dive_target)
	dived = 0.0


func _attack(delta: float) -> void:
	velocity = dive_dir * tn.flyer_dive_speed
	dived += tn.flyer_dive_speed * delta
	if is_on_floor() or dived >= tn.flyer_dive_max:
		velocity = Vector2.ZERO
		_end_attack()
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 6 項 PASS；`SELFTEST SUMMARY pass=32 fail=0`；`rc=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add crawler and flyer false-light enemies with dart interrupt cooldown (MV-PROTO-001)"
```

---

### Task 9: 測試房間、HUD、進入點、除錯鍵

**Files:**
- Create: `prototypes/core/level/test_room.gd`、`prototypes/core/ui/hud.gd`
- Modify: `prototypes/core/main.gd`（整個替換）
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: `player.gd`（`respawn`、`fall_into_pit`、`died`、`health`、`tn`、`scripted`）、`crawler.gd`、`flyer.gd`（`target`、`tn`、`died`）、`pogo_crystal.gd`、`Tune.save()`、`Tune.table()`
- Produces:
  - `test_room.gd`（Node2D）：常數 `GROUND_Y`、`PIT_LEFT`、`PIT_WIDTH`、`RIGHT_EDGE`、`START`、`PIT_RESPAWN`；欄位 `tn`、`player`、`enemies: Array`、`camera: Camera2D`；`reset_room()`；`_add_enemy(e, at)` 內連接敵人訊號
  - `hud.gd`（Control）：欄位 `player`
  - `main.gd`：一般啟動組裝房間與 HUD；F9／F10；`--demo`

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const Room := preload("res://level/test_room.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 9：測試房間 ----

func make_room() -> Node:
	var r := Room.new()
	r.tn = fresh_tuning()
	add_child(r)
	await frames(3)
	return r


func test_room_layout() -> void:
	var r = await make_room()
	var crawlers := 0
	var flyers := 0
	var crystals := 0
	for c in r.get_children():
		if c is Crawler:
			crawlers += 1
		elif c is Flyer:
			flyers += 1
		elif c is PogoCrystal:
			crystals += 1
	check(crawlers == 2 and flyers == 1, "戰鬥房應有爬行型 ×2、飛行型 ×1，實際 %d、%d" % [crawlers, flyers])
	check(crystals == 3, "平台段應有 3 個彈跳物，實際 %d" % crystals)
	await free_world(r)


func test_room_pit_respawns_at_edge() -> void:
	var r = await make_room()
	var p = r.player
	p.position = Vector2(Room.PIT_LEFT + 500.0, Room.GROUND_Y - 300.0)
	p.velocity = Vector2.ZERO
	var fell: bool = await wait_until(func(): return p.health.hp == 4, 120)
	check(fell, "掉進坑應扣 1 血")
	await frames(2)
	check(p.position.distance_to(Room.PIT_RESPAWN) < 50.0, "掉坑後應回到坑邊，實際位置 %s" % p.position)
	await free_world(r)


func test_room_reset_restores_everything() -> void:
	var r = await make_room()
	r.player.health.hp = 1
	r.player.health.heal_charges = 0
	r.enemies[0].hurtbox.receive(100, null, &"melee")
	await frames(1)
	r.reset_room()
	await frames(2)
	check(r.player.health.hp == 5 and r.player.health.heal_charges == 2, "重置後血量與治療次數應補滿")
	check(r.enemies.size() == 3, "重置後敵人應全部重生，實際 %d" % r.enemies.size())
	check(r.player.position.distance_to(Room.START) < 50.0, "重置後角色應回起點")
	await free_world(r)


func test_room_death_resets_room() -> void:
	var r = await make_room()
	var p = r.player
	p.health.hp = 1
	p.fall_into_pit(Room.PIT_RESPAWN)
	await frames(2)
	check(p.health.hp == 5, "血量歸零應重置房間（血量補滿），實際 %d" % p.health.hp)
	check(p.position.distance_to(Room.START) < 50.0, "血量歸零應回到起點")
	await free_world(r)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`res://level/test_room.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/level/test_room.gd`：

```gdscript
extends Node2D
# 測試房間（規格書第 6 節）：左邊戰鬥房（爬行型 ×2、飛行型 ×1、兩個高台），
# 右邊平台段（坑寬 1100 px，上方 3 個彈跳物）。掉坑扣血回坑邊；血量歸零整個房間重置。
# ponytail: yagni: 地形用矩形資料建立 | upgrade if: 正式素材進來，改用 TileMapLayer

const Tuning := preload("res://tuning/combat_tuning.gd")
const L := preload("res://combat/layers.gd")
const Player := preload("res://player/player.gd")
const Crawler := preload("res://enemies/crawler.gd")
const Flyer := preload("res://enemies/flyer.gd")
const PogoCrystal := preload("res://level/pogo_crystal.gd")

const GROUND_Y := 900.0
const PIT_LEFT := 2900.0
const PIT_WIDTH := 1100.0  # 超過一般跳躍的水平距離（初始數值約 650 px）
const RIGHT_EDGE := 4700.0
const START := Vector2(300, GROUND_Y)
const PIT_RESPAWN := Vector2(PIT_LEFT - 150.0, GROUND_Y)
const SOLIDS := [
	Rect2(-200, GROUND_Y, PIT_LEFT + 200, 400),  # 戰鬥房與坑前地面
	Rect2(PIT_LEFT + PIT_WIDTH, GROUND_Y, RIGHT_EDGE - PIT_LEFT - PIT_WIDTH, 400),  # 對岸
	Rect2(900, GROUND_Y - 260, 360, 30),  # 高台 1
	Rect2(1700, GROUND_Y - 260, 360, 30),  # 高台 2
	Rect2(-300, -600, 100, 1900),  # 左牆
	Rect2(RIGHT_EDGE, -600, 100, 1900),  # 右牆
]
const CRYSTALS := [
	Vector2(PIT_LEFT + 250, GROUND_Y - 120),
	Vector2(PIT_LEFT + 550, GROUND_Y - 120),
	Vector2(PIT_LEFT + 850, GROUND_Y - 120),
]
const CRAWLERS := [Vector2(1100, GROUND_Y), Vector2(2000, GROUND_Y)]
const FLYERS := [Vector2(1500, GROUND_Y - 450)]

var tn: Tuning = Tune.data
var player
var enemies: Array = []
var camera: Camera2D


func _ready() -> void:
	for r in SOLIDS:
		_add_solid(r)
	for at in CRYSTALS:
		var c := PogoCrystal.new()
		c.position = at
		add_child(c)
	_add_pit()
	player = Player.new()
	player.tn = tn
	player.position = START
	add_child(player)
	player.died.connect(reset_room, CONNECT_DEFERRED)
	camera = Camera2D.new()
	camera.position = Vector2(0, -150)
	camera.position_smoothing_enabled = true
	camera.limit_left = -200
	camera.limit_right = int(RIGHT_EDGE)
	camera.limit_top = -400
	camera.limit_bottom = int(GROUND_Y + 400.0)
	player.add_child(camera)
	_spawn_enemies()


func _add_solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	body.add_child(cs)
	add_child(body)


func _add_pit() -> void:
	var pit := Area2D.new()
	pit.collision_layer = 0
	pit.collision_mask = L.PLAYER_BODY
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(PIT_WIDTH, 100)
	cs.shape = shape
	cs.position = Vector2(PIT_LEFT + PIT_WIDTH / 2.0, GROUND_Y + 350.0)
	pit.add_child(cs)
	pit.body_entered.connect(_on_pit_entered)
	add_child(pit)


func _on_pit_entered(body: Node) -> void:
	if body == player:
		player.call_deferred("fall_into_pit", PIT_RESPAWN)


func _spawn_enemies() -> void:
	for at in CRAWLERS:
		_add_enemy(Crawler.new(), at)
	for at in FLYERS:
		_add_enemy(Flyer.new(), at)


func _add_enemy(e: Node2D, at: Vector2) -> void:
	e.tn = tn
	e.target = player
	e.position = at
	add_child(e)
	enemies.append(e)
	e.died.connect(_on_enemy_died)


func _on_enemy_died(e: Node) -> void:
	enemies.erase(e)


## F10 與血量歸零：角色回起點並補滿，敵人全部重生
func reset_room() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	player.respawn(START)
	_spawn_enemies()


func _draw() -> void:
	for r in SOLIDS:
		draw_rect(r, Color(0.22, 0.27, 0.25))
	draw_rect(Rect2(PIT_LEFT, GROUND_Y, PIT_WIDTH, 400), Color(0.05, 0.05, 0.07))
```

`prototypes/core/ui/hud.gd`：

```gdscript
extends Control
# 灰盒 HUD：血量（方塊）、治療次數（圓點）、除錯鍵提示。

var player


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.health == null:
		return
	var h = player.health
	for i in h.max_hp:
		draw_rect(Rect2(40 + i * 46, 40, 36, 36), Color(0.95, 0.9, 0.8) if i < h.hp else Color(0.3, 0.3, 0.3))
	for i in player.tn.heal_charges:
		draw_circle(Vector2(58 + i * 46, 104), 14.0, Color(0.5, 0.9, 0.6) if i < h.heal_charges else Color(0.25, 0.3, 0.27))
	draw_string(ThemeDB.fallback_font, Vector2(40, 1050), "F9 存回數值並印出數值表　F10 重置房間", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
```

`prototypes/core/main.gd`：整個替換為：

```gdscript
extends Node2D
# MV-PROTO-001 戰鬥手感（核心專案，之後 MV-PROTO-002、003 在此延續）。
# 規格：todo/spec/MV-PROTO-001_戰鬥手感.md
# 使用者參數（放在 -- 之後）：
#   --self-test   執行自動測試後結束（結束碼 0＝全部通過）
#   --demo        展示模式：角色站在敵人旁不動，供錄影截圖檢查前搖訊號

const SelfTest := preload("res://tests/self_test.gd")
const Room := preload("res://level/test_room.gd")
const Hud := preload("res://ui/hud.gd")

var room


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		var t := SelfTest.new()
		add_child(t)
		await t.run()
		get_tree().quit(0 if t.fail_count == 0 else 1)
		return
	room = Room.new()
	add_child(room)
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Hud.new()
	hud.player = room.player
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	if "--demo" in args:
		room.player.scripted = true
		room.player.position = Vector2(1350, Room.GROUND_Y)


func _unhandled_input(event: InputEvent) -> void:
	if room == null:
		return
	if event.is_action_pressed("debug_save"):
		var err := Tune.save()
		print(Tune.table())
		print("TUNING saved err=%d" % err)
	elif event.is_action_pressed("debug_reset"):
		room.reset_room()
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 4 項 PASS；`SELFTEST SUMMARY pass=36 fail=0`；`rc=0`。

再確認一般啟動沒有錯誤：

```bash
cd '<repo>'
godot --headless --fixed-fps 60 --quit-after 300 --path prototypes/core > /tmp/core_run.txt 2>&1; rc=$?
grep -E 'SCRIPT ERROR|Parse Error|ERROR' /tmp/core_run.txt; echo "rc=$rc"
```

Expected: 沒有任何錯誤行；`rc=0`。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add test room, HUD, debug keys and demo mode (MV-PROTO-001)"
```

---

### Task 10: 命中回饋、佔位音效、碎裂

**Files:**
- Create: `prototypes/core/fx/feedback.gd`、`prototypes/core/fx/sfx.gd`、`prototypes/core/fx/shatter.gd`
- Modify: `prototypes/core/level/test_room.gd`（加回饋與訊號連接）
- Test: `prototypes/core/tests/self_test.gd`（追加）

**Interfaces:**
- Consumes: `test_room.gd`（`player`、`camera`、`_add_enemy`）、player signals（`swung`、`hit_landed`、`dart_fired`、`hurt_taken`、`healed`）、enemy signals（`interrupted`、`died`）
- Produces:
  - `feedback.gd`（Node）：欄位 `tn`、`camera`；`hitstop()`、`shake()`、`play(sound: StringName)`；停頓以真實時間結束、連續命中只延長
  - `sfx.gd`：`static build_all() -> Dictionary`，鍵為 `&"swing"`、`&"hit"`、`&"dart"`、`&"interrupt"`、`&"hurt"`、`&"heal"`、`&"pogo"`、`&"shatter"`
  - `shatter.gd`（Node2D）：產生後自行淡出、移除

- [ ] **Step 1: 寫測試**

在 `tests/self_test.gd` 的 preload 區加入：

```gdscript
const Feedback := preload("res://fx/feedback.gd")
const Sfx := preload("res://fx/sfx.gd")
```

在檔案末尾加入：

```gdscript
# ---- Task 10：回饋 ----

func test_hitstop_always_recovers() -> void:
	var f := Feedback.new()
	f.tn = fresh_tuning()
	f.tn.hitstop_time = 0.05
	add_child(f)
	f.hitstop()
	f.hitstop()
	check(Engine.time_scale == 0.0, "命中停頓中時間應暫停")
	OS.delay_msec(80)
	f._process(0.0)
	check(Engine.time_scale == 1.0, "停頓時間過後應恢復（連續命中也不會卡住）")
	Engine.time_scale = 1.0
	f.queue_free()
	await frames(1)


func test_sfx_bank_complete() -> void:
	var bank := Sfx.build_all()
	for s in [&"swing", &"hit", &"dart", &"interrupt", &"hurt", &"heal", &"pogo", &"shatter"]:
		check(bank.has(s), "缺少佔位音效 %s" % s)
		if bank.has(s):
			check(bank[s].data.size() > 0, "%s 沒有聲音資料" % s)
```

- [ ] **Step 2: 執行測試，確認失敗**

Expected: `Parse Error`（`res://fx/feedback.gd` 不存在）。

- [ ] **Step 3: 實作**

`prototypes/core/fx/sfx.gd`：

```gdscript
extends RefCounted
# 佔位音效：啟動時用程式合成（沿用 P1 sound_bank.gd 的做法），只為手感回饋，不代表正式音色。
# ponytail: native: AudioStreamWAV 程式合成 | upgrade if: 正式音效到位，改為載入檔案

const RATE := 22050.0
const LENGTHS := {
	&"swing": 0.09, &"hit": 0.12, &"dart": 0.05, &"interrupt": 0.18,
	&"hurt": 0.2, &"heal": 0.35, &"pogo": 0.14, &"shatter": 0.25,
}


static func build_all() -> Dictionary:
	var bank := {}
	for sound in LENGTHS:
		bank[sound] = _make(sound, LENGTHS[sound])
	return bank


static func _make(sound: StringName, length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(sample(sound, i / RATE, length), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = data
	return wav


## s：秒；length：總長
static func sample(sound: StringName, s: float, length: float) -> float:
	var env := 1.0 - s / length
	match sound:
		&"swing":  # 揮擊：漸弱的氣流雜音
			return env * env * 0.5 * (randf() * 2.0 - 1.0)
		&"hit":  # 命中：低頻悶擊
			return exp(-s * 30.0) * sin(TAU * 90.0 * s) + 0.2 * exp(-s * 60.0) * (randf() * 2.0 - 1.0)
		&"dart":  # 吹箭：短促的高頻氣音
			return env * 0.4 * sin(TAU * 1400.0 * s) * (0.6 + 0.4 * randf())
		&"interrupt":  # 打斷：兩聲清脆上揚
			var f := 880.0 if s < length / 2.0 else 1320.0
			return env * 0.5 * sin(TAU * f * s)
		&"hurt":  # 受擊：低沉嗡聲
			return env * 0.6 * signf(sin(TAU * 110.0 * s))
		&"heal":  # 治療完成：上滑音
			return env * 0.4 * sin(TAU * (300.0 + 600.0 * s / length) * s)
		&"pogo":  # 彈跳：彈簧聲
			return env * 0.5 * sin(TAU * (500.0 + 300.0 * sin(TAU * 8.0 * s)) * s)
		&"shatter":  # 碎裂：空洞的玻璃雜音（虛假類）
			return env * env * 0.4 * (randf() * 2.0 - 1.0) * sin(TAU * 2400.0 * s)
	return 0.0
```

`prototypes/core/fx/feedback.gd`：

```gdscript
extends Node
# 命中回饋（規格書第 4、8 節）：命中停頓、晃鏡頭、佔位音效。
# 停頓用真實時間計算結束點：連續命中只會延長、不會卡住（Engine.time_scale 必回到 1）。

const Sfx := preload("res://fx/sfx.gd")
const Tuning := preload("res://tuning/combat_tuning.gd")

var tn: Tuning = Tune.data
var camera: Camera2D
var _hitstop_end_ms := 0
var _shake_left := 0.0
var _bank := {}
var _players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bank = Sfx.build_all()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func hitstop() -> void:
	if tn.hitstop_time <= 0.0:
		return
	_hitstop_end_ms = maxi(_hitstop_end_ms, Time.get_ticks_msec() + int(tn.hitstop_time * 1000.0))
	Engine.time_scale = 0.0


func shake() -> void:
	_shake_left = tn.shake_time


func play(sound: StringName) -> void:
	if not _bank.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _bank[sound]
			p.play()
			return


func _process(delta: float) -> void:
	if Engine.time_scale == 0.0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		Engine.time_scale = 1.0
	if camera == null:
		return
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tn.shake_strength
	else:
		camera.offset = Vector2.ZERO


func _exit_tree() -> void:
	Engine.time_scale = 1.0
```

`prototypes/core/fx/shatter.gd`：

```gdscript
extends Node2D
# 假光造物碎成光點（ART-3）：灰盒用小方塊向外飛散、淡出後自行移除。

const COUNT := 14
const LIFE := 0.45

var _parts: Array = []  # 每個元素：[位置, 速度]
var _age := 0.0


func _ready() -> void:
	for i in COUNT:
		var ang := randf() * TAU
		_parts.append([Vector2.ZERO, Vector2(cos(ang), sin(ang)) * randf_range(200.0, 600.0)])


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for p in _parts:
		p[0] += p[1] * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _age / LIFE
	for p in _parts:
		draw_rect(Rect2(p[0] - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.95, 0.7, a))
```

`test_room.gd` 的 preload 區加入：

```gdscript
const Feedback := preload("res://fx/feedback.gd")
const Shatter := preload("res://fx/shatter.gd")
```

`test_room.gd` 的欄位區（`var camera: Camera2D` 之後）加入：

```gdscript
var feedback
```

`test_room.gd` 的 `_ready`：在 `player.add_child(camera)` 之後、`_spawn_enemies()` 之前加入：

```gdscript
	feedback = Feedback.new()
	feedback.tn = tn
	feedback.camera = camera
	add_child(feedback)
	player.swung.connect(_on_player_swung)
	player.hit_landed.connect(_on_player_hit)
	player.dart_fired.connect(_on_player_dart)
	player.hurt_taken.connect(_on_player_hurt)
	player.healed.connect(_on_player_healed)
```

`test_room.gd`：把 `_add_enemy` 與 `_on_enemy_died` 整個替換為：

```gdscript
func _add_enemy(e: Node2D, at: Vector2) -> void:
	e.tn = tn
	e.target = player
	e.position = at
	add_child(e)
	enemies.append(e)
	e.died.connect(_on_enemy_died)
	e.interrupted.connect(_on_enemy_interrupted)


func _on_enemy_died(e: Node) -> void:
	enemies.erase(e)
	var s := Shatter.new()
	s.position = e.position + Vector2(0, -40)
	add_child(s)
	feedback.play(&"shatter")


func _on_enemy_interrupted(_e: Node) -> void:
	feedback.play(&"interrupt")


func _on_player_swung() -> void:
	feedback.play(&"swing")


func _on_player_hit(target: Node) -> void:
	feedback.hitstop()
	feedback.shake()
	feedback.play(&"pogo" if target.collision_layer & L.POGO else &"hit")


func _on_player_dart() -> void:
	feedback.play(&"dart")


func _on_player_hurt() -> void:
	feedback.play(&"hurt")
	feedback.shake()


func _on_player_healed() -> void:
	feedback.play(&"heal")
```

- [ ] **Step 4: 執行測試，確認通過**

Expected: 新增 2 項 PASS；`SELFTEST SUMMARY pass=38 fail=0`；`rc=0`。再跑一次 Task 9 Step 4 的「一般啟動」命令，Expected 沒有錯誤行。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core
git commit -m "Add hitstop, camera shake, placeholder sfx and shatter feedback (MV-PROTO-001)"
```

---

### Task 11: README、畫面驗證、收尾

**Files:**
- Create: `prototypes/core/README.md`
- Modify: `todo/spec/MV-PROTO-001_戰鬥手感.md`（只填「Git Commit」一節）、`todo/todo.md`（MV-PROTO-001 狀態）、`README.md`（原型表加一列）
- Create: `report/MV-PROTO-001_戰鬥手感_<YYYY-MM-DD_HHmm>_執行報告.md`

**Interfaces:**
- Consumes: 全部前述檔案
- Produces: 可交給 Brian 自評的原型與說明

- [ ] **Step 1: 寫 README**

`prototypes/core/README.md`：

````markdown
# 核心專案｜MV-PROTO-001 戰鬥手感

> 規格：[todo/spec/MV-PROTO-001_戰鬥手感.md](../../todo/spec/MV-PROTO-001_戰鬥手感.md)
> 計畫：[原型驗證計畫](../../docs/design/MV-PROTO-000_原型驗證計畫.md) 第 3 節
> 之後 MV-PROTO-002（換人與武器）、MV-PROTO-003（交織式 Boss）在這個專案延續。

## 要回答的問題

1. 以《Hollow Knight》為主、借《死亡細胞》的手感能不能成立？
2. 翻滾無敵與跳躍閃避的分工清不清楚？
3. 吹箭（低傷害、打斷）會不會架空近戰？

## 執行

需要 Godot 4.7。

```bash
godot --path prototypes/core
```

調數值時請改從 Godot 編輯器開啟 `prototypes/core`、按 F5 執行（見「調數值」）。

## 操作（方案 A）

| 動作 | 手把 | 鍵盤＋滑鼠 |
|---|---|---|
| 移動 | 左搖桿 | A／D |
| 上攻／下劈 | 左搖桿上＋攻擊／空中左搖桿下＋攻擊 | W＋攻擊／空中 S＋攻擊 |
| 跳躍（按住跳得更高） | A | Space |
| 翻滾（只能在地面，中段無敵） | B | Shift |
| 攻擊（斧頭） | X | 滑鼠左鍵 |
| 吹箭 | 右搖桿瞄準＋RT；沒推右搖桿時朝面向 | 滑鼠右鍵，朝游標 |
| 治療（按下就扣次數，硬直 1 秒，被打就中斷） | 十字鍵上 | R |
| 存回數值並印出數值表 | — | F9 |
| 重置房間 | — | F10 |

## 房間

- 左邊戰鬥房：爬行型 ×2（前搖白色圓形＝可招架）、飛行型 ×1（前搖暗紫鋸齒＝不可招架）。這一版沒有招架，兩種都靠翻滾或跳躍躲。
- 敵人前搖中用吹箭射中會被打斷（硬直）；同一隻 3 秒內不能再被打斷，頭上會出現暗色圓點。
- 右邊平台段：坑上方 3 個彈跳物，連續下劈彈跳才過得去。掉坑扣 1 血、回坑邊。

## 調數值（驗收 5）

1. 用 Godot 編輯器開啟 `prototypes/core`，按 F5 執行。
2. 編輯器左側場景面板切到「遠端」，選 `/root/Tune`，在檢查器展開 `data`，直接改數值，立即生效。
3. 調到滿意時在遊戲中按 F9：數值存回 `tuning/combat_tuning.tres`，主控台（編輯器下方「輸出」）印出 Markdown 數值表，貼進原型驗證計畫。

初始值在 `tuning/combat_tuning.gd`；`.tres` 只存和初始值不同的數值。

## 自評步驟

| # | 驗收 | 怎麼做 |
|---|---|---|
| 1 | 連續玩 10 分鐘沒有「卡手」 | 戰鬥房反覆打（F10 重置），記下每次覺得「按了沒反應」或「不想要卻動了」的時刻 |
| 2 | 讀前搖能無傷打倒 3 隻敵人 | F10 重置後一口氣打完 3 隻、血量保持 5 格 |
| 3 | 下劈彈跳能穩定連續 3 次 | 平台段連續過坑 5 次，至少 4 次成功 |
| 4 | 吹箭打斷前搖有明確回饋 | 射中前搖中的敵人：有打斷音效、敵人變藍、頭上出現冷卻圓點 |
| 5 | 數值表寫回原型驗證計畫 | 按 F9，把主控台的表貼進 `docs/design/MV-PROTO-000_原型驗證計畫.md` |

## 試玩紀錄

| 日期 | 試玩者 | 版本（commit） | 觀察 | 原話 |
|---|---|---|---|---|
| | | | | |

## 自動驗證

```bash
godot --headless --fixed-fps 60 --quit-after 7200 --path prototypes/core -- --self-test
```

每項印一行 `SELFTEST PASS|FAIL`，最後 `SELFTEST SUMMARY`；有失敗時結束碼非 0。輸出中若出現 `SCRIPT ERROR` 也算失敗（Godot 遇到執行期錯誤會繼續跑）。

## 展示模式（截圖驗證用）

```bash
godot --path prototypes/core --write-movie /tmp/core_demo/frame.png --fixed-fps 30 --quit-after 90 -- --demo
```

角色站在敵人旁不動，錄下前搖訊號與受擊。
````

- [ ] **Step 2: 畫面驗證**

```bash
mkdir -p /tmp/core_demo && rm -f /tmp/core_demo/*.png
cd '<repo>'
godot --path prototypes/core --write-movie /tmp/core_demo/frame.png --fixed-fps 30 --quit-after 90 -- --demo > /tmp/core_demo.txt 2>&1; rc=$?
grep -E 'SCRIPT ERROR|Parse Error' /tmp/core_demo.txt; echo "rc=$rc"; ls /tmp/core_demo | head -3; ls /tmp/core_demo | wc -l
```

Expected: 沒有錯誤行；`rc=0`；約 90 張 PNG。用 Read 工具開啟 `frame00000010.png`、`frame00000030.png`、`frame00000060.png`，確認：角色（暖色方塊）、爬行型與飛行型（金色方塊）、前搖時輪廓變白並出現白色圓形或暗紫鋸齒、HUD 左上 5 個血量方塊與 2 個治療圓點、底部除錯提示文字（中文可正常顯示）。任何一項看不到就回頭修正繪圖程式。

- [ ] **Step 3: 完整跑一次自動測試**

執行 Global Constraints 的驗證命令。Expected: `SELFTEST SUMMARY pass=38 fail=0`、`rc=0`、無 `SCRIPT ERROR`／`Parse Error`。

- [ ] **Step 4: 文件與派工單**

- `todo/spec/MV-PROTO-001_戰鬥手感.md`：把「## Git Commit」下的「（實作完成後填寫）」換成本分支的 commit 清單（`git log --oneline develop..HEAD` 的輸出）。
- 根目錄 `README.md` 的「原型」表加一列：`| [prototypes/core/](prototypes/core/) | 核心專案；MV-PROTO-001 戰鬥手感（實作完成、待 Brian 自評） |`
- `todo/todo.md` 的 MV-PROTO-001：狀態改 `⏸️ 暫停`，暫停原因 `等待人工決策（Brian 自評）`，說明欄加上 README 與執行報告連結。
- 新增 `report/MV-PROTO-001_戰鬥手感_<YYYY-MM-DD_HHmm>_執行報告.md`（frontmatter：`type: task-report`、`id: MV-PROTO-001`、`name: 戰鬥手感`、`status: ⏸️ 暫停`、`retry_count: 0`、`pause_reason: 等待人工決策（Brian 自評）`、`started_at`、`generated_at`），內容：產出檔案表、測試結果（貼 SUMMARY 行）、畫面驗證結論、與規格書的差異（初始值放在 `.gd` 預設值、`.tres` 只存調整值；驗證命令多了 `--fixed-fps`、`--quit-after`）、交接備註（自評步驟見 `prototypes/core/README.md`）。

- [ ] **Step 5: Commit**

```bash
git add prototypes/core README.md todo report
git commit -m "Document core prototype and hand off for self-evaluation (MV-PROTO-001)"
```

- [ ] **Step 6: 分支收尾（dispatch-task-execution 後處理）**

```bash
git branch -m 'feature/MV-PROTO-001_戰鬥手感' 'end/MV-PROTO-001_戰鬥手感'
godot --headless --fixed-fps 60 --quit-after 7200 --path prototypes/core -- --self-test > /tmp/core_selftest.txt 2>&1; rc=$?
grep -E 'SELFTEST SUMMARY|SCRIPT ERROR|Parse Error' /tmp/core_selftest.txt; echo "rc=$rc"
```

CI（自動測試）通過後：

```bash
git checkout develop
git merge --no-ff 'end/MV-PROTO-001_戰鬥手感' -m "Merge MV-PROTO-001 combat-feel prototype into develop"
rtk proxy git log --oneline -3
```

push 等 Brian 指示。
