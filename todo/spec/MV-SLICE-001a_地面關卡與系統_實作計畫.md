# MV-SLICE-001a 地面關卡與系統 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新開正式專案 `game/`，用灰盒把垂直切片 30 分鐘的流程串通：祖母家 → 田地（工具、入夜抓老鼠）→ 球具 → 森林 → Seven Macaw → 出口，含可可豆、祖母兌換、裝備頁、老鼠的鑽地突襲、按鍵提示、篝火存檔。

**Architecture:** 從 `prototypes/core/` 複製戰鬥、角色、敵人、Boss 程式到 `game/core/`；新增唯一的狀態來源 `GameState`（autoload）、資料驅動的房間系統（`world/rooms/*.gd` 資料＋通用 `room.gd` 建構＋`room_flow.gd` 換房）、事件與 UI。Boss 段落（規格第 8～13 房）做成一個特殊房間 `boss`，內部沿用原型的 `boss_fight.gd` 整條流程，只接上 GameState。

**Tech Stack:** Godot 4.7.2、GDScript（不用 `class_name`，沿用 core 的 `preload` 常數）、自測框架沿用 core 的 `--self-test`。

**Spec:** [todo/spec/MV-SLICE-001a_地面關卡與系統.md](MV-SLICE-001a_地面關卡與系統.md)（上層：[MV-SLICE-001_垂直切片.md](MV-SLICE-001_垂直切片.md)）

## 與規格書的差異（實作做法）

- **規格第 8～13 房（nance 樹前 → 出口）做成一個特殊房間 `boss`**，內部沿用原型 `boss_fight.gd` 的整條流程（樹下篝火、nance 樹、小路、宮殿篝火、宮殿、出口高台）。原型的 Boss 戰是一個連續的 world，拆成 6 個房間等於重寫 Boss 戰，也就做不到「Boss 戰數值與原型一致」。玩家感受到的流程與規格相同：兩個篝火都能休息存檔、nance 樹開打前能往回走到森林。房間資料因此是 9 個（`home`、`yard`、`field`、`forest_1`～`forest_4`、`boss`、`exit`）。
- 原型 Boss 戰的「Esc／Start 在 2 秒內按兩次回選單」改成正式的暫停選單（Task 11）。

## Global Constraints

- 引擎 Godot 4.7.2；專案設定沿用 core：視窗 1920×1080、`window_width_override=1280`、`stretch/mode="canvas_items"`、`aspect="keep"`。
- `prototypes/core/` 一律不改（SLICE-a14）。
- 程式註解與 UI 文字用繁體中文；commit 訊息用英文，句首大寫、結尾帶 `(MV-SLICE-001a)`，同既有風格。
- 數值一律放 `core/tuning/combat_tuning.gd`，照原型結案值；新增群組「經濟」「動物技能」。
- 除錯鍵（F9～F11、數字鍵 1～3）與開發版參數只在 `OS.is_debug_build()` 時有效。
- 自測輸出格式照 core：每項 `SELFTEST PASS|FAIL <名稱>`，最後 `SELFTEST SUMMARY pass=N fail=M`；測試不動 `Tune.data`、不寫 `.tres`、不寫 `user://slot1.json`（用 `user://test_*.json`）。
- 驗證指令：`godot --headless --path game -- --self-test 2>&1 | grep -E "SELFTEST (FAIL|SUMMARY)|SCRIPT ERROR|Parse Error"`，通過＝`fail=0` 且沒有 `SCRIPT ERROR`／`Parse Error`。
- 文字卡是旁白，角色不直接說話（J4）。

## Review Focus

1. **壞掉或舊版的存檔**：`slot1.json` 內容損壞、缺欄位或版本不符時，「繼續」不可當機，要當成沒有存檔（Task 2 加測）。
2. **事件或文字卡進行中死亡、或同一幀碰到兩扇門**：只能換一次房、不能重複觸發事件（Task 4、Task 10 加測）。
3. **鑽地突襲途中目標死掉、或途中換房**：老鼠要安全消失、資源只扣一次（Task 8 加測）。
4. **還沒拿到任何武器、或只有一把時打開裝備頁**：不能把同一把給兩人，沒有武器的人顯示「—」且攻擊無效（Task 7 加測）。
5. **治療鍵在次數與熱湯都用完、或滿血時按下**：熱湯不可被扣掉（Task 3 加測）。

---

### Task 1: 專案骨架、搬遷與自測拆檔

**Files:**
- Create: `game/project.godot`、`game/main.tscn`、`game/main.gd`、`game/input_setup.gd`、`game/launch_args.gd`、`game/.gitignore`
- Copy（`cp -R`，再改 `res://` 路徑）：`prototypes/core/{combat,player,enemies,boss,fx,tuning}` → `game/core/`；`prototypes/core/ui/{hud,text_card,whiteout}.gd` → `game/ui/`
- 不複製：`level/`、`enemies/parry_dummy.gd`、`ui/start_menu.gd`
- Create: `game/tests/runner.gd`、`game/tests/base_test.gd`、`game/tests/test_combat.gd`、`test_player.gd`、`test_enemies.gd`、`test_boss.gd`、`test_ui.gd`

