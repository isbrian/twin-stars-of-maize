# MV-PROTO-002 換人與武器 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在核心專案加上兩兄弟一鍵換人、斧頭／掘棒／球具三種武器、球具招架、Hunahpu 二段跳、Xbalanque「讓工具自己動」與木障，以及需要換人的探索區與招架練習工具。

**Architecture:** 場上只有一個 `player.gd` 身體，換人只切換「角色資料」（`twin.gd`）；武器動作改由 `weapons.gd` 的資料決定，球具的側攻與上攻變成新的 `PARRY` 狀態。木障是地形＋受擊判定，被 Xbalanque 的飛鏢標記時由角色派出 `tool_spirit.gd`。測試房間往右延伸成探索區。

**Tech Stack:** Godot 4.7.2、GDScript（不用 `class_name`，一律 `preload` 常數）；自動測試沿用 `tests/self_test.gd` 的 `--self-test` 執行器。

**Spec:** [todo/spec/MV-PROTO-002_換人與武器.md](MV-PROTO-002_換人與武器.md)

## Global Constraints

- 分支 `feature/MV-PROTO-002_換人與武器`（已從 `develop` 開好，規格書在上面）。
- 不用 `class_name`；跨檔引用用 `preload` 常數；未標型別的變數不能用 `:=` 推斷（例：`var x: float = obj.prop`）。
- 數值一律放 `tuning/combat_tuning.gd`，程式每幀讀 `tn`（不快取）；新群組名稱：`換人`、`二段跳`、`掘棒`、`球具`、`工具`、`練習對象`。
- 節點與地形用程式建立；場景檔不新增。
- 兩兄弟的基礎數值完全相同；Hunahpu 主色沿用 `Color(0.85, 0.55, 0.25)`，Xbalanque 主色 `Color(0.25, 0.65, 0.7)`。
- 佔位音效全部程式合成，避開 AUDIO_SPEC 第 2 節各類語彙特徵；木障悶響「低沉、短、沒有回聲」。
- 探索區不放任何文字提示。
- MV-PROTO-001 原有測試除本計畫明列要改預期值的 4 項外，全部不改、全部 PASS。
- 測試指令（每個 Task 結尾用這個）：
  ```bash
  godot --headless --fixed-fps 60 --quit-after 18000 --path prototypes/core -- --self-test > /tmp/p2_selftest.log 2>&1; tail -3 /tmp/p2_selftest.log; grep -c "SCRIPT ERROR" /tmp/p2_selftest.log
  ```
  通過的定義：`SELFTEST SUMMARY ... fail=0` 且 `SCRIPT ERROR` 計數為 0。（`--quit-after` 從 7200 提高到 18000：新增的機器人測試會跑比較多幀。）

## 本計畫的決定（規格書沒寫到的細節）

| # | 決定 | 理由 |
|---|---|---|
| D1 | 二段跳起跳速度＝`jump_velocity() * sqrt(double_jump_ratio)` | 高度與速度平方成正比，這樣第二跳高度才是 `jump_height × 0.75` |
| D2 | 招架窗口內「從背後被打」記為白揮 | 規格的三種結果中最接近「沒擋到」 |
| D3 | 練習對象放在**起點左側、緊鄰左牆**（x = -80），攻擊判定是面前 200 px 的方框 | 起點右側在爬行型偵測範圍（450 px）內，練習會被打擾；練習對象不往前撲，判定要往前延伸，但不能打到剛出生的角色（起點 x = 300） |
| D4 | F10／死亡重置時回到 Hunahpu，兩人回預設武器，收回在外的工具 | 「角色回起點」即回到初始狀態 |
| D5 | 木障的受擊框比實體每邊大 4 px | 飛鏢射線同時碰到實體與受擊框時，先碰到受擊框才能觸發標記 |
| D6 | 飛鏢在**發射時**決定能不能標記木障（`marks_barrier`） | 飛行中換人不影響已射出的飛鏢，結果可預期 |
| D7 | 傷害為 0 的命中：對敵人不呼叫 `receive`、不發 `hit_landed`；對彈跳物照舊發 `hit_landed` | 規格「不觸發命中停頓、閃白、扣血」，但彈跳物的彈跳音效照舊 |
| D8 | 改預期值的舊測試：`test_input_scheme_a_registered`（新增按鍵）、`test_room_layout`（敵人 3＋2）、`test_room_reset_restores_everything`（敵人 5）、`test_room_enemy_falling_into_pit_dies`（剩 4） | 房間內容與按鍵依規格改變；斷言的意義不變 |

## Review Focus

1. 飛鏢飛行中換人：已射出的 Xbalanque 飛鏢仍能標記木障，Hunahpu 換回來不影響（Task 6 測試 `test_dart_mark_decided_at_fire`）。
2. 角色與敵人 x 座標完全相同時招架：視為正面（Task 4 測試 `test_parry_same_x_counts_as_front`）。
3. 工具在外時按 F10：工具消失、木障復原，之後再標記仍能派出工具（Task 8 測試 `test_room_reset_recalls_tool`）。
4. 攻擊判定中用除錯鍵換武器：攻擊立即結束、判定關閉，不會殘留傷害（Task 3 測試 `test_set_weapon_mid_attack_stops_hitbox`）。
5. 二段跳後死亡重置：重生後 `air_jump_used` 為 false（Task 5 測試 `test_respawn_restores_double_jump`）。

---

### Task 1: 數值、兩兄弟與武器資料、按鍵

**Files:**
- Modify: `prototypes/core/tuning/combat_tuning.gd`
- Create: `prototypes/core/player/twin.gd`
- Create: `prototypes/core/player/weapons.gd`
- Modify: `prototypes/core/input_setup.gd`、`prototypes/core/player/intent.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Produces:
  - `combat_tuning.gd` 新欄位（規格第 10 節）：`swap_cooldown := 0.3`、`double_jump_ratio := 0.75`、`stick_startup := 0.10`、`stick_active := 0.08`、`stick_recovery := 0.22`、`stick_damage := 4`、`stick_side_box := Vector2(210, 60)`、`stick_up_box := Vector2(60, 210)`、`stick_down_box := Vector2(60, 210)`、`parry_window := 0.2`、`parry_recovery := 0.35`、`parry_stagger := 1.2`、`ballgear_down_box := Vector2(120, 150)`、`tool_speed := 900.0`、`tool_chops := 3`、`tool_chop_time := 0.6`、`dummy_interval := 2.0`
  - `weapons.gd`（`extends RefCounted`）：`enum Weapon { AXE, STICK, BALLGEAR }`、`enum Dir { SIDE, UP, DOWN }`（值與 `player.gd` 的 `AttackDir` 相同）、`const NAMES := ["斧頭", "掘棒", "球具"]`、`static func timing(w: int, tn) -> Vector3`（x 出招、y 判定、z 收招；球具的下劈用斧頭的時間）、`static func box(w: int, dir: int, tn) -> Vector2`、`static func damage(w: int, tn) -> int`（球具 0）、`static func is_parry(w: int, dir: int) -> bool`（球具且非下劈）
  - `twin.gd`（`extends RefCounted`）：欄位 `display_name: String`、`color: Color`、`weapon: int`、`default_weapon: int`、`can_double_jump: bool`、`can_send_tool: bool`；`static func hunahpu()`（斧頭、可二段跳）、`static func xbalanque()`（球具、可派工具）
  - 按鍵動作：`swap`（Tab、手把 Y）、`debug_weapon_1`／`debug_weapon_2`／`debug_weapon_3`（鍵盤 1／2／3）
  - `intent.gd`：`swap_pressed`（讀 `swap` 的 just_pressed，`clear_presses()` 清除）

- [ ] **Step 1: 寫失敗的測試**（加在 `self_test.gd` 新段落 `# ---- MV-PROTO-002 Task 1 ----`，並在檔頭 preload `Twin`、`Weapons`）

```gdscript
func test_p2_tuning_defaults() -> void:
	var t := fresh_tuning()
	check(is_equal_approx(t.swap_cooldown, 0.3), "換人冷卻應為 0.3")
	check(is_equal_approx(t.double_jump_ratio, 0.75), "二段跳比例應為 0.75")
	check(t.stick_side_box == Vector2(210, 60), "掘棒側攻判定應為 210×60")
	check(is_equal_approx(t.parry_window, 0.2) and is_equal_approx(t.parry_recovery, 0.35), "招架窗口 0.2、收招 0.35")
	check(is_equal_approx(t.parry_stagger, 1.2), "招架硬直應為 1.2")
	check(t.tool_chops == 3 and is_equal_approx(t.tool_speed, 900.0), "工具 900 px/s、砍 3 下")
	var table := Tune.table(t)
	for g in ["換人", "二段跳", "掘棒", "球具", "工具", "練習對象"]:
		check(table.contains("| %s |" % g), "數值表缺群組 %s" % g)

func test_p2_weapon_data() -> void:
	var t := fresh_tuning()
	check(Weapons.damage(Weapons.Weapon.AXE, t) == 4 and Weapons.damage(Weapons.Weapon.STICK, t) == 4, "斧頭與掘棒傷害都是 4")
	check(Weapons.damage(Weapons.Weapon.BALLGEAR, t) == 0, "球具傷害 0")
	check(Weapons.box(Weapons.Weapon.STICK, Weapons.Dir.SIDE, t) == Vector2(210, 60), "掘棒側攻 210×60")
	check(Weapons.box(Weapons.Weapon.AXE, Weapons.Dir.SIDE, t) == t.axe_side_box, "斧頭側攻沿用 axe_side_box")
	check(Weapons.timing(Weapons.Weapon.STICK, t).is_equal_approx(Vector3(0.10, 0.08, 0.22)), "掘棒時間 0.10／0.08／0.22")
	check(Weapons.is_parry(Weapons.Weapon.BALLGEAR, Weapons.Dir.SIDE) and Weapons.is_parry(Weapons.Weapon.BALLGEAR, Weapons.Dir.UP), "球具側攻、上攻是招架")
	check(not Weapons.is_parry(Weapons.Weapon.BALLGEAR, Weapons.Dir.DOWN), "球具下劈不是招架")

func test_p2_twin_defaults() -> void:
	var h = Twin.hunahpu()
	var x = Twin.xbalanque()
	check(h.weapon == Weapons.Weapon.AXE and h.can_double_jump and not h.can_send_tool, "Hunahpu：斧頭、二段跳")
	check(x.weapon == Weapons.Weapon.BALLGEAR and x.can_send_tool and not x.can_double_jump, "Xbalanque：球具、派工具")
	check(h.color.is_equal_approx(Color(0.85, 0.55, 0.25)) and x.color.is_equal_approx(Color(0.25, 0.65, 0.7)), "兩人主色")
```

並把 `test_input_scheme_a_registered` 的 `expect` 加上 `"swap": 2, "debug_weapon_1": 1, "debug_weapon_2": 1, "debug_weapon_3": 1`（D8）。

- [ ] **Step 2: 執行測試確認失敗**

Run: 上方 Global Constraints 的測試指令
Expected: `test_p2_*` 三項 FAIL 或 `SCRIPT ERROR`（`twin.gd`、`weapons.gd` 不存在）；`test_input_scheme_a_registered` FAIL（缺 `swap`）

- [ ] **Step 3: 實作**：照 Interfaces 新增數值（各自放在對應的 `@export_group`）、`weapons.gd`、`twin.gd`、按鍵與 `intent.swap_pressed`。

- [ ] **Step 4: 執行測試確認通過**

Run: 測試指令
Expected: `fail=0`、`SCRIPT ERROR` 0

- [ ] **Step 5: Commit**

```bash
git add prototypes/core/tuning/combat_tuning.gd prototypes/core/player/twin.gd prototypes/core/player/weapons.gd prototypes/core/input_setup.gd prototypes/core/player/intent.gd prototypes/core/tests/self_test.gd
git commit -m "Add twin and weapon data, swap input and new tuning values (MV-PROTO-002)"
```

---

### Task 2: 換人

**Files:**
- Modify: `prototypes/core/player/player.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Consumes: Task 1 的 `Twin`、`intent.swap_pressed`、`tn.swap_cooldown`
- Produces（`player.gd`）：
  - `var twins: Array`（`[Twin.hunahpu(), Twin.xbalanque()]`，在 `_ready` 建立）、`var twin_index := 0`、`func twin()`（回傳目前的 Twin）
  - `signal swapped`
  - `func can_swap() -> bool`：`FREE`，或 `ATTACK` 且 `attack_phase == RECOVERY`，或 Task 4 的 `PARRY` 收招中
  - `func swap_twin() -> void`：`twin_index = 1 - twin_index`、`swap_cooldown_left = tn.swap_cooldown`、`swap_buffer_left = 0`、`hitbox.stop()`、`_enter(State.FREE)`、`swap_flash_left = 0.15`、發 `swapped`
  - `var swap_buffer_left`（沿用 `tn.action_buffer`，在 `_update_input_timers` 更新）、`var swap_cooldown_left`
  - 每幀在狀態處理前呼叫 `_try_swap()`：`swap_buffer_left > 0`、`swap_cooldown_left <= 0`、`can_swap()` 都成立才 `swap_twin()`；冷卻中按下直接丟棄（`swap_buffer_left = 0`）
  - `respawn()` 另外：`twin_index = 0`、兩人 `weapon = default_weapon`、`swap_*_left = 0`（D4）
  - `_draw()` 主色改用 `twin().color`；`swap_flash_left > 0` 時整個身體畫白色外框

- [ ] **Step 1: 寫失敗的測試**

```gdscript
func test_swap_in_free_keeps_motion() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(0, 0))
	p.health.hp = 3
	p.velocity = Vector2(400, -500)
	p.facing = -1
	var pos: Vector2 = p.position
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "自由狀態按換人應換成 Xbalanque")
	check(p.health.hp == 3, "共用血量：換人後血量不變")
	check(p.facing == -1, "換人後面向不變")
	check(p.position.distance_to(pos) < 40.0, "換人不應瞬移")
	await free_world(w)