**Interfaces:**
- Produces: `base_test.gd`（extends Node）提供 `check(cond: bool, msg: String)`、`frames(n: int)`、`wait_until(cond: Callable, max_frames := 120) -> bool`、`fresh_tuning() -> Tuning`、`make_world() -> Node2D`、`make_player(w: Node2D, at := Vector2.ZERO) -> Node`、`free_world(w: Node)`——內容照 core `self_test.gd` 第 51～250 行的同名函式。
- Produces: `runner.gd` 依序載入 `tests/test_*.gd`，對每個檔案的 `test_*` 方法依名稱排序執行，印出 core 同格式的結果，最後回傳 `fail_count`。
- Produces: InputMap 新增 `skill_1`（十字鍵左／Q）、`skill_2`（十字鍵右／F）、`interact`（十字鍵下／E）、`pause`（Start／Esc）；core 的 `menu_back` 改名 `pause`。

- [ ] **Step 1: 複製 core 的程式並建 `project.godot`**（autoload：`Tune="*res://core/tuning/tune.gd"`、`InputSetup="*res://input_setup.gd"`；`config/name="Popol Vuh MV｜垂直切片"`），把所有 `res://combat/...` 等路徑改成 `res://core/combat/...`。
- [ ] **Step 2: 把 core 的 `self_test.gd` 依段落拆到 5 個測試檔**：保留 Task 1～8、10、最終審查、延後的小問題、MV-PROTO-002 Task 1～6、9、最終審查、MV-PROTO-003 全部；**刪除**用到練習房、探索區、練習對象、`--demo*`、`--tester` 的項目（`test_room_*`、`test_explore_*`、`test_dummy_*`、`test_room_has_dummy_and_barriers`、`test_start_menu_items_and_toggle`、`test_parry_whiff_recorded_when_left_by_swap_or_weapon_key` 中依賴練習房的部分改用 `make_world()`）。每個被刪的測試在 `tests/README.md` 列一行「刪除原因」。
- [ ] **Step 3: 改 `test_input_scheme_a_registered`** 的期望表：`menu_back` 換成 `"pause": 2`，新增 `"skill_1": 2, "skill_2": 2, "interact": 2`。
- [ ] **Step 4: `main.gd` 的 `--self-test` 改跑 `runner.gd`**；`launch_args.gd` 只保留 `--self-test`、`--boss`、`--boss-phase`，並新增 `--room <id>`（開發版才生效，Task 12 使用）。
- [ ] **Step 5: 執行驗證指令**，Expected：`fail=0`、無 `SCRIPT ERROR`；記下搬過來的測試數（core 171 項減去刪除的項目）。
- [ ] **Step 6: Commit** `Start the slice project from the core prototype (MV-SLICE-001a)`

---

### Task 2: GameState 與存檔

**Files:**
- Create: `game/state/game_state.gd`（autoload `GameState`）、`game/state/save.gd`
- Modify: `game/core/tuning/combat_tuning.gd`（新增群組「經濟」）
- Test: `game/tests/test_state.gd`

**Interfaces:**
- Produces（`game_state.gd`，extends Node）：
  - 欄位：`cacao: int`、`weapons_owned: Array`（Weapons.Weapon 值）、`equip: Array`（長 2，-1＝沒有）、`skills_owned: Array`（String，例 `"rat"`）、`skill_slots: Array`（長 2，`""`＝空）、`slot2_unlocked := false`、`soup: int`、`skill_res: int`、`skill_hits: int`、`hints_seen: Dictionary`、`flags: Dictionary`、`stashes_taken: Dictionary`、`last_rest: String`、`hp: int`、`heal_charges: int`、`awakened := false`；只在執行中的 `defeated: Dictionary`（room_id → Array 敵人索引，不存檔）。
  - `reset_new_game() -> void`：`cacao=0`、沒有武器、`equip=[-1,-1]`、沒有技能、`soup=0`、`skill_res=tn.skill_max`、`hp=tn.max_hp`、`heal_charges=tn.heal_charges`、`last_rest="home"`。
  - `add_cacao(n: int)`、`can_buy_soup() -> bool`、`buy_soup() -> bool`、`take_soup() -> bool`
  - `give_weapon(w: int)`：加入持有；若某人 `equip` 是 -1 就裝上（先 Hunahpu 0 再 Xbalanque 1）。
  - `equip_weapon(twin: int, w: int) -> void`：`w` 是對方正在用的就兩人互換（SLICE-a5）。
  - `give_skill(id: String)`：加入持有、放進第一個空的已解鎖槽。
  - `use_skill(cost: int) -> bool`、`on_weapon_hit() -> void`（每 `tn.skill_hits_per_charge` 次回 1 格，上限 `tn.skill_max`）
  - `set_flag(name: String)`、`has_flag(name: String) -> bool`
  - `rest(at: String) -> void`：`hp`、`heal_charges`、`skill_res` 回滿，`defeated` 清空，`last_rest=at`
  - `to_dict() -> Dictionary`、`from_dict(d: Dictionary) -> bool`（缺欄位或型別不對回傳 false 且不改狀態）
  - `var tn: Tuning = Tune.data`（測試可換成 fresh_tuning）