func test_swap_in_air() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.jump_pressed = true
	await frames(10)
	check(not p.is_on_floor(), "前提：在空中")
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "空中也能換人")
	await free_world(w)

func test_swap_blocked_in_startup_active_buffered_to_recovery() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.attack_pressed = true
	await frames(1)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0, "出招中不能換")
	await wait_until(func(): return p.attack_phase == Player.Phase.ACTIVE, 30)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0, "判定中不能換")
	var swapped: bool = await wait_until(func(): return p.twin_index == 1, 12)
	check(swapped, "判定中按下的換人應在收招第一幀執行（0.1 秒緩衝）")
	check(p.state == Player.State.FREE, "換上場的人回到自由狀態")
	await free_world(w)

func test_swap_blocked_in_roll_heal_hurt() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.roll_pressed = true
	await frames(2)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0 and p.state == Player.State.ROLL, "翻滾中不能換")
	await wait_until(func(): return p.state == Player.State.FREE, 40)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "翻滾結束後能換")
	await frames(30)
	p.health.hp = 3
	p.intent.heal_pressed = true
	await frames(2)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1 and p.state == Player.State.HEAL, "治療中不能換")
	await wait_until(func(): return p.state == Player.State.FREE, 90)
	await frames(30)
	p.hurtbox.receive(1, null, &"enemy")
	await frames(1)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.state == Player.State.HURT and p.twin_index == 1, "受擊硬直中不能換")
	await free_world(w)

func test_swap_cooldown() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.swap_pressed = true
	await frames(1)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "冷卻 0.3 秒內再按不換")
	await frames(20)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0, "冷卻過後可再換")
	await free_world(w)

func test_shared_health_across_swap() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.hurtbox.receive(1, null, &"enemy")
	await frames(30)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1 and p.health.hp == 4, "Hunahpu 受的傷換人後仍在")
	await free_world(w)
```

- [ ] **Step 2: 執行測試確認失敗**（Expected：`swap_pressed`／`twin_index` 未使用或不存在 → FAIL 或 SCRIPT ERROR）
- [ ] **Step 3: 實作** `player.gd` 的換人（照 Interfaces）。檔頭註解改成「MV-PROTO-001／002」並標規格出處。
- [ ] **Step 4: 執行測試確認通過**（`fail=0`、`SCRIPT ERROR` 0）
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/player/player.gd prototypes/core/tests/self_test.gd
git commit -m "Add one-button twin swap with recovery-only cancel and cooldown (MV-PROTO-002)"
```

---

### Task 3: 三種武器

**Files:**
- Modify: `prototypes/core/player/player.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Consumes: `Weapons`、`twin().weapon`
- Produces（`player.gd`）：
  - `_start_attack()` 依 `Weapons.box(twin().weapon, attack_dir, tn)` 設判定框；`_state_attack()` 依 `Weapons.timing(...)`；`_process_hits()` 依 `Weapons.damage(...)`
  - `Weapons.is_parry(...)` 成立時改呼叫 Task 4 的 `_start_parry()`（本 Task 先留一個什麼都不做、直接 return 的 `_start_parry()`）
  - 傷害為 0 的命中依 D7：對 `ENEMY_HURT` 不 `receive`、不發 `hit_landed`；下劈仍然彈跳（`velocity.y = -tn.pogo_velocity`）；對 `POGO` 照舊發 `hit_landed`
  - `func set_weapon(w: int) -> void`：設定目前場上的人的武器；若在 `ATTACK`（或 Task 4 的 `PARRY`）就 `hitbox.stop()` 並 `_enter(State.FREE)`

- [ ] **Step 1: 寫失敗的測試**

```gdscript
func make_target(w: Node2D, x: float) -> Array:
	var target := Hurtbox.new()
	target.setup(Vector2(20, 160), Vector2(0, -80), L.ENEMY_HURT)
	target.position = Vector2(x, 0)
	var got := []
	target.hurt.connect(func(amount, _src, kind): got.append([amount, kind]))
	w.add_child(target)
	return got

func test_stick_reaches_farther_than_axe() -> void:
	# 角色前緣在 x=30；斧頭判定到 30+140=170，掘棒到 30+210=240；靶（寬 20）放在 x=205
	var w := make_world()
	var p = await make_player(w)
	var got := make_target(w, 205.0)
	p.intent.attack_pressed = true
	await frames(20)
	check(got.is_empty(), "斧頭側攻不應打到 205 px 外的靶，實際 %s" % [got])
	await frames(10)
	p.set_weapon(Weapons.Weapon.STICK)
	p.intent.attack_pressed = true
	await frames(25)
	check(got.size() == 1 and got[0][0] == 4, "掘棒側攻應打到並扣 4，實際 %s" % [got])
	await free_world(w)