- Produces（`save.gd`，extends RefCounted，靜態）：`const VERSION := 1`、`const PATH := "user://slot1.json"`、`static func write(d: Dictionary, path := PATH) -> Error`（寫入 `{"version": VERSION, "state": d}`）、`static func read(path := PATH) -> Dictionary`（檔案不存在、不是 JSON、版本不符、缺 `state` 時回傳 `{}`）、`static func exists(path := PATH) -> bool`（＝`read(path)` 非空）
- 數值（群組「經濟」）：`cacao_drop_min := 1`、`cacao_drop_max := 3`、`stash_cacao := 10`、`soup_price := 15`、`soup_max := 2`、`skill_max := 3`、`skill_cost := 1`、`skill_hits_per_charge := 4`

- [ ] **Step 1: Write the failing tests**（`test_state.gd`）：
  - `test_new_game_defaults`：`cacao==0`、`equip==[-1,-1]`、`soup==0`、`skill_res==3`、`last_rest=="home"`
  - `test_soup_price_and_cap`：14 顆不能買；15 顆買到 1 碗、剩 0；買滿 2 碗後 `can_buy_soup()==false` 即使有 100 顆
  - `test_give_weapon_auto_equips_in_order`：給斧頭 → `equip==[AXE,-1]`；再給掘棒 → `[AXE,STICK]`；再給球具 → 不變
  - `test_equip_swaps_when_taken`：`[AXE,STICK]` 時 `equip_weapon(0, STICK)` → `[STICK,AXE]`；`equip_weapon(0, BALLGEAR)` 但沒持有球具 → 不變
  - `test_skill_use_and_recharge`：`use_skill(1)` 三次成功、第四次 false；`on_weapon_hit()` 4 次回 1 格；滿 3 格後再打不超過 3
  - `test_rest_refills_and_clears_defeated`
  - `test_save_roundtrip`：寫到 `user://test_slot.json` 再讀回，`from_dict` 後 `to_dict()` 相同
  - `test_corrupt_or_old_save_is_ignored`（Review Focus 1）：寫入 `"not json"`、`{"version": 0, "state": {}}`、`{"version": 1}` 三種，`read()` 都回傳 `{}`；`from_dict({"cacao": "x"})` 回傳 false 且 `cacao` 不變
- [ ] **Step 2: 執行驗證指令**，Expected：上述測試 FAIL（`GameState` 不存在）
- [ ] **Step 3: 實作 `game_state.gd`、`save.gd`、新增數值**，`project.godot` 登記 autoload `GameState="*res://state/game_state.gd"`
- [ ] **Step 4: 執行驗證指令**，Expected：PASS
- [ ] **Step 5: Commit** `Add the game state and the single save slot (MV-SLICE-001a)`

---

### Task 3: Loadout：把 GameState 套到角色身上（武器、血量、熱湯）

**Files:**
- Create: `game/state/loadout.gd`
- Modify: `game/core/player/player.gd`（`_try_heal`）、`game/core/player/twin.gd`（沿用 `weapon_enabled`）、`game/ui/hud.gd`（沒有武器顯示「—」）
- Test: `game/tests/test_loadout.gd`

**Interfaces:**
- Consumes: Task 2 的 `GameState`
- Produces（`loadout.gd`，靜態）：
  - `static func make_player(gs, tn) -> Node`：建 Player（`tn` 指定），呼叫 `apply(player, gs)`
  - `static func apply(player, gs) -> void`：每個兄弟 `i`：`equip[i] == -1` → `twins[i].weapon_enabled=false`，否則 `weapon=equip[i]`、`weapon_enabled=true`；`player.health.hp=gs.hp`、`heal_charges=gs.heal_charges`；`player.abilities_enabled=gs.awakened`；`player.soup_source=gs`；連接 `player.hit_landed` → `gs.on_weapon_hit()`（只計近戰：`hit_landed` 只由近戰發出，已確認於 core）
  - `static func store(player, gs) -> void`：把 `hp`、`heal_charges` 寫回 gs（換房前呼叫）
- Produces（`player.gd`）：`var soup_source: Object = null`；`_try_heal()` 在 `heal_charges == 0`、在地面、`hp < max_hp`、`hp > 0` 時呼叫 `soup_source.take_soup()`，成功才 `health.heal_charges += 1` 再照原流程 `begin_heal()`

- [ ] **Step 1: Write the failing tests**：
  - `test_no_weapon_cannot_attack_but_can_dart`：`equip==[-1,-1]` 時按攻擊不出招，吹箭照常
  - `test_loadout_applies_equip_and_health`：`equip=[STICK,AXE]`、`hp=3` → Hunahpu 掘棒、Xbalanque 斧頭、`health.hp==3`
  - `test_heal_uses_soup_after_charges`：`heal_charges=0`、`soup=1`、`hp=2` → 治療完成後 `hp==2+heal_amount`、`soup==0`
  - `test_soup_not_taken_when_full_or_none`（Review Focus 5）：`hp==max_hp` 時按治療，`soup` 不變；`heal_charges=0`、`soup=0` 時按治療不進入治療狀態
  - `test_weapon_hit_recharges_skill`：近戰打中 4 次 `skill_res` +1；吹箭打中不算
  - `test_hud_shows_dash_without_weapon`：`twin_lines()` 含「—」
- [ ] **Step 2: 執行驗證指令**，Expected：FAIL
- [ ] **Step 3: 實作**
- [ ] **Step 4: 執行驗證指令**，Expected：PASS（含 Task 1 搬來的全部測試）
- [ ] **Step 5: Commit** `Apply the game state to the player: weapons, health and soup (MV-SLICE-001a)`

---

### Task 4: 房間資料、通用房間與換房

**Files:**
- Create: `game/world/room.gd`、`game/world/room_flow.gd`、`game/world/room_check.gd`、`game/world/rooms/_test_a.gd`、`game/world/rooms/_test_b.gd`（只給測試用的兩個小房間）
- Test: `game/tests/test_rooms.gd`

**Interfaces:**
- Produces：房間資料＝每個 `world/rooms/<id>.gd` 的 `static func data() -> Dictionary`，鍵：
  - `id: String`、`size: Vector2`、`ground_y: float`
  - `solids: Array`（Rect2）、`platforms: Array`（Rect2，單向）
  - `doors: Array`（`{id, rect: Rect2, to_room, to_door, spawn: Vector2}`；`spawn` 是從這扇門進來時角色站的位置）
  - `rest: Dictionary`（`{pos}`，可省略）、`npc: Dictionary`（`{kind: "grandmother", pos}`，可省略）
  - `enemies: Array`（`{kind: "crawler"|"flyer", pos}`）、`stash: Dictionary`（`{id, pos}`，可省略）
  - `pickups: Array`（`{id, item: "axe"|"stick"|"gear", pos}`）
  - `props: Array`（`{id, kind: "bush"|"clod"|"rat"|"rope", pos}`，Task 10 使用）
  - `triggers: Array`（`{id, rect, event}`）、`gates: Array`（`{rect, until_flag}`）
  - `layers: Dictionary`（子專案 b 用，先 `{}`）
  - 特殊房間：`{id: "boss", kind: "boss"}`（Task 11）
- Produces（`room.gd`，extends Node2D）：`func build(d: Dictionary, gs, tn) -> void`；`var player`；signals `door_entered(door_id: String)`、`trigger_entered(trigger_id: String)`、`interacted(kind: String)`；`func spawn_point(door_id: String) -> Vector2`；敵人加入 group `"enemy"`；`gs.defeated[id]` 裡的敵人不生成；`gates` 的 `until_flag` 已設時不生成
- Produces（`room_flow.gd`，extends Node）：`func goto(room_id: String, door_id: String) -> void`（淡出 0.25 秒 → `Loadout.store` → 釋放舊房 → `build` 新房 → 角色放在 `spawn_point(door_id)` → 淡入；換房進行中忽略新的 `goto`）；`func start(room_id: String) -> void`（不經過門，角色站在房間的 `rest.pos`）；signal `room_changed(id: String)`；`var current: Node`；`var rooms: Dictionary`（id → 資料腳本，由 Task 5 填入）
- Produces（`room_check.gd`，靜態）：`static func errors(d: Dictionary) -> PackedStringArray`——門的 `spawn`、`rest.pos`、`npc.pos`、`stash.pos`、`pickups`、`enemies`（爬行型）的位置要站在某個 solid 或 platform 的頂邊上（容差 2 px）、或 `y == ground_y`；飛行型不檢查；`static func link_errors(all: Dictionary) -> PackedStringArray`——每扇門的 `to_room` 存在、`to_door` 存在、且對方的門指回來

- [ ] **Step 1: Write the failing tests**：
  - `test_room_check_catches_floating_spawn`：一個 spawn 在空中的資料 → `errors()` 非空；修正後為空
  - `test_link_check_requires_return_door`
  - `test_build_creates_solids_enemies_and_skips_defeated`
  - `test_gate_hidden_after_flag`
  - `test_goto_places_player_at_door_spawn_and_keeps_hp`：在 `_test_a` 把 `hp` 改成 2，走進門 → 在 `_test_b` 的對應位置、`hp==2`
  - `test_goto_ignored_while_transitioning`（Review Focus 2）：同一幀呼叫兩次 `goto` → 只換一次房、`room_changed` 只發一次
- [ ] **Step 2: 執行驗證指令**，Expected：FAIL
- [ ] **Step 3: 實作**（地形用 core `test_room.gd` 的 `_add_solid` 做法；灰盒用 `_draw()` 畫色塊）
- [ ] **Step 4: 執行驗證指令**，Expected：PASS
- [ ] **Step 5: Commit** `Build rooms from data files and move between them through doors (MV-SLICE-001a)`

---

### Task 5: 地面的 9 個房間資料