func test_stick_and_ballgear_down_bounce() -> void:
	for wpn in [Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
		var w := make_world()
		var c := PogoCrystal.new()
		c.position = Vector2(0, -600)
		w.add_child(c)
		var p = await make_player(w, Vector2(0, -700))
		p.set_weapon(wpn)
		p.velocity = Vector2.ZERO
		p.intent.down = true
		p.intent.attack_pressed = true
		var bounced: bool = await wait_until(func(): return p.velocity.y < 0.0, 30)
		check(bounced, "%s 的下劈應能彈跳" % Weapons.NAMES[wpn])
		await free_world(w)

func test_ballgear_never_damages() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var got := make_target(w, 80.0)
	p.intent.attack_pressed = true
	await frames(40)
	p.intent.up = true
	p.intent.attack_pressed = true
	await frames(40)
	check(got.is_empty(), "球具側攻、上攻不應造成傷害，實際 %s" % [got])
	await free_world(w)

func test_set_weapon_mid_attack_stops_hitbox() -> void:
	var w := make_world()
	var p = await make_player(w)
	var got := make_target(w, 80.0)
	p.intent.attack_pressed = true
	await frames(2)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	await frames(20)
	check(p.state == Player.State.FREE, "攻擊中換武器應立即結束攻擊")
	check(got.is_empty(), "換武器後不應殘留斧頭傷害，實際 %s" % [got])
	await free_world(w)
```

- [ ] **Step 2: 執行測試確認失敗**（`set_weapon` 不存在 → SCRIPT ERROR）
- [ ] **Step 3: 實作**（照 Interfaces；`axe_*` 數值與斧頭行為保持不變，MV-PROTO-001 的攻擊測試不能改）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/player/player.gd prototypes/core/tests/self_test.gd
git commit -m "Drive attacks from weapon data and add digging stick thrusts (MV-PROTO-002)"
```

---

### Task 4: 球具招架與招架紀錄

**Files:**
- Create: `prototypes/core/combat/parry_stats.gd`
- Modify: `prototypes/core/player/player.gd`、`prototypes/core/enemies/enemy.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Produces:
  - `parry_stats.gd`（`extends RefCounted`）：`enum Result { SUCCESS, WHIFF, UNPARRYABLE }`；`func record(t_sec: float, result: int) -> void`；`func minute_rows() -> Array`（每列 `{"minute": int, "attempts": int, "successes": int}`，minute 從 1 起算＝`floori(t_sec / 60) + 1`，列出 1 到最後一個有紀錄的分鐘，沒有嘗試的分鐘也列 0）；`func report() -> String`（Markdown：表頭 `| 分鐘 | 嘗試 | 成功 | 成功率 |`，成功率四捨五入到整數百分比，嘗試 0 的列寫 `—`；表下一行 `被不可招架打到：N 次`）
  - `enemy.gd`：`var stagger_time := 0.0`（STAGGER 狀態的時限改用它；吹箭打斷時設為 `tn.dart_stagger_time`）；`func parried() -> void`（只在 `ATTACK` 中有效：`stagger_time = tn.parry_stagger`、`_enter(State.STAGGER)`、`flash_left = tn.enemy_flash_time`）
  - `player.gd`：`State.PARRY`；`func _start_parry()`；`var parry_stats`（`_ready` 建立，`respawn` **不**重建）；`signal parried(enemy: Node)`；`func is_parry_window() -> bool`（`PARRY` 且 `state_time < tn.parry_window`）
- 規則（規格第 4 節＋D2）：
  - `_start_parry()`：進 `PARRY`、記一筆「進行中的嘗試」；招架中可左右移動、面向不變（同攻擊）。
  - `_on_hurt` 在招架窗口內：`source` 有 `parryable` 屬性且為 true，且在正面（`signf(source.global_position.x - global_position.x)` 為 0 或等於 `facing`）→ 呼叫 `source.parried()`、不扣血、記 `SUCCESS`、發 `parried`、`_enter(State.FREE)`。`source.parryable == false` → 照常受傷、記 `UNPARRYABLE`。其餘（背後）→ 照常受傷、記 `WHIFF`。
  - 窗口結束時嘗試仍在進行中 → 記 `WHIFF`；收招 `tn.parry_recovery` 結束回 `FREE`；收招可被翻滾、跳躍、換人取消（`can_swap()` 加上 PARRY 收招）。
  - 時間用 `Time.get_ticks_msec() / 1000.0`。
  - 回饋：成功時 `parry_ring_left = 0.3`，`_draw()` 在角色面前畫一個由小變大、漸淡的白色圓環（ART_SPEC 第 5 節「招架成功＝白色圓形光環擴散」）；招架窗口中角色面前畫一個半透明的小圓盾，收招中變淡。

- [ ] **Step 1: 寫失敗的測試**

```gdscript
func test_parry_stats_minute_buckets() -> void:
	var s = ParryStats.new()
	s.record(5.0, ParryStats.Result.SUCCESS)
	s.record(30.0, ParryStats.Result.WHIFF)
	s.record(70.0, ParryStats.Result.SUCCESS)
	s.record(75.0, ParryStats.Result.SUCCESS)
	s.record(80.0, ParryStats.Result.UNPARRYABLE)
	s.record(190.0, ParryStats.Result.SUCCESS)
	var rows: Array = s.minute_rows()
	check(rows.size() == 4, "應列出第 1～4 分鐘，實際 %d 列" % rows.size())
	check(rows[0].attempts == 2 and rows[0].successes == 1, "第 1 分鐘：2 次、成功 1")
	check(rows[1].attempts == 3 and rows[1].successes == 2, "第 2 分鐘：3 次、成功 2")
	check(rows[2].attempts == 0, "第 3 分鐘：0 次")
	var r: String = s.report()
	check(r.contains("| 1 | 2 | 1 | 50% |") and r.contains("| 2 | 3 | 2 | 67% |") and r.contains("| 3 | 0 | 0 | — |"), "報表格式不符：\n%s" % r)
	check(r.contains("被不可招架打到：1 次"), "報表應列出被不可招架打到的次數")

## 角色面向右、在 x=0；爬行型在右邊撲過來
func parry_setup(enemy_scr, enemy_x: float) -> Array:
	var w := make_world()
	var p = await make_player(w)
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var e = await make_enemy(w, enemy_scr, Vector2(enemy_x, 0), p)
	return [w, p, e]

## 在敵人攻擊判定碰到角色前 frames_before 幀按下招架
func parry_when_close(p, e, frames_before := 3) -> void:
	await wait_until(func(): return e.state == Enemy.State.ATTACK, 120)
	await wait_until(func(): return absf(e.global_position.x - p.global_position.x) < 150.0 + frames_before * 18.0, 30)
	p.intent.attack_pressed = true

func test_parry_success_staggers_crawler() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	await parry_when_close(p, e)
	var ok: bool = await wait_until(func(): return e.state == Enemy.State.STAGGER, 30)
	check(ok, "窗口內被爬行型撲擊打到應招架成功、敵人硬直")
	check(p.health.hp == 5, "招架成功不受傷")
	check(p.parry_stats.minute_rows()[0].successes == 1, "紀錄應 +1 成功")
	await frames(60)
	check(e.state == Enemy.State.STAGGER, "招架硬直應長於 1 秒（1.2 秒）")
	await free_world(a[0])

func test_parry_unparryable_hurts() -> void:
	var a: Array = await parry_setup(Flyer, 200.0)
	var p = a[1]
	var e = a[2]
	await wait_until(func(): return e.state == Enemy.State.ATTACK, 200)
	await wait_until(func(): return e.global_position.distance_to(p.global_position + Vector2(0, -90)) < 220.0, 60)
	p.intent.attack_pressed = true
	var hurt: bool = await wait_until(func(): return p.health.hp < 5, 30)
	check(hurt, "窗口內被飛行型（不可招架）打到應受傷")
	check(p.parry_stats.report().contains("被不可招架打到：1 次"), "紀錄應 +1 被不可招架打到")
	await free_world(a[0])

func test_parry_late_is_whiff() -> void:
	var a: Array = await parry_setup(Crawler, 250.0)
	var p = a[1]
	var e = a[2]
	await wait_until(func(): return e.state == Enemy.State.TELEGRAPH, 120)
	await wait_until(func(): return e.state_time >= 0.3, 30)
	p.intent.attack_pressed = true  # 窗口在前搖中就結束，撲擊到達時角色正在收招
	var hurt: bool = await wait_until(func(): return p.health.hp < 5, 90)
	check(hurt, "窗口外（收招中）被打應受傷")
	var rows: Array = p.parry_stats.minute_rows()
	check(rows.size() == 1 and rows[0].attempts == 1 and rows[0].successes == 0, "該次應記為白揮")
	await free_world(a[0])

func test_parry_from_behind_hurts() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	p.facing = -1  # 背對敵人
	await parry_when_close(p, e)
	var hurt: bool = await wait_until(func(): return p.health.hp < 5, 30)
	check(hurt, "背後被打應受傷")
	await free_world(a[0])

func test_parry_same_x_counts_as_front() -> void:
	var w := make_world()
	var p = await make_player(w)
	var e = await make_enemy(w, Crawler, Vector2(0, 0), p)
	e.set_physics_process(false)
	e.state = Enemy.State.ATTACK
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	p.intent.attack_pressed = true
	await frames(1)
	p.hurtbox.receive(1, e, &"enemy")
	check(p.health.hp == 5 and e.state == Enemy.State.STAGGER, "x 相同時應視為正面、招架成功")
	await free_world(w)


func test_parry_success_allows_swap_same_frame() -> void:
	var a: Array = await parry_setup(Crawler, 300.0)
	var p = a[1]
	var e = a[2]
	await parry_when_close(p, e)
	await wait_until(func(): return e.state == Enemy.State.STAGGER, 30)
	check(p.can_swap(), "招架成功的當下應能換人")
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 1, "招架成功後立刻換人")
	await free_world(a[0])