**Files:**
- Create: `game/world/rooms/{home,yard,field,forest_1,forest_2,forest_3,forest_4,boss,exit}.gd`、`game/world/rooms/index.gd`
- Test: `game/tests/test_ground_rooms.gd`

**Interfaces:**
- Consumes: Task 4 的資料格式與 `room_check.gd`
- Produces: `index.gd` 的 `const ROOMS := {"home": preload(...), ...}`
- 房間內容（尺寸以 1920×1080 一個畫面為單位；跳躍高度 400、單跳上不去的高台 ≥ 450）：
  - `home`：1 畫面；`rest`、`npc grandmother`；門 `to_yard`；`props` 有 `rope`（Task 10 球具）
  - `yard`：2 畫面；左門 `to_field`、中門 `to_home`、右門 `to_forest`；`gates` 一個荊棘 `until_flag: "gear_obtained"` 擋在右門前
  - `field`：2 畫面；`pickups` 斧頭、掘棒；`props` 3 個 `bush`、3 個 `clod`；`triggers` 一個 `night`（Task 10）
  - `forest_1`：2 畫面，爬行型 2
  - `forest_2`：2 畫面，`rest`（篝火）、爬行型 1、飛行型 1
  - `forest_3`：2 畫面，爬行型 2、飛行型 1；`stash`（10 顆）在高 380 的平台上（單跳上得去）
  - `forest_4`：2 畫面，爬行型 2、飛行型 2；右門 `to_boss`
  - `boss`：`{id: "boss", kind: "boss", left_door: "to_forest_4"}`
  - `exit`：Boss 段落裡已有出口高台，所以 `exit` 只是結尾文字卡的掛點：`{id: "exit", kind: "ending"}`

- [ ] **Step 1: Write the failing tests**：
  - `test_ground_rooms_pass_room_check`：每個一般房間 `errors()` 為空
  - `test_ground_rooms_link`：`link_errors(ROOMS)` 為空（`boss` 的 `left_door` 指向 `forest_4` 的 `to_boss`）
  - `test_enemy_counts_per_room`：每房 1～4 隻（SLICE-a12）
  - `test_stash_reachable_by_single_jump`：stash 平台頂邊離地 ≤ `tn.jump_height`
  - `test_all_rooms_reachable_from_home`：從 `home` 沿門走得到 `boss`
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Lay out the ground rooms from the grandmother's house to the forest (MV-SLICE-001a)`

---

### Task 6: 可可豆、藏點、篝火休息與死亡回點

**Files:**
- Create: `game/world/pickup.gd`、`game/world/rest_point.gd`
- Modify: `game/world/room.gd`、`game/core/enemies/enemy.gd`（`died` 時掉可可豆）
- Test: `game/tests/test_rest_and_cacao.gd`

**Interfaces:**
- Consumes: Task 2、4
- Produces：敵人死亡掉 `randi_range(tn.cacao_drop_min, tn.cacao_drop_max)` 顆，直接 `gs.add_cacao`（灰盒：數字飄起）；`stash` 取過記 `gs.stashes_taken[id]=true`，加 `tn.stash_cacao`；篝火與祖母家：站在範圍內按 `interact` → `gs.rest(room_id)`、`Save.write(gs.to_dict())`、`gs.defeated.erase(...)` 後重建房間；角色死亡 → `room_flow.start(gs.last_rest)`，`hp`、`heal_charges` 回滿，可可豆不變
- Boss 段落的召喚物不掉可可豆（避免刷錢；Boss 設計只說回充技能資源）
- HUD 新增可可豆數量與熱湯碗數（`hud.gd` 讀 `GameState`）

- [ ] **Step 1: Write the failing tests**：
  - `test_enemy_drop_in_range`（固定 seed，掉落 1～3）
  - `test_stash_once`：取一次 +10，換房再回來不再出現
  - `test_rest_saves_and_respawns_enemies`：打倒一隻 → 休息 → 存檔存在、該敵人重生
  - `test_death_returns_to_last_rest_keeping_cacao`
  - `test_hud_shows_cacao_and_soup`
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Add cacao drops, the stash, resting and returning to the last rest (MV-SLICE-001a)`

---

### Task 7: 暫停選單、裝備頁與祖母兌換

**Files:**
- Create: `game/ui/pause_menu.gd`、`game/ui/equip_page.gd`、`game/ui/shop.gd`
- Test: `game/tests/test_menus.gd`

**Interfaces:**
- Consumes: Task 2
- Produces（`equip_page.gd`，extends Control）：`func open(gs) -> void`；兩欄的選項＝`gs.weapons_owned`；`func choose(twin: int, w: int) -> void` → `gs.equip_weapon`；技能區顯示 2 槽、`slot2_unlocked==false` 時第 2 槽鎖住；沒有武器時欄位顯示「—」
- Produces（`pause_menu.gd`）：`pause` 鍵開關；項目「裝備」「回主選單」「回到遊戲」；開啟時 `get_tree().paused = true`；signal `quit_to_title`
- Produces（`shop.gd`）：`func open(gs) -> void`；一個選項「熱湯（15 顆）」，`can_buy_soup()==false` 時灰掉；確認鍵 → `buy_soup()`
- 按鍵：上下選、攻擊鍵確認、`pause` 或翻滾鍵返回

- [ ] **Step 1: Write the failing tests**：
  - `test_equip_page_lists_owned_only`
  - `test_equip_page_no_weapons_shows_dash_and_no_duplicate`（Review Focus 4）：持有 0 把時兩欄都是「—」；持有 1 把時另一欄不能選同一把（選了等於互換，另一人變「—」）
  - `test_slot2_locked`
  - `test_pause_freezes_world`：開啟後 `get_tree().paused`，關閉後恢復
  - `test_shop_disables_when_poor_or_full`
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Add the pause menu, the equipment page and the grandmother's soup (MV-SLICE-001a)`