```

（檔頭 preload `ParryStats`。）

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**（照 Interfaces 與規則；吹箭打斷改設 `stagger_time`，`test_dart_interrupts_telegraph_with_cooldown` 必須仍 PASS）
- [ ] **Step 4: 執行測試確認通過**。若 `parry_when_close` 的時機在 headless 下不穩（連續 3 次結果不同），只調整 `frames_before` 與距離門檻，不改斷言，並在 commit 訊息註明。
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/combat/parry_stats.gd prototypes/core/player/player.gd prototypes/core/enemies/enemy.gd prototypes/core/tests/self_test.gd
git commit -m "Add ball gear parry window, enemy parry stagger and per-minute parry stats (MV-PROTO-002)"
```

---

### Task 5: 二段跳

**Files:**
- Modify: `prototypes/core/player/player.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Produces（`player.gd`）：`var air_jump_used := false`、`signal double_jumped`；`_try_jump()` 在一般跳躍不成立時，若 `jump_buffer_left > 0`、`twin().can_double_jump`、`not is_on_floor()`、`not air_jump_used` → `velocity.y = -tn.jump_velocity() * sqrt(tn.double_jump_ratio)`（D1）、`air_jump_used = true`、`jumping = true`、發 `double_jumped`；落地（`_update_input_timers` 中 `is_on_floor()`）與下劈彈起（`_process_hits` 彈跳時）設 `air_jump_used = false`；`respawn()` 也重設。換人不碰 `air_jump_used`。回饋：`double_jump_flash_left = 0.2`，`_draw()` 在腳下畫一圈 6 個小光點並漸淡。

- [ ] **Step 1: 寫失敗的測試**

```gdscript
## 從地面按住跳，在上升頂點附近（第 22 幀）再按一次；回傳最高點離地高度
func double_jump_height(p) -> float:
	var y0: float = p.position.y
	p.intent.jump_pressed = true
	var top := y0
	for i in 90:
		p.intent.jump_held = true
		if i == 22:
			p.intent.jump_pressed = true
		await frames(1)
		top = minf(top, p.position.y)
	return y0 - top


func test_hunahpu_double_jump_height() -> void:
	var w := make_world()
	var p = await make_player(w)
	var h: float = await double_jump_height(p)
	check(h > 620.0 and h < 760.0, "二段跳總高應約 700 px，實際 %.1f" % h)
	await free_world(w)

func test_xbalanque_cannot_double_jump() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.swap_twin()
	await frames(25)
	var h: float = await double_jump_height(p)
	check(h < 440.0, "Xbalanque 不能二段跳（只有約 400 px），實際 %.1f" % h)
	await free_world(w)

func test_swap_does_not_refresh_double_jump() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.intent.jump_pressed = true
	await frames(15)
	p.intent.jump_pressed = true
	await frames(1)
	check(p.air_jump_used, "前提：已用掉二段跳")
	p.intent.swap_pressed = true
	await frames(20)
	p.intent.swap_pressed = true
	await frames(1)
	check(p.twin_index == 0 and p.air_jump_used, "空中換人來回不應刷新二段跳")
	var vy: float = p.velocity.y
	p.intent.jump_pressed = true
	await frames(1)
	check(p.velocity.y >= vy, "已用掉時再按跳不應再往上")
	await free_world(w)

func test_double_jump_restored_by_landing_and_pogo() -> void:
	var w := make_world()
	var c := PogoCrystal.new()
	c.position = Vector2(0, -600)
	w.add_child(c)
	var p = await make_player(w, Vector2(0, -700))
	p.air_jump_used = true
	p.velocity = Vector2.ZERO
	p.intent.down = true
	p.intent.attack_pressed = true
	await wait_until(func(): return p.velocity.y < 0.0, 30)
	check(not p.air_jump_used, "下劈彈起應恢復二段跳")
	p.air_jump_used = true
	await wait_until(func(): return p.is_on_floor(), 180)
	await frames(1)
	check(not p.air_jump_used, "落地應恢復二段跳")
	await free_world(w)

func test_respawn_restores_double_jump() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.air_jump_used = true
	p.respawn(Vector2.ZERO)
	check(not p.air_jump_used and p.twin_index == 0, "重生後二段跳恢復、回到 Hunahpu")
	await free_world(w)
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**
- [ ] **Step 4: 執行測試確認通過**（`double_jump_height` 的按鍵幀數若讓高度落在範圍外，只調整按下的幀，不改範圍）
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/player/player.gd prototypes/core/tests/self_test.gd
git commit -m "Add Hunahpu double jump restored only by landing or pogo (MV-PROTO-002)"
```

---

### Task 6: 木障與「讓工具自己動」

**Files:**
- Create: `prototypes/core/level/barrier.gd`、`prototypes/core/player/tool_spirit.gd`
- Modify: `prototypes/core/combat/layers.gd`、`prototypes/core/player/dart.gd`、`prototypes/core/player/blowgun.gd`、`prototypes/core/player/player.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Produces:
  - `layers.gd`：`const BARRIER := 64`
  - `dart.gd`：`var shooter: Node`、`var marks_barrier := false`；射線遮罩加 `L.BARRIER`
  - `blowgun.gd`：`try_fire` 設 `d.shooter = player`、`d.marks_barrier = player.twin().can_send_tool`（D6）
  - `player.gd`：近戰判定遮罩加 `L.BARRIER`（側攻、上攻、下劈都加）；`var tool: Node`；`signal tool_sent(tool: Node)`；`func send_tool(barrier: Node) -> bool`（`is_instance_valid(tool)` 時回傳 false；否則建立 `ToolSpirit`、加到 `get_parent()`、記在 `tool`、發 `tool_sent`、回傳 true）；`respawn()` 時若 `tool` 有效就 `queue_free()`（D4）
  - `barrier.gd`（`extends StaticBody2D`）：`func setup(rect: Rect2) -> void`（加入場景前呼叫；實體碰撞層 `L.WORLD`，另加一個 `Hurtbox`，大小每邊多 4 px、層 `L.BARRIER`，D5）；`signal thudded`、`signal broken`；`var is_broken := false`；受擊處理：`kind == &"dart"` 且 `source.marks_barrier` → `source.shooter.send_tool(self)`；其餘一律發 `thudded`；`func break_apart() -> void`（`is_broken = true`、實體與受擊框停用（`set_deferred("disabled", true)`）、隱藏、發 `broken`）；`func restore() -> void`（反向）；`_draw()`：木色長方形加幾道斜紋
  - `tool_spirit.gd`（`extends Node2D`）：`var tn`、`var player: Node`、`var barrier: Node`；狀態 OUT → CHOP → BACK；從 `player.global_position + Vector2(0, -90)` 出發，以 `tn.tool_speed` 飛向木障中心；距離 < 12 px 進 CHOP，`tn.tool_chop_time` 內平均發 `tn.tool_chops` 次 `signal chopped`；CHOP 結束呼叫 `barrier.break_apart()`；BACK 飛向 `player.global_position + Vector2(0, -90)`，距離 < 24 px 時 `queue_free()`；`player` 若失效直接 `queue_free()`；`_draw()`：一個小斧頭形的方塊

- [ ] **Step 1: 寫失敗的測試**

```gdscript
## 木障：x=300 處、從 y=-400 到地面
func make_barrier(w: Node2D) -> Node:
	var b = Barrier.new()
	b.setup(Rect2(300, -400, 60, 400))
	w.add_child(b)
	return b

func test_xbalanque_dart_breaks_barrier() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "Xbalanque 的飛鏢射中木障後，工具應在 2 秒內把它砍碎")
	await wait_until(func(): return not is_instance_valid(p.tool), 120)
	check(not is_instance_valid(p.tool), "工具砍完應飛回並消失")
	await free_world(w)

func test_hunahpu_dart_and_melee_do_not_break_barrier() -> void:
	var w := make_world()
	var b = make_barrier(w)
	var p = await make_player(w, Vector2(200, 0))
	var thuds := []
	b.thudded.connect(func(): thuds.append(1))
	p.intent.dart_pressed = true
	await frames(20)
	for wpn in [Weapons.Weapon.AXE, Weapons.Weapon.STICK]:
		p.set_weapon(wpn)
		p.intent.attack_pressed = true
		await frames(30)
	p.swap_twin()
	await frames(25)
	p.set_weapon(Weapons.Weapon.AXE)
	p.intent.attack_pressed = true
	await frames(60)
	check(not b.is_broken, "Hunahpu 的飛鏢與任何人的近戰都不應打壞木障")
	check(thuds.size() >= 3, "打在木障上應發出悶響（thudded），實際 %d 次" % thuds.size())
	await free_world(w)

func test_only_one_tool_at_a_time() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	check(p.send_tool(b), "第一次派工具應成功")
	check(not p.send_tool(b), "工具在外時再派應失敗")
	await free_world(w)

func test_swap_while_tool_out_still_breaks() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.send_tool(b)
	await frames(2)
	p.swap_twin()
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "工具在外時換人，木障照樣被砍碎")
	await free_world(w)

func test_dart_mark_decided_at_fire() -> void:
	var w := make_world()
	var p = await make_player(w)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	await frames(1)
	p.swap_cooldown_left = 0.0
	p.swap_twin()  # 飛鏢還在飛時換回 Hunahpu
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "Xbalanque 射出的飛鏢在飛行中換人，仍應標記木障")
	await free_world(w)

func test_barrier_restore() -> void:
	var w := make_world()
	var b = make_barrier(w)
	await frames(2)
	b.break_apart()
	await frames(2)
	b.restore()
	await frames(2)
	check(not b.is_broken, "restore 後木障復原")
	var p = await make_player(w, Vector2(150, 0))
	p.intent.move_x = 1.0
	await frames(40)
	check(p.position.x < 300.0, "復原的木障應擋住角色")
	await free_world(w)
```

（檔頭 preload `Barrier`。）

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**（照 Interfaces；`test_fast_dart_*` 兩項舊測試必須仍 PASS）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/level/barrier.gd prototypes/core/player/tool_spirit.gd prototypes/core/combat/layers.gd prototypes/core/player/dart.gd prototypes/core/player/blowgun.gd prototypes/core/player/player.gd prototypes/core/tests/self_test.gd
git commit -m "Add wooden barriers broken by Xbalanque's dart-marked flying tool (MV-PROTO-002)"
```

---

### Task 7: 招架練習對象

**Files:**
- Create: `prototypes/core/enemies/parry_dummy.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Consumes: `enemy.gd`（含 Task 4 的 `parried()`、`stagger_time`）
- Produces: `parry_dummy.gd`（`extends "res://enemies/enemy.gd"`）：`size = Vector2(110, 70)`、`parryable = true`；`var cycle_left`（初值 `tn.dummy_interval`，每幀遞減）；`_idle`：`cycle_left <= 0` 時 `start_telegraph()` 並重設為 `tn.dummy_interval`；前搖與攻擊時間用 `tn.crawler_telegraph`、`tn.crawler_lunge_time`，收招 `tn.crawler_recover`；不移動；`start_telegraph()` 時把攻擊判定設為面向側 200 px 寬的方框（`configure(Vector2(200, size.y * 1.1), Vector2(facing * (size.x / 2.0 + 100.0), -size.y / 2.0), L.PLAYER_HURT)`，D3）；`_on_hurt` 覆寫成只閃白、不扣血、不死；傷害 `tn.crawler_damage`

- [ ] **Step 1: 寫失敗的測試**

```gdscript
func test_dummy_attacks_periodically_and_never_dies() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(150, 0))
	var d = await make_enemy(w, ParryDummy, Vector2(0, 0), p)
	var telegraphs := 0
	var last = d.state
	for i in 300:
		await frames(1)
		if d.state == Enemy.State.TELEGRAPH and last != Enemy.State.TELEGRAPH:
			telegraphs += 1
		last = d.state
	check(telegraphs >= 2, "5 秒內應至少出招 2 次（每 2 秒），實際 %d" % telegraphs)
	check(d.parryable, "練習對象的攻擊應可招架（白色圓形）")
	check(absf(d.position.x) < 1.0, "練習對象不應移動")
	d.hurtbox.receive(100, null, &"melee")
	await frames(1)
	check(is_instance_valid(d) and d.state != Enemy.State.DEAD, "練習對象不會死")
	check(p.health.hp < 5, "站在面前 150 px 內應會被打到")
	await free_world(w)

func test_dummy_can_be_parried() -> void:
	var w := make_world()
	var p = await make_player(w, Vector2(150, 0))
	p.facing = -1
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	var d = await make_enemy(w, ParryDummy, Vector2(0, 0), p)
	await wait_until(func(): return d.state == Enemy.State.TELEGRAPH, 200)
	await wait_until(func(): return d.state_time >= d.tn.crawler_telegraph - 0.1, 60)
	p.intent.attack_pressed = true
	var ok: bool = await wait_until(func(): return d.state == Enemy.State.STAGGER, 30)
	check(ok and p.health.hp == 5, "練習對象的攻擊應能被招架、不受傷")
	await free_world(w)
```