---

### Task 8: 動物技能：老鼠的鑽地突襲

**Files:**
- Create: `game/core/player/skill_user.gd`、`game/core/player/rat.gd`、`game/core/player/rat_target.gd`
- Modify: `game/core/player/intent.gd`（`skill_1`、`skill_2`）、`game/core/enemies/enemy.gd`（`stun(seconds: float)`）、`game/core/tuning/combat_tuning.gd`（群組「動物技能」）、`game/ui/hud.gd`（技能資源 3 格）、`game/state/loadout.gd`（掛上 `skill_user`）
- Test: `game/tests/test_rat.gd`

**Interfaces:**
- Consumes: Task 2（`use_skill`）、Task 3
- 數值（群組「動物技能」）：`rat_speed := 900.0`、`rat_range := 700.0`、`rat_damage := 3`、`rat_stun := 0.8`、`rat_max_dy := 40.0`
- Produces（`rat_target.gd`，靜態）：`static func pick(origin: Vector2, facing: int, candidates: Array, range: float, max_dy: float) -> Node`——候選要沒死、腳底 y 與 `origin.y` 相差 ≤ `max_dy`、在面前（`(x - origin.x) * facing >= 0`）、水平距離 ≤ `range`；回傳水平距離最近的，沒有回傳 `null`。位置一律是腳底（core 慣例）。
- Produces（`rat.gd`，extends Node2D）：`func launch(from: Vector2, facing: int, target: Node) -> void`；沿地面以 `rat_speed` 前進；到目標腳下 → `target.hurtbox.receive(rat_damage, self, &"dart")`（沿用吹箭的打斷與 Boss「吹箭打斷」破綻加成），`target.has_method("stun")` 時 `stun(rat_stun)`，然後消失；沒有目標 → 走 `rat_range` 後折返、回到角色位置消失；目標途中消失（`is_instance_valid`）→ 立即消失
- Produces（`skill_user.gd`，extends Node，掛在 player 下）：讀 `intent.skill_1`；技能槽 1 是 `"rat"` 且 `gs.use_skill(tn.skill_cost)` 成功才發動；資源不足時 `hud.flash_skill()`；候選＝`get_tree().get_nodes_in_group("enemy")`（Boss 也加入這個 group）
- Produces（`enemy.gd`）：`func stun(seconds: float) -> void`——非死亡狀態進入 `STAGGER`、`stagger_time = seconds`

- [ ] **Step 1: Write the failing tests**：
  - `test_rat_target_ground_only`：爬行型（腳底在地面）被選、飛行型（懸停）不選、身後的不選、超出 700 的不選
  - `test_rat_hits_crawler_and_stuns`：命中後 `hp` 少 3、進入 STAGGER
  - `test_rat_interrupts_telegraph_like_dart`
  - `test_rat_no_target_returns_and_costs`：沒有地面敵人 → 資源 -1、老鼠回來後消失
  - `test_rat_needs_resource`：資源 0 時不發動、資源不變
  - `test_rat_target_dies_midway`（Review Focus 3）：發動後目標被別的攻擊打死 → 老鼠消失、不報錯、資源只扣 1
  - `test_rat_counts_for_boss_gauge`：地面上的 Seven Macaw 在可打斷的招式中被老鼠咬 → 破綻條增加量＝吹箭打斷的加成
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Add the rat's burrowing strike as the first animal skill (MV-SLICE-001a)`

---

### Task 9: 按鍵提示

**Files:**
- Create: `game/ui/hints.gd`
- Test: `game/tests/test_hints.gd`

**Interfaces:**
- Consumes: Task 2（`hints_seen`）、`InputSetup.uses_mouse()`
- Produces（`hints.gd`，extends Control）：`func request(id: String) -> void`（`gs.hints_seen` 有就忽略；同時只顯示一個，後來的排隊）；`func satisfy(id: String) -> void`（目前顯示的是它 → 消失並記到 `hints_seen`）；`func text_for(id: String) -> String`（依 `uses_mouse()` 選鍵盤或手把的按鍵名稱）
- 提示 id 與文字（鍵盤／手把）：`move`「A／D 或 ←／→ 移動｜左搖桿移動」、`jump`「Space 跳躍｜A 跳躍」、`dart`「滑鼠右鍵 吹箭｜RT 吹箭（右搖桿瞄準）」、`attack`「滑鼠左鍵 攻擊｜X 攻擊」、`swap`「Tab 換人｜Y 換人」、`interact`「E 互動｜十字鍵下 互動」、`equip`「Esc → 裝備 換武器｜Start → 裝備 換武器」、`skill`「Q 老鼠鑽地突襲｜十字鍵左 老鼠鑽地突襲」、`heal`「R 治療｜十字鍵上 治療」
- 觸發點（由各 Task 呼叫 `request`）：開場 `move`、`jump`、`dart`；拿到工具 `attack`、`swap`；站在篝火、祖母、拾取點旁 `interact`；拿到球具與老鼠 `equip`、`skill`；第一次受傷 `heal`。滿足條件：做出對應動作（`equip`＝打開裝備頁）