（檔頭 preload `ParryDummy`。）

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/enemies/parry_dummy.gd prototypes/core/tests/self_test.gd
git commit -m "Add stationary parry practice dummy on a fixed cycle (MV-PROTO-002)"
```

---

### Task 8: 探索區與房間整合

**Files:**
- Modify: `prototypes/core/level/test_room.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Consumes: `Barrier`、`ParryDummy`、`player` 的 `swapped`／`parried`／`double_jumped`／`tool_sent` 訊號
- Produces（`test_room.gd` 常數；GROUND_Y = 900，數值依規格第 7 節與 MV-PROTO-001 初始數值計算）：
  - `RIGHT_EDGE := 10000.0`（原 5200）
  - `LEDGE1 := Rect2(5600, GROUND_Y - 550, 800, 950)`（① 高台）
  - `PIT2_LEFT := 7000.0`、`PIT2_WIDTH := 600.0`、`PIT2_RESPAWN := Vector2(PIT2_LEFT - 150.0, GROUND_Y)`
  - `LEDGE3 := Rect2(8000, GROUND_Y - 550, 800, 950)`（③ 台階）
  - `CEILING := Rect2(6800, GROUND_Y - 1050, 2200, 100)`（②③ 的天花板，下緣在地面上方 950 px）
  - `BARRIERS := [Rect2(7270, GROUND_Y - 950, 60, 950), Rect2(8160, GROUND_Y - 950, 60, 400)]`（② 坑中央；③ 台階頂端往內 160 px，留給 Hunahpu 落腳）
  - `DUMMY := Vector2(-80, GROUND_Y)`（D3）
  - `CRAWLERS` 加 `Vector2(9400, GROUND_Y)`；`FLYERS` 加 `Vector2(9600, GROUND_Y - 450)`
  - 地面：原「對岸」那塊改成到 `PIT2_LEFT` 為止，另加 `PIT2_LEFT + PIT2_WIDTH` 到 `RIGHT_EDGE` 的一塊；右牆移到 `RIGHT_EDGE`；`LEDGE1`、`LEDGE3`、`CEILING` 加進實體
  - `_add_pit(rect: Rect2, respawn: Vector2)` 一般化：第二個坑掉下去回 `PIT2_RESPAWN`
  - `var barriers: Array`、`var dummy`；`reset_room()` 另外：每個木障 `restore()`、練習對象重建、`player.respawn` 已處理工具與武器
  - 音效接線：`swapped`→`&"swap"`、`parried`→`&"parry"`、`double_jumped`→`&"double_jump"`、`tool_sent`→`&"tool_out"`（並把該工具的 `chopped` 接到 `&"chop"`）、木障 `broken`→`&"barrier_break"`、`thudded`→`&"thud"`
  - 鏡頭 `limit_right = int(RIGHT_EDGE)`

- [ ] **Step 1: 寫失敗的測試**（並依 D8 改三項舊測試的預期值：`test_room_layout` 改為 `crawlers == 3 and flyers == 2`；`test_room_reset_restores_everything` 改為 `r.enemies.size() == 5`；`test_room_enemy_falling_into_pit_dies` 改為 `r.enemies.size() == 4`）

```gdscript
## 探索區機器人：在 start 放下角色（指定兄弟），依 steps 逐幀輸入；回傳角色
## steps 每項：{"frames": int, "move_x": float, "jump": bool, "hold": bool, "swap": bool, "dart": bool, "aim": Vector2}
func explore_bot(r, start: Vector2, twin: int, steps: Array) -> Node:
	var p = r.player
	p.scripted = true
	for e in r.enemies:
		e.set_physics_process(false)
	p.position = start
	p.velocity = Vector2.ZERO
	if p.twin_index != twin:
		p.swap_twin()
	p.swap_cooldown_left = 0.0
	p.facing = 1
	await frames(3)
	for s in steps:
		for i in s.get("frames", 1):
			p.intent.move_x = s.get("move_x", 0.0)
			p.intent.jump_held = s.get("hold", false)
			if i == 0:
				p.intent.jump_pressed = s.get("jump", false)
				p.intent.swap_pressed = s.get("swap", false)
				p.intent.dart_pressed = s.get("dart", false)
				p.intent.aim = s.get("aim", Vector2.ZERO)
			await frames(1)
	return p

func test_explore_ledge1_needs_double_jump() -> void:
	var r = await make_room()
	var climb := [
		{"frames": 20, "move_x": 1.0},
		{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 40, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 30, "move_x": 1.0},
	]
	var p = await explore_bot(r, Vector2(5450, Room.GROUND_Y), 0, climb)
	check(p.position.x > 5650 and p.position.y < Room.GROUND_Y - 500, "Hunahpu 應能二段跳上 ① 高台，實際 %s" % p.position)
	p = await explore_bot(r, Vector2(5450, Room.GROUND_Y), 1, climb)
	check(p.position.x < 5600, "Xbalanque 單跳上不了 ① 高台，實際 %s" % p.position)
	await free_world(r)

func test_explore_pit2_needs_xbalanque() -> void:
	var r = await make_room()
	var b2 = r.barriers[0]
	var p = await explore_bot(r, Vector2(6950, Room.GROUND_Y), 0, [{"frames": 40, "dart": true}])
	check(not b2.is_broken, "Hunahpu 的飛鏢不能破 ② 的木障")
	p = await explore_bot(r, Vector2(6950, Room.GROUND_Y), 1, [{"frames": 150, "dart": true}])
	check(b2.is_broken, "Xbalanque 在坑緣朝面向射，應破 ② 的木障")
	p = await explore_bot(r, Vector2(6950, Room.GROUND_Y), 0, [
		{"frames": 4, "move_x": 1.0},
		{"frames": 45, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 40, "move_x": 1.0},
	])
	check(p.position.x > Room.PIT2_LEFT + Room.PIT2_WIDTH and p.health.hp == 5, "破障後應能跳過 ② 的坑，實際 %s、血量 %d" % [p.position, p.health.hp])
	await free_world(r)

func test_explore_ledge3_needs_both() -> void:
	var r = await make_room()
	var b3 = r.barriers[1]
	# Hunahpu 先二段跳上台階頂端的落腳處，換 Xbalanque 近距離射破木障，再往右走
	var p = await explore_bot(r, Vector2(7850, Room.GROUND_Y), 0, [
		{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
		{"frames": 40, "move_x": 0.6, "jump": true, "hold": true},
		{"frames": 30},
	])
	check(p.position.y < Room.GROUND_Y - 500 and p.position.x < 8160, "Hunahpu 應落在 ③ 木障前的落腳處，實際 %s" % p.position)
	p = await explore_bot(r, p.position, 1, [{"frames": 150, "dart": true}])
	check(b3.is_broken, "換 Xbalanque 後應能破 ③ 的木障")
	p = await explore_bot(r, p.position, 1, [{"frames": 120, "move_x": 1.0}])
	check(p.position.x > 8800, "破障後應能走到小戰鬥房，實際 %s" % p.position)
	await free_world(r)

func test_room_pit2_respawns_at_edge() -> void:
	var r = await make_room()
	var p = r.player
	p.position = Vector2(Room.PIT2_LEFT + 150.0, Room.GROUND_Y - 300.0)
	p.velocity = Vector2.ZERO
	var fell: bool = await wait_until(func(): return p.health.hp == 4, 120)
	check(fell, "掉進 ② 的坑應扣 1 血")
	await frames(2)
	check(p.position.distance_to(Room.PIT2_RESPAWN) < 50.0, "應回到 ② 的坑緣，實際 %s" % p.position)
	await free_world(r)

func test_room_reset_recalls_tool() -> void:
	var r = await make_room()
	var p = r.player
	p.scripted = true
	var b2 = r.barriers[0]
	p.position = Vector2(6950, Room.GROUND_Y)
	p.swap_twin()
	await frames(3)
	p.send_tool(b2)
	await frames(2)
	r.reset_room()
	await frames(3)
	check(not is_instance_valid(p.tool), "重置房間應收回在外的工具")
	check(not b2.is_broken, "重置後木障完好")
	check(p.twin_index == 0, "重置後回到 Hunahpu")
	p.position = Vector2(6950, Room.GROUND_Y)
	p.swap_twin()
	await frames(3)
	check(p.send_tool(b2), "重置後應能再派工具")
	await free_world(r)

func test_room_has_dummy_and_barriers() -> void:
	var r = await make_room()
	check(r.barriers.size() == 2, "應有 2 道木障")
	check(r.dummy != null and r.dummy.position.distance_to(Room.DUMMY) < 5.0, "練習對象應在起點左側")
	await free_world(r)
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**（照 Interfaces；`_draw()` 畫出新地形、②的坑、天花板）
- [ ] **Step 4: 執行測試確認通過**。機器人測試若因起跳幀數不穩而失敗：先用 `--demo-explore`（Task 9）錄影確認地形本身能過，再只調整 `steps` 的幀數與 `move_x`；**不改地形尺寸與斷言**。地形若真的過不去（例如二段跳搆不到 550 px），停下來，把量到的數字記進 ledger 再決定。
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/level/test_room.gd prototypes/core/tests/self_test.gd
git commit -m "Extend test room with swap-gated exploration, second pit, barriers and parry dummy (MV-PROTO-002)"
```