- [ ] **Step 1: Write the failing tests**：`test_hint_shows_once`、`test_hint_queue_one_at_a_time`、`test_hint_text_follows_device`、`test_hints_seen_saved`
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Show first-time button hints that follow the input device (MV-SLICE-001a)`

---

### Task 10: 三個地面事件與荊棘

**Files:**
- Create: `game/events/field_clearing.gd`、`game/events/night_rat.gd`、`game/events/gear_drop.gd`、`game/world/prop.gd`（灌木、土塊、老鼠、繩子的灰盒）
- Modify: `game/world/room.gd`（依旗標掛事件）
- Test: `game/tests/test_events.gd`

**Interfaces:**
- Consumes: Task 2、4、6、9；core 的 `text_card.gd`（`show_card(s)`、signal `closed`）
- 旗標與順序（規格「事件」表）：
  - 開墾田地：拾取斧頭 → `give_weapon(AXE)`、拾取掘棒 → `give_weapon(STICK)`，兩把都拿到 → `tools_obtained`、提示 `attack`、`swap`；`bush` 只吃斧頭的近戰、`clod` 只吃掘棒的近戰（`hit_landed` 的武器判斷），6 個都清掉 → `field_cleared`
  - 入夜抓老鼠：`field_cleared` 後 3 秒自動開始（不在田地就等下次進田地時立刻開始）；文字卡 1「夜裡，動物們把田地復原了。兄弟倆守在田邊。」→ 田地變暗、灌木與土塊回來（`field_cleared` 不清掉）→ `rat` 在田裡移動，與角色距離 < 300 時往反方向以 `run_speed * 0.8` 跑；碰到左右牆 → 網子落下（灰盒：方框）→ 文字卡 2「老鼠答應告訴他們一件事，換一頓飯。兄弟倆給了牠玉米、豆子與可可。」→ `rat_caught`
  - 球具掉下：`rat_caught` 且未 `gear_obtained` 時進 `home` → 文字卡 3「老鼠說出了祕密：父親的球具，就掛在屋頂下。」→ `rope` 斷開、球具方塊落地 → 角色拾取 → `give_weapon(BALLGEAR)`、`give_skill("rat")`、提示 `equip`、`skill` → 文字卡 4「第二天早上，兄弟倆出發了。」→ `gear_obtained`
  - `yard` 的荊棘：`gear_obtained` 後不生成（Task 4 的 `gates`）
- 事件進行中（文字卡顯示、網子落下）鎖住角色輸入；事件中途死亡 → 事件沒設的旗標不設，下次從頭再來

- [ ] **Step 1: Write the failing tests**：
  - `test_field_needs_both_tools_and_six_clears`
  - `test_bush_only_axe_clod_only_stick`
  - `test_night_starts_three_seconds_after_clear`
  - `test_rat_flees_and_net_at_wall_sets_flag`
  - `test_gear_event_only_after_rat`：沒有 `rat_caught` 進祖母家不觸發；有了才觸發，結束後 `weapons_owned` 含球具、`skill_slots[0]=="rat"`、`gear_obtained`
  - `test_thorns_block_until_gear`
  - `test_death_mid_event_restarts_it`（Review Focus 2）：入夜事件進行中角色死亡 → 回祖母家、`rat_caught` 未設；再進田地事件重新開始
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Add the field clearing, the night rat catch and the falling ball gear (MV-SLICE-001a)`

---

### Task 11: Boss 段落接上 GameState

**Files:**
- Modify: `game/core/boss/boss_fight.gd`、`game/world/room_flow.gd`（`kind: "boss"`、`kind: "ending"`）
- Test: `game/tests/test_boss_segment.gd`

**Interfaces:**
- Consumes: Task 2、3、6、8
- 改動（只加不改原型的戰鬥邏輯）：
  - `_ready()`：建 player 後 `Loadout.apply(player, gs)`；`_apply_loadout()` 改成先套 GameState 再疊原型規則（斷臂、`abilities_enabled = awakened`）；Boss `add_to_group("enemy")`
  - 篝火：兩個 `rest_point(p)` 位置放 `rest_point.gd`，休息 → `gs.rest("nance_camp" | "palace_camp")`、`Save.write`
  - 左出口：`Stage.APPROACH` 且 `phase == 1` 時走到 nance 區最左邊 → signal `left_exit` → `room_flow.goto("forest_4", "to_boss")`
  - `func begin_at_rest(rest_id: String) -> void`：`"nance_camp"` → `_retry(1)`、`"palace_camp"` → `_retry(2)`（「繼續」從 Boss 段落的篝火接續）
  - 覺醒：`_on_setup(3)` 時 `gs.awakened = true`
  - `finished` → `room_flow.start("exit")` → 文字卡「垂直切片到此結束。」→ 回主選單
  - 移除測試日誌對 `--tester` 的依賴（固定 `tester = "slice"`），日誌照寫到 `user://boss_logs`
  - 刪除 `request_menu()` 的「2 秒內按兩次」：Boss 段落裡 `pause` 一樣開暫停選單；同時刪除搬來的 `test_menu_back_needs_second_press_in_boss`