---

### Task 9: HUD、佔位音效、F9 招架報表、展示模式

**Files:**
- Modify: `prototypes/core/ui/hud.gd`、`prototypes/core/fx/sfx.gd`、`prototypes/core/main.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Produces:
  - `sfx.gd`：`LENGTHS` 加 `&"swap"`、`&"parry"`、`&"double_jump"`、`&"tool_out"`、`&"chop"`、`&"barrier_break"`、`&"thud"`，各自在 `sample()` 合成（`thud`：低頻、指數快速衰減、無回聲；其餘避開語彙特徵：不用持續低平嗡聲、不用單發乾短空洞敲擊加回聲）
  - `hud.gd`：血量、治療下方兩行文字，場上的人亮色 `Color(1, 1, 1, 0.95)`、另一位 `Color(1, 1, 1, 0.4)`，格式 `"%s　%s" % [twin.display_name, Weapons.NAMES[twin.weapon]]`；底部提示加「1／2／3 換武器　Tab 換人」；`func twin_lines() -> PackedStringArray`（給測試讀）
  - `main.gd`：`debug_weapon_1..3` → `room.player.set_weapon(...)`；`debug_save` 另外 `print(room.player.parry_stats.report())`；新增 `--demo-explore`（角色放在 `Vector2(7850, Room.GROUND_Y)`，scripted）、`--demo-parry`（角色放在 `Vector2(70, Room.GROUND_Y)`、面向左、scripted、拿球具）

- [ ] **Step 1: 寫失敗的測試**

```gdscript
func test_p2_sfx_complete() -> void:
	var bank := Sfx.build_all()
	for s in [&"swap", &"parry", &"double_jump", &"tool_out", &"chop", &"barrier_break", &"thud"]:
		check(bank.has(s) and bank[s].data.size() > 0, "缺少或空白的佔位音效 %s" % s)

func test_hud_twin_lines() -> void:
	var w := make_world()
	var p = await make_player(w)
	var hud = Hud.new()
	hud.player = p
	w.add_child(hud)
	var lines: PackedStringArray = hud.twin_lines()
	check(lines.size() == 2 and lines[0].contains("Hunahpu") and lines[0].contains("斧頭") and lines[1].contains("Xbalanque") and lines[1].contains("球具"), "HUD 兩行應顯示兩兄弟與武器，實際 %s" % [lines])
	p.set_weapon(Weapons.Weapon.STICK)
	check(hud.twin_lines()[0].contains("掘棒"), "改武器後 HUD 應更新")
	await free_world(w)
```

（檔頭 preload `Hud`。）

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**
- [ ] **Step 4: 執行測試確認通過**；再錄三段影片確認畫面：
  ```bash
  for m in demo demo-explore demo-parry; do rm -rf /tmp/p2_$m; mkdir -p /tmp/p2_$m; godot --path prototypes/core --write-movie /tmp/p2_$m/frame.png --fixed-fps 30 --quit-after 120 -- --$m > /tmp/p2_$m.log 2>&1; grep -c "SCRIPT ERROR" /tmp/p2_$m.log; done
  ```
  Expected：每段 `SCRIPT ERROR` 0；用 Read 看各段第 60、119 幀：`--demo-explore` 看得到台階、木障（斜紋）、天花板；`--demo-parry` 看得到練習對象的白色圓形前搖；HUD 兩行文字正確。
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/ui/hud.gd prototypes/core/fx/sfx.gd prototypes/core/main.gd prototypes/core/tests/self_test.gd
git commit -m "Add twin HUD, placeholder sounds, parry report on F9 and demo modes (MV-PROTO-002)"
```

---

### Task 10: README、派工單、執行報告

**Files:**
- Modify: `prototypes/core/README.md`、`todo/todo.md`、`todo/spec/MV-PROTO-002_換人與武器.md`（「Git Commit」節）
- Create: `report/MV-PROTO-002_換人與武器_{YYYY-MM-DD_HHmm}_執行報告.md`

**Interfaces:** 無程式介面。

- [ ] **Step 1: 改寫 README**：標題改為「核心專案｜MV-PROTO-002 換人與武器」；「要回答的問題」換成本規格三題；操作表加換人、1／2／3；房間說明加練習對象（左牆邊）、探索區 ①②③、小戰鬥房（不寫通過方法）；「調數值」沿用；自評步驟換成規格的 5 項（含招架參考線、找 1 人的做法）；試玩紀錄表；自動驗證指令改 `--quit-after 18000`；展示模式加 `--demo-explore`、`--demo-parry`；MV-PROTO-001 的問題、自評步驟移到「上一個原型：MV-PROTO-001」一節保留。
- [ ] **Step 2: 執行完整測試**（測試指令；Expected：`fail=0`、`SCRIPT ERROR` 0；PASS 總數＝55＋本計畫新增數）
- [ ] **Step 3: 更新派工單與規格**：`todo/todo.md` 的 MV-PROTO-002 改 `⏸️ 暫停`、暫停原因「等待人工決策（Brian 自評）」，說明欄加規格、計畫、報告連結與測試數；規格書「Git Commit」節列出本分支的 commit。
- [ ] **Step 4: 寫執行報告**（`type: task-report`，含：做了什麼、測試結果、ledger 中的 Ruling、Brian 的自評步驟）
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/README.md todo/todo.md todo/spec/MV-PROTO-002_換人與武器.md report/
git commit -m "Document swap and weapons prototype and hand off for self-review (MV-PROTO-002)"
```