- 數值與原型一致：不改 `combat_tuning.gd` 的「Boss」群組

- [ ] **Step 1: Write the failing tests**：
  - `test_boss_uses_equipped_weapons`：GameState `equip=[STICK,BALLGEAR]` → Boss 段落的角色 Hunahpu 掘棒（第 1 段）、Xbalanque 球具
  - `test_boss_rest_saves_with_id`：在 nance 篝火休息 → `last_rest=="nance_camp"`、存檔存在
  - `test_boss_left_exit_only_before_arena`：第 1 段開打前走到最左 → 回 `forest_4`；關門後不能
  - `test_continue_at_palace_camp`：`begin_at_rest("palace_camp")` → `phase==2`、角色在宮殿篝火
  - `test_awakening_sets_gamestate`
  - `test_boss_numbers_match_prototype`：`fresh_tuning()` 的 Boss 群組每個欄位等於 `prototypes/core/tuning/combat_tuning.gd` 的預設值（用 `load()` 讀原型腳本比對）
- [ ] **Step 2～4:** 失敗 → 實作 → 通過（MV-PROTO-003 搬來的測試也要全部通過）
- [ ] **Step 5: Commit** `Run the Seven Macaw segment inside the room flow with the shared game state (MV-SLICE-001a)`

---

### Task 12: 灰盒主選單、主流程、開發參數與自動走完全程

**Files:**
- Create: `game/ui/title_menu.gd`、`game/world/game_world.gd`
- Modify: `game/main.gd`、`game/launch_args.gd`
- Test: `game/tests/test_walkthrough.gd`

**Interfaces:**
- Consumes: 前面全部
- Produces（`title_menu.gd`）：項目「新遊戲」「繼續」；`Save.exists()==false` 時「繼續」不可選；有存檔時選「新遊戲」要再確認一次；signal `chosen(mode: String)`（`"new"`／`"continue"`）
- Produces（`game_world.gd`，extends Node2D）：持有 `room_flow`、HUD、`hints`、`pause_menu`、`shop`；`func new_game()`（`gs.reset_new_game()`、`start("home")`、提示 `move`、`jump`、`dart`）；`func continue_game()`（`Save.read()` → `from_dict` → `start(gs.last_rest)`；`last_rest` 是 Boss 篝火時進 Boss 段落並 `begin_at_rest`）
- 開發參數：`--room <id>`（只在 `OS.is_debug_build()`）：`reset_new_game()` 後直接 `start(<id>)`，`--room boss` 同 `--boss`

- [ ] **Step 1: Write the failing tests**：
  - `test_title_continue_disabled_without_save`
  - `test_continue_restores_room_and_state`
  - `test_walkthrough_new_game_to_exit`：以 `scripted` 角色依序：home → yard → field（拾取兩把、清 6 個）→ 等入夜 → 把老鼠逼到牆 → home（球具事件）→ yard → forest_1～4（用 `kill()` 清敵人）→ boss（每段用 `debug_fill_gauge()` 加 Hunahpu 設局飛鏢）→ 出口 → 結尾文字卡；全程 `SCRIPT ERROR` 為 0、最後回到主選單
- [ ] **Step 2～4:** 失敗 → 實作 → 通過
- [ ] **Step 5: Commit** `Add the gray-box title menu and walk the slice from start to finish (MV-SLICE-001a)`

---

### Task 13: 文件與收尾

**Files:**
- Create: `game/README.md`（執行、操作表含新增按鍵、開發參數、房間清單、存檔位置、自測指令、驗收步驟）
- Modify: `todo/spec/MV-SLICE-001a_地面關卡與系統.md`（驗收打勾、Git Commit 段）、`todo/todo.md`
- Create: `report/MV-SLICE-001a_地面關卡與系統_<date>_執行報告.md`（時間先跑 `date`）

- [ ] **Step 1: 執行驗證指令**，記錄 `SELFTEST SUMMARY`
- [ ] **Step 2: 實際開啟遊戲走一輪**（`godot --path game`）截圖：祖母家、田地入夜、裝備頁、兌換、Boss 段落入口，確認沒有 `SCRIPT ERROR`
- [ ] **Step 3: 寫 README、報告，派工單標「⏸️ 暫停（等待 Brian 手把驗收）」**
- [ ] **Step 4: Commit** `Document the slice project and report sub-project a (MV-SLICE-001a)`
