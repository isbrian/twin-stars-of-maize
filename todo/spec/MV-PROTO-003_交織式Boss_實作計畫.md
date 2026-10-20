# MV-PROTO-003 交織式 Boss 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在核心專案做一場完整的 Seven Macaw 灰盒 Boss 戰（三段設局、兩個場地與兩個篝火、文字卡、重試與段落保留、結尾覺醒出口），加上開頭選單與自動寫入的測試日誌，供 Brian 試打與 2～3 位外人測試。

**Architecture:** `boss/boss_fight.gd` 管整場流程（場地、段落、文字卡、篝火重試、日誌），底下一個 `world` 子樹放場地、角色、Boss、造物與飛鏢；`boss/seven_macaw.gd` 是 Boss 主體（段落、破綻條、硬直、光源、依循環出招），每一招是 `boss/moves/` 裡的一個小腳本。光源是只有飛鏢射線查得到的新碰撞層。`main.gd` 改成先顯示開頭選單，再切到練習房（既有 `test_room.gd`）或 Boss 戰。

**Tech Stack:** Godot 4.7.2、GDScript（不用 `class_name`，一律 `preload` 常數）；自動測試沿用 `tests/self_test.gd` 的 `--self-test` 執行器。

**Spec:** [todo/spec/MV-PROTO-003_交織式Boss.md](MV-PROTO-003_交織式Boss.md)（上層：[MV-BOSS-001](../../docs/design/MV-BOSS-001_SevenMacaw設計.md)）

## Global Constraints

- 分支 `feature/MV-PROTO-003_交織式Boss`（已建立，疊在 `feature/MV-PROTO-002_換人與武器` 上，規格書已 commit）。開工前確認 002 分支沒有新 commit；若 Brian 自評後 002 有修改，先合進本分支再繼續（規格「與 MV-PROTO-002 自評的關係」）。
- 不用 `class_name`；跨檔引用用 `preload` 常數；未標型別的變數不能用 `:=` 推斷（例：`var x: float = obj.prop`）。
- `self_test.gd` 檔頭的 `preload` 只在**建立該檔案的 Task** 加入（先 preload 不存在的檔案會讓整個測試檔解析失敗）。`seven_macaw.gd` 的 `MOVES` 表同理：每個招式在建立它的 Task 才登記。
- 避免循環 preload：招式腳本、`fruit.gd`、`pillar.gd` 不 preload `seven_macaw.gd`，需要 Boss 常數時讀 `boss.SIZE`；`self_test.gd` 不 preload `main.gd`（`main.gd` 已 preload 測試檔），啟動參數解析放在獨立的 `launch_args.gd`。
- 數值一律放 `tuning/combat_tuning.gd` 的新群組 `Boss`，程式每幀讀 `tn`（不快取）。
- 節點與地形用程式建立；場景檔不新增。
- 不改 `enemies/enemy.gd`、`crawler.gd`、`flyer.gd`、`level/test_room.gd` 的行為（PROTO3-7）；召喚出來的造物就是現有的爬行型與飛行型。
- 所有攻擊傷害 1；前搖訊號依 ART_SPEC 第 5 節：可招架＝白色圓形，不可招架＝暗紫鋸齒；不用紅色。
- 文字卡只寫原典有的事、不提示玩法（不得出現「破綻、設局、光源、微亮、最亮、吹箭、背對、二段跳、弱點」）。
- 名稱：依 MV-NAME-001 名稱表（Brian 2026-10-05 填寫）的繁中顯示名：胡納普（H01）、希巴拉克（H02）、七金剛鸚鵡（O13）、奇瑪瑪特（O14）。兩位老人（A01、A02）尚未定案，文字卡不寫他們的名字，只稱「兩位老人」。名稱集中在 `boss/card_text.gd` 與 `player/twin.gd`（計畫 D10）。
- MV-PROTO-001／002 的 101 項測試除 `test_input_scheme_a_registered`（新增按鍵，Task 1 改預期值）與 `test_hud_twin_lines`（顯示名改繁中，Task 9 改預期值）外，全部不改、全部 PASS。
- 測試指令（每個 Task 結尾用這個）：
  ```bash
  godot --headless --fixed-fps 60 --quit-after 60000 --path prototypes/core -- --self-test > /tmp/p3_selftest.log 2>&1; tail -3 /tmp/p3_selftest.log; grep -c "SCRIPT ERROR" /tmp/p3_selftest.log
  ```
  通過的定義：`SELFTEST SUMMARY ... fail=0` 且 `SCRIPT ERROR` 計數為 0。`--quit-after` 從 18000 提高到 60000（Boss 測試要等 4 秒硬直、2.5 秒招式）；若輸出沒有 `SELFTEST SUMMARY`，表示幀數上限到了，再調高。

## 本計畫的決定（規格書沒寫到的細節）

| # | 決定 | 理由 |
|---|---|---|
| D1 | Boss 是 `Node2D`，不與地形碰撞；位置由招式直接移動（`move_toward`），目標位置都在場地常數內 | Boss 會飛、會降到低枝、會衝撞，物理身體只會增加卡牆的問題；碰觸本來就不傷人（PROTO1-4） |
| D2 | 光源用新碰撞層 `LIGHT`（128），熄滅時拿掉層；飛鏢每幀**另做一次只查光源的射線**，同一段路徑上光源優先，除非地形比光源更近 | 光源在 Boss 身體裡面，射線會先碰到身體的邊；熄滅時要讓飛鏢「穿過」去打身體 |
| D3 | 文字卡的「暫停」＝把 `world` 子樹的 `process_mode` 設為 `DISABLED`（不動 `SceneTree.paused`）；文字卡至少顯示 0.5 秒才接受攻擊鍵 | 暫停整棵樹會卡住 `--self-test`；設局常在狂按攻擊時發生，沒有最短時間文字卡會一閃而過 |
| D4 | Boss 的攻擊被招架：該次判定結束、破綻 +15，直接進入該招之後的空檔；不另加硬直 | 規格只定了破綻量；Boss 不是一般敵人，不套 1.2 秒招架硬直 |
| D5 | 招式之間有 `boss_move_gap` 0.4 秒；移動到出招位置（樹冠、低枝、玩家身邊、撞寶座的起點）不算前搖，不能打斷 | 規格沒有招式間隔；完全無縫的連招讀不出來 |
| D6 | 循環字串裡的未知招式名稱跳過；整圈都出不了招時停在空檔、不當機 | 循環在檢查器裡可改，打錯字不能讓遊戲壞掉 |
| D7 | `attempt_start` 在每段**開打**時記（入口關上那一刻、第 3 段在換牙文字卡關閉時）；摘要的總嘗試次數＝死亡次數＋1；每段累計時間＝各次開打到該次死亡／設局／離開；「沒有進展」的區間所屬的段＝區間結束前最後一筆帶段的事件的段 | 規格要「總嘗試次數」「每段累計時間」，這是不會重複計算的定義 |
| D8 | 兩個區域分開放在同一個世界：樹下區 x −100～6720、宮殿區 x 7800～17020；第 1 段設局後把角色傳送到小路起點 | 單一畫面的 Boss 房＋各自的篝火走廊，不需要跨區相機 |
| D9 | 宮殿：入口在左（老夫婦）、寶座在右；出口的木障就是宮殿的右牆，後面是走廊與 550 px 高台 | 戰鬥中「讓工具自己動」停用，木障就是普通的牆；覺醒後當場射開（BOSS-9c） |
| D10 | 文字卡與 Boss 名稱集中在 `boss/card_text.gd`、兄弟名稱在 `twin.gd`，用名稱表的繁中顯示名；兩位老人不寫名字 | MV-NAME-001 已填 H、O 兩區；A 區（兩位老人）未填，不自行定名 |
| D11 | 另加除錯／展示參數：`--boss-phase <1～4>`（直接從該段開打；4＝覺醒後的出口）、`--demo-boss-intro`、`--demo-boss-flash`、`--demo-boss-p3`；Esc／手把 Start 回選單；1／2／3 換武器在 Boss 戰仍有效（不告訴外人） | 錄影驗收要拍開場、假光閃耀、第 3 段；規格提到「回選單」但沒定按鍵 |
| D12 | 死因＝最後打中角色的來源的 `move_name`（Boss 目前的招式、果子、反光柱）；造物記 `summon`；沒有來源記 `unknown` | 日誌 `death` 要「最後打中玩家的招式」 |
| D13 | 自動換成 Hunahpu 用新的 `force_twin(0)`：不受冷卻、也不設冷卻；攻擊或招架中會結束該動作，翻滾、受擊、治療照舊 | 「原地換人、不打斷移動與瞄準」；斷臂的 Hunahpu 不能繼續 Xbalanque 的攻擊 |
| D14 | 第 1 段設局後血量不補；只有回篝火才補滿 | 規格只寫篝火補滿 |
| D15 | Boss 速度等初始值：飛行 1100、走路 700、俯衝 1600、撞寶座 1800、撲擊 1400（最遠 900 px）、果子 1000（px/s）；走到玩家身邊最多追 1.5 秒；開場吃果子 3 秒 | 規格第 7 節要求實作計畫訂速度初始值；以跑速 900 為基準 |
| D16 | 反光柱：第 1 道在撞上寶座那一刻的角色 x，其餘 `pillar_count − 1` 道在 `LEFT + 1920 × i ÷ pillar_count`（i＝1…） | 「兩道在固定位置」；數量可調時位置跟著平均分布 |
| D17 | 光束長度＝Boss 前緣到面向那一側的場地邊界；高度帶 `beam_band` (20, 100) | 規格「貼地的水平光束（離地 20～100 px）」 |
| D18 | F10 只在接近場地或戰鬥中有效（回到該段的篝火、Boss 回到該段開頭，不記死亡）；文字卡、開場、出口時忽略 | 「重來目前的場地」 |
| D19 | 不新增音效：微亮命中與吹箭打斷用 `interrupt`，其餘沿用練習房的接法 | 規格「不做：音樂」；佔位音效已足夠回饋 |
| D20 | Boss 戰的 HUD 不顯示除錯鍵提示；Hunahpu 斷臂時 HUD 的武器欄顯示「—」 | 除錯鍵不告訴外人；攻擊鍵沒反應時要看得出原因 |

### 世界座標（D8、D9；`GROUND_Y` 900，單跳 400、二段跳約 700、跑速 900）

| 常數 | 值 | 說明 |
|---|---|---|
| `Nance.REST` | (300, 900) | 樹下篝火 |
| `Nance.LEFT`／`RIGHT` | 4800／6720 | 篝火到入口 4500 px＝約 5 秒；場地寬 1920（單一畫面） |
| `Nance.ENTRY_X` | `LEFT + 150` | 角色越過 → 入口關上 |
| `Nance.TREE_X` | 5760 | 樹幹（只畫，不碰撞） |
| `Nance.CANOPY` | (5760, 100) | 樹冠，Boss 腳底離地 800：高於近戰最高點 400＋180＋210＝790 |
| `Nance.BRANCH` | Rect2(5840, 640, 420, 30) | 低枝，單向平台，離地 260 |
| `Nance.PERCH` | (6050, 640) | 吃果子時 Boss 的腳底 |
| `Nance.VIEW` | Rect2(4800, −60, 1920, 1080) | 入口關上後的相機範圍 |
| `Palace.PATH_START` | (8000, 900) | 小路起點 |
| `Palace.REST` | (9500, 900) | 宮殿篝火 |
| `Palace.LEFT`／`RIGHT` | 14000／15920 | 篝火到入口 4500 px |
| `Palace.HOME` | (15300, 900) | 第 2、3 段 Boss 的起始位置 |
| `Palace.PLATFORMS` | Rect2(14300, 640, 320, 30)、Rect2(15150, 640, 320, 30) | 兩側低台（單向） |
| `Palace.THRONE_X` | `RIGHT − 140` | 撞寶座的終點 |
| `Palace.COUPLE_X` | `LEFT + 120` | 老夫婦（只畫） |
| `Palace.BARRIER` | Rect2(15860, −60, 60, 960) | 出口木障＝宮殿右牆 |
| `Palace.EXIT_LEDGE` | Rect2(16320, 350, 600, 950) | 出口高台，離地 550；頂端是出口 |
| `Palace.EXIT_RIGHT` | 17020 | 宮殿區右牆 |

兩個場地的入口大門都是 `Rect2(LEFT, −60, 40, 960)`；相機上下界 `GROUND_Y − 960`～`GROUND_Y + 120`。

## Review Focus

1. 設局成功時正在狂按攻擊鍵：文字卡不能一閃而過（Task 9 `test_card_ignores_confirm_before_min_time`）。
2. `--tester` 給了空白、斜線、冒號等字元：日誌檔名要能建立（Task 8 `test_log_safe_name`）。
3. Boss 戰中途直接關掉視窗或按 Esc 回選單：摘要 `.md` 仍要寫出、事件最後一筆是 `quit`（Task 11 `test_fight_quit_writes_summary`）。
4. 在檢查器把循環字串打錯或清空：Boss 跳過那一招或停在空檔，不當機（Task 4 `test_cycle_next_rules`）。
5. 破綻滿、自動換成 Hunahpu 的硬直中死掉：重試後 Boss 回到該段開頭、光源熄滅、破綻 0（Task 11 `test_death_during_break_resets_boss`）。

---

### Task 1: 數值、角色開關、按鍵

**Files:**
- Modify: `prototypes/core/tuning/combat_tuning.gd`、`prototypes/core/player/twin.gd`、`prototypes/core/player/player.gd`、`prototypes/core/player/blowgun.gd`、`prototypes/core/input_setup.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Produces:
  - `combat_tuning.gd` 新群組 `@export_group("Boss")`（放在「場地」之前）：`gauge_max := 100`、`gauge_melee := 8`、`gauge_parry := 15`、`gauge_dart_interrupt := 10`、`gauge_glow_hit := 12`、`boss_stagger_time := 4.0`、`gauge_miss_reset := 50`、`boss_interrupt_stagger := 0.6`、`whiteout_in := 0.3`、`whiteout_hold := 1.4`、`whiteout_out := 0.3`、`boss_move_gap := 0.4`、`boss_fly_speed := 1100.0`、`boss_walk_speed := 700.0`、`boss_chase_max := 1.5`、`intro_eat_time := 3.0`、`throw_telegraph := 0.6`、`fruit_speed := 1000.0`、`eat_time := 2.5`、`dive_telegraph := 0.7`、`dive_speed := 1600.0`、`dive_rest := 1.2`、`flash_telegraph := 1.0`、`summon_telegraph := 0.6`、`flail_telegraph := 0.5`、`flail_active := 0.6`、`flail_box := Vector2(380, 220)`、`wail_time := 2.5`、`charge_telegraph := 0.8`、`charge_speed := 1800.0`、`pillar_warn := 0.8`、`pillar_active := 0.4`、`pillar_count := 3`、`pounce_telegraph := 0.6`、`pounce_speed := 1400.0`、`pounce_max := 900.0`、`pounce_rest := 1.2`、`beam_charge := 1.2`、`beam_active := 0.5`、`beam_band := Vector2(20, 100)`、`beam_wobble := 1.0`、`phase1_cycle := PackedStringArray(["summon", "throw_fruit", "eat_fruit", "dive", "throw_fruit", "eat_fruit", "false_flash"])`、`phase2_cycle := PackedStringArray(["flail", "wail", "throne_charge", "wail"])`、`phase3_cycle := PackedStringArray(["summon", "stagger_pounce", "beam", "stagger_pounce", "beam"])`、`summon_cap_p1 := 1`、`summon_cap_p3 := 2`
  - `twin.gd`：`var weapon_enabled := true`（斷臂時 false）、`var can_trigger_setup := false`（`hunahpu()` 設 true）
  - `player.gd`：
    - `var abilities_enabled := true`：false 時 `_try_double_jump()` 一律不成立
    - `_state_free` 的攻擊：`twin().weapon_enabled` 為 false 時清掉 `attack_buffer_left`、不出招（吹箭、翻滾、跳躍、治療照常）
    - `func force_twin(i: int) -> void`（D13）：已是 i 就不動；`ATTACK`／`PARRY` 中先 `hitbox.stop()`＋`_enter(State.FREE)`；設 `twin_index`、`swap_flash_left`、清 `swap_buffer_left`、發 `swapped`；不碰 `swap_cooldown_left`
    - `var last_hurt_source: Node`：`_on_hurt` 確定扣到血後、發 `hurt_taken` 前記下 `source`
  - `blowgun.gd`：`d.marks_barrier = player.twin().can_send_tool and player.abilities_enabled`
  - 按鍵：`debug_gauge`（F11）、`menu_back`（Esc、手把 Start）

- [ ] **Step 1: 寫失敗的測試**（新段落 `# ---- MV-PROTO-003 Task 1：數值、角色開關、按鍵 ----`）

```gdscript
func test_p3_tuning_defaults() -> void:
	var t := fresh_tuning()
	check(t.gauge_max == 100 and t.gauge_melee == 8 and t.gauge_parry == 15 and t.gauge_dart_interrupt == 10 and t.gauge_glow_hit == 12, "破綻量 100／8／15／10／12")
	check(is_equal_approx(t.boss_stagger_time, 4.0) and t.gauge_miss_reset == 50, "硬直 4 秒、錯過退回 50")
	check(is_equal_approx(t.boss_interrupt_stagger, 0.6), "吹箭打斷硬直 0.6")
	check(is_equal_approx(t.whiteout_in, 0.3) and is_equal_approx(t.whiteout_hold, 1.4) and is_equal_approx(t.whiteout_out, 0.3), "白茫 0.3／1.4／0.3")
	check(t.phase1_cycle == PackedStringArray(["summon", "throw_fruit", "eat_fruit", "dive", "throw_fruit", "eat_fruit", "false_flash"]), "第 1 段循環")
	check(t.phase2_cycle == PackedStringArray(["flail", "wail", "throne_charge", "wail"]), "第 2 段循環")
	check(t.phase3_cycle == PackedStringArray(["summon", "stagger_pounce", "beam", "stagger_pounce", "beam"]), "第 3 段循環")
	check(t.summon_cap_p1 == 1 and t.summon_cap_p3 == 2 and t.pillar_count == 3, "召喚上限 1／2、反光柱 3 道")
	check(Tune.table(t).contains("| Boss | gauge_max | 100 |"), "數值表應有 Boss 群組")


func test_armless_hunahpu_cannot_attack_but_darts() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.twins[0].weapon_enabled = false
	p.intent.attack_pressed = true
	await frames(2)
	check(p.state == Player.State.FREE, "武器槽停用時攻擊鍵無效")
	p.intent.dart_pressed = true
	await frames(1)
	check(count_darts(w) == 1, "武器槽停用時吹箭照常")
	p.swap_twin()
	await frames(1)
	p.intent.attack_pressed = true
	await frames(2)
	check(p.state == Player.State.PARRY, "Xbalanque 的攻擊照常（球具招架）")
	await free_world(w)


func test_abilities_disabled_blocks_double_jump_and_tool() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.abilities_enabled = false
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(10)
	p.intent.jump_pressed = true
	await frames(1)
	check(not p.air_jump_used, "能力停用時不能二段跳")
	p.intent.jump_held = false
	await wait_until(func(): return p.is_on_floor(), 120)
	var b = make_barrier(w)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	await frames(30)
	check(not is_instance_valid(p.tool) and not b.is_broken, "能力停用時 Xbalanque 的飛鏢不會派出工具")
	p.abilities_enabled = true
	await frames(25)
	p.intent.dart_pressed = true
	var broke: bool = await wait_until(func(): return b.is_broken, 120)
	check(broke, "能力開啟後照常派工具")
	await free_world(w)


func test_force_twin_ignores_cooldown_and_keeps_roll() -> void:
	var w := make_world()
	var p = await make_player(w)
	p.swap_twin()
	check(p.swap_cooldown_left > 0.0, "前提：剛換完人、冷卻中")
	p.force_twin(0)
	check(p.twin_index == 0, "強制換人不受冷卻限制")
	p.swap_twin()
	p.intent.roll_pressed = true
	await frames(2)
	p.force_twin(0)
	check(p.twin_index == 0 and p.state == Player.State.ROLL, "翻滾中強制換人不打斷翻滾")
	await free_world(w)


func test_last_hurt_source_recorded() -> void:
	var w := make_world()
	var p = await make_player(w)
	var src := Node2D.new()
	w.add_child(src)
	p.hurtbox.receive(1, src, &"enemy")
	check(p.last_hurt_source == src, "應記下最後打中角色的來源")
	await free_world(w)
```

並把 `test_input_scheme_a_registered` 的 `expect` 加上 `"debug_gauge": 1, "menu_back": 2`。

- [ ] **Step 2: 執行測試確認失敗**

Run: 測試指令
Expected: 上述新測試 FAIL 或 `SCRIPT ERROR`（欄位與方法不存在）；`test_input_scheme_a_registered` FAIL（缺 `debug_gauge`）

- [ ] **Step 3: 實作**：照 Interfaces 加數值、`twin.gd` 欄位、`player.gd` 的四項修改、`blowgun.gd` 一行、兩個按鍵；`combat_tuning.gd` 檔頭註解加上「MV-PROTO-003 新增 Boss（規格書第 7 節）」。

- [ ] **Step 4: 執行測試確認通過**（Expected：`fail=0`、`SCRIPT ERROR` 0）

- [ ] **Step 5: Commit**

```bash
git add prototypes/core/tuning/combat_tuning.gd prototypes/core/player/twin.gd prototypes/core/player/player.gd prototypes/core/player/blowgun.gd prototypes/core/input_setup.gd prototypes/core/tests/self_test.gd
git commit -m "Add boss tuning, armless and ability switches, forced swap and new keys (MV-PROTO-003)"
```

---

### Task 2: 破綻條、光源、飛鏢打光源

**Files:**
- Create: `prototypes/core/boss/break_gauge.gd`、`prototypes/core/boss/light_source.gd`
- Modify: `prototypes/core/combat/layers.gd`、`prototypes/core/player/dart.gd`、`prototypes/core/player/blowgun.gd`
- Test: `prototypes/core/tests/self_test.gd`（檔頭 preload `BreakGauge`、`Light`）

**Interfaces:**
- Consumes: Task 1 的 `twin.can_trigger_setup`
- Produces:
  - `layers.gd`：`const LIGHT := 128  # Boss 光源（MV-PROTO-003）：只有飛鏢的射線查得到`
  - `break_gauge.gd`（`extends RefCounted`，純邏輯）：`var value := 0`；`func add(amount: int, cap: int) -> bool`（已滿時不累積、回傳 false；這次加到上限回傳 true，值不超過上限）；`func is_full(cap: int) -> bool`；`func miss(reset_to: int) -> void`；`func clear() -> void`
  - `light_source.gd`（`extends "res://combat/hurtbox.gd"`）：`enum State { OFF, GLOW, BRIGHT }`、`enum Effect { NONE, GLOW_HIT, SETUP }`、`var state := State.OFF`；`func set_state(s: int) -> void`（OFF 時 `set_deferred("collision_layer", 0)`，其他狀態放回 `L.LIGHT`；`queue_redraw()`）；`static func effect(s: int, can_setup: bool) -> int`（GLOW → `GLOW_HIT`；BRIGHT 且 can_setup → `SETUP`；其他 `NONE`）；建立方式：`setup(Vector2(40, 40), Vector2.ZERO, L.LIGHT)` 後加入場景，初始為 OFF（`setup` 之後直接把 `collision_layer` 設 0）
  - 光源繪圖（規格第 2 節：兩者一眼分得出來）：OFF＝半徑 6 的暗珠寶色小圓；GLOW＝半徑 9 的亮白黃光點，0.5 秒週期脈動；BRIGHT＝半徑 34 的實心亮光＋8 道向外放射的光線（長 60）
  - `dart.gd`：`var can_setup := false`（發射時決定）；每幀先照原本做一般射線，再做一次 `mask = L.LIGHT`、`collide_with_areas = true`、`collide_with_bodies = false`、`hit_from_inside = true` 的射線；光源有命中且（一般射線沒命中，或一般命中不是地形，或光源命中點比較近）→ `light.receive(tn.dart_damage, self, &"dart")`、飛鏢消失；否則照原本處理（D2）
  - `blowgun.gd`：`d.can_setup = player.twin().can_trigger_setup`

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 2：破綻條、光源、飛鏢打光源 ----

func test_break_gauge_rules() -> void:
	var g = BreakGauge.new()
	check(not g.add(8, 100) and g.value == 8, "近戰 +8")
	g.add(15, 100)
	g.add(10, 100)
	g.add(12, 100)
	check(g.value == 45, "各來源累加應為 45，實際 %d" % g.value)
	g.value = 95
	check(g.add(8, 100), "加到上限應回傳滿")
	check(g.value == 100, "不超過上限")
	check(not g.add(8, 100) and g.value == 100, "滿了之後不累積、不再回傳滿")
	g.miss(50)
	check(g.value == 50, "錯過退回 50")
	g.clear()
	check(g.value == 0, "換段歸 0")


func test_light_effect_table() -> void:
	check(Light.effect(Light.State.OFF, true) == Light.Effect.NONE, "熄滅：沒有效果")
	check(Light.effect(Light.State.GLOW, false) == Light.Effect.GLOW_HIT, "微亮：誰的箭都算微亮命中")
	check(Light.effect(Light.State.BRIGHT, true) == Light.Effect.SETUP, "最亮＋Hunahpu 的箭：設局")
	check(Light.effect(Light.State.BRIGHT, false) == Light.Effect.NONE, "最亮＋Xbalanque 的箭：沒有效果")


## 假 Boss：身體受擊框 180×140（x=at_x、站在地上）＋面向角色那一側、吹箭口高度的光源；回傳 [身體, 光源, 紀錄]
func make_fake_boss(w: Node2D, at_x: float) -> Array:
	var got := []
	var body := Hurtbox.new()
	body.setup(Vector2(180, 140), Vector2(0, -70), L.ENEMY_HURT)
	body.position = Vector2(at_x, 0)
	body.hurt.connect(func(_a, _s, kind): got.append(["body", kind]))
	w.add_child(body)
	var light = Light.new()
	light.setup(Vector2(40, 40), Vector2.ZERO, L.LIGHT)
	light.collision_layer = 0
	light.position = Vector2(-60, -45)
	light.hurt.connect(func(_a, src, _k): got.append(["light", src.get("can_setup")]))
	body.add_child(light)
	return [body, light, got]


func test_dart_passes_off_light_to_body() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2] == [["body", &"dart"]], "熄滅的光源不擋飛鏢，打到身體，實際 %s" % [a[2]])
	await free_world(w)


func test_dart_hits_glowing_light_before_body() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 600.0)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	p.intent.dart_pressed = true
	await frames(25)
	check(a[2] == [["light", true]], "微亮的光源比身體先被打到，且 Hunahpu 的箭能觸發設局，實際 %s" % [a[2]])
	await free_world(w)


func test_dart_setup_flag_decided_at_fire() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 900.0)
	a[1].set_state(Light.State.BRIGHT)
	p.swap_twin()
	await frames(25)
	p.intent.dart_pressed = true
	await frames(1)
	p.swap_twin()
	await frames(30)
	check(p.twin_index == 0, "前提：飛行中已換回 Hunahpu")
	check(a[2] == [["light", false]], "Xbalanque 射出的箭飛行中換人，仍不能觸發設局，實際 %s" % [a[2]])
	await free_world(w)


func test_melee_cannot_hit_light() -> void:
	var w := make_world()
	var p = await make_player(w)
	var a := make_fake_boss(w, 150.0)
	a[1].set_state(Light.State.GLOW)
	await frames(2)
	p.intent.attack_pressed = true
	await frames(20)
	check(a[2] == [["body", &"melee"]], "近戰只打到身體、打不到光源，實際 %s" % [a[2]])
	await free_world(w)
```

- [ ] **Step 2: 執行測試確認失敗**（Expected：新測試 FAIL 或 `SCRIPT ERROR`，檔案不存在）
- [ ] **Step 3: 實作** `break_gauge.gd`、`light_source.gd`、`layers.gd`、`dart.gd`、`blowgun.gd`（照 Interfaces；`dart.gd` 檔頭註解補上「光源優先」）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/break_gauge.gd prototypes/core/boss/light_source.gd prototypes/core/combat/layers.gd prototypes/core/player/dart.gd prototypes/core/player/blowgun.gd prototypes/core/tests/self_test.gd
git commit -m "Add break gauge, boss light source and dart priority on lights (MV-PROTO-003)"
```

---

### Task 3: 場地（nance 樹、宮殿與出口）

**Files:**
- Create: `prototypes/core/boss/terrain.gd`、`prototypes/core/boss/nance_arena.gd`、`prototypes/core/boss/palace_arena.gd`
- Test: `prototypes/core/tests/self_test.gd`（preload `Nance`、`Palace`）

**Interfaces:**
- Consumes: `level/barrier.gd`（出口木障）
- Produces:
  - `terrain.gd`（`extends RefCounted`）：`static func add_solid(parent: Node, r: Rect2, one_way := false) -> CollisionShape2D`（同 `test_room._add_solid`，回傳形狀供大門切換 `disabled`）
  - 兩個場地都 `extends Node2D`，常數見上方「世界座標」表，另有：`const GROUND_Y := 900.0`、`const REGION: Rect2`（接近時的相機範圍：nance＝Rect2(−100, −60, 6820, 1080)；宮殿＝Rect2(7800, −60, 8120, 1080)）、`var gate_closed := false`、`func close_gate() -> void`、`func open_gate() -> void`（大門形狀 `set_deferred("disabled", …)`、`visible`）
  - nance 區建立：地面 Rect2(−100, 900, 6820, 400)、左牆 Rect2(−200, −60, 100, 1360)、右牆 Rect2(6720, −60, 100, 1360)、低枝（單向）、入口大門（初始打開）；`_draw` 畫地面、樹幹（`TREE_X` 寬 80、從地面到樹冠）、樹冠（橢圓）、低枝、篝火
  - 宮殿區建立：地面 Rect2(7800, 900, 9220, 400)、左牆 Rect2(7700, −60, 100, 1360)、右牆 Rect2(17020, −60, 100, 1360)、兩側低台（單向）、`EXIT_LEDGE`、入口大門、`var barrier`（`Barrier.new()`＋`setup(BARRIER)`，在 `_ready` 加入）；`_draw` 畫地面、篝火、金銀寶座（`THRONE_X` 附近 160×300，金銀二色）、Chimalmat（寶座旁的暗色剪影）、老夫婦在 `COUPLE_X`（兩個灰盒，只在 `couple_static` 為 true 時畫）、出口標記；`var couple_static := false`
  - `palace_arena.gd`：`const EXIT_VIEW := Rect2(LEFT, −60, EXIT_RIGHT − LEFT, 1080)`、`static func pillar_xs(count: int, player_x: float) -> Array`（D16）、`static func on_exit(p: Vector2) -> bool`（`p.x >= EXIT_LEDGE.position.x` 且 `p.y <= EXIT_LEDGE.position.y + 2`）

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 3：場地 ----

## 在場地放角色（不放 Boss）；回傳 [容器, 場地, 角色]
func arena_setup(scr, at: Vector2) -> Array:
	var w := Node2D.new()
	add_child(w)
	var a = scr.new()
	w.add_child(a)
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = at
	w.add_child(p)
	await frames(3)
	return [w, a, p]


## 依 steps 逐幀填角色的操作（格式同 explore_bot）
func drive(p, steps: Array) -> void:
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


## 從高台左緣前 150 px 起跑 → 跳 → 空中再按跳（同 test_explore_ledge1_needs_double_jump）
const CLIMB := [
	{"frames": 20, "move_x": 1.0},
	{"frames": 22, "move_x": 1.0, "jump": true, "hold": true},
	{"frames": 40, "move_x": 1.0, "jump": true, "hold": true},
	{"frames": 30, "move_x": 1.0},
]


func test_nance_canopy_out_of_melee_reach() -> void:
	var t := fresh_tuning()
	var reach := t.jump_height + Player.SIZE.y + maxf(t.axe_up_box.y, t.stick_up_box.y)
	var canopy := Nance.GROUND_Y - Nance.CANOPY.y
	check(canopy > reach, "樹冠（離地 %.0f）應高於近戰最高點 %.0f" % [canopy, reach])


func test_nance_branch_single_jump() -> void:
	var s: Array = await arena_setup(Nance, Vector2(Nance.BRANCH.position.x - 150.0, Nance.GROUND_Y))
	var p = s[2]
	p.abilities_enabled = false
	p.intent.move_x = 1.0
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(30)
	p.intent.move_x = 0.0
	await frames(30)
	check(p.is_on_floor() and absf(p.position.y - Nance.BRANCH.position.y) < 2.0, "單跳應能站上低枝，實際 %s" % p.position)
	await free_world(s[0])


func test_arena_gate_blocks_after_close() -> void:
	var s: Array = await arena_setup(Nance, Vector2(Nance.LEFT + 200.0, Nance.GROUND_Y))
	s[1].close_gate()
	await frames(2)
	var p = s[2]
	p.intent.move_x = -1.0
	await frames(40)
	check(p.position.x > Nance.LEFT + 40.0, "入口關上後走不回去，實際 x=%.0f" % p.position.x)
	s[1].open_gate()
	await frames(40)
	check(p.position.x < Nance.LEFT, "打開後可以通過，實際 x=%.0f" % p.position.x)
	await free_world(s[0])


func test_palace_barrier_is_right_wall() -> void:
	var s: Array = await arena_setup(Palace, Vector2(Palace.RIGHT - 300.0, Palace.GROUND_Y))
	var p = s[2]
	p.intent.move_x = 1.0
	await frames(40)
	check(p.position.x < Palace.BARRIER.position.x, "出口木障擋住通道，實際 x=%.0f" % p.position.x)
	check(not s[1].barrier.is_broken, "木障一開始完好")
	await free_world(s[0])


func test_palace_exit_needs_double_jump() -> void:
	var start := Vector2(Palace.EXIT_LEDGE.position.x - 150.0, Palace.GROUND_Y)
	var s: Array = await arena_setup(Palace, start)
	var p = s[2]
	p.abilities_enabled = false
	await drive(p, CLIMB)
	check(not Palace.on_exit(p.position), "能力停用時上不了出口高台，實際 %s" % p.position)
	p.position = start
	p.velocity = Vector2.ZERO
	p.abilities_enabled = true
	await frames(3)
	await drive(p, CLIMB)
	check(Palace.on_exit(p.position), "二段跳應能上出口高台，實際 %s" % p.position)
	await free_world(s[0])


func test_pillar_positions() -> void:
	var xs: Array = Palace.pillar_xs(3, 14800.0)
	check(xs.size() == 3 and is_equal_approx(xs[0], 14800.0), "3 道、第一道在角色位置")
	check(is_equal_approx(xs[1], Palace.LEFT + 640.0) and is_equal_approx(xs[2], Palace.LEFT + 1280.0), "其餘在固定位置，實際 %s" % [xs])
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**三個檔案（照 Interfaces 與世界座標表；檔頭註解寫規格第 4 節、計畫 D8、D9；`terrain.gd` 加 `ponytail: yagni: 地形用矩形資料建立 | upgrade if: 正式素材進來，改用 TileMapLayer`）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/terrain.gd prototypes/core/boss/nance_arena.gd prototypes/core/boss/palace_arena.gd prototypes/core/tests/self_test.gd
git commit -m "Add nance tree and palace arenas with gates and exit ledge (MV-PROTO-003)"
```

---

### Task 4: Boss 主體、召喚、擲果

**Files:**
- Create: `prototypes/core/boss/seven_macaw.gd`、`prototypes/core/boss/moves/move.gd`、`prototypes/core/boss/moves/summon.gd`、`prototypes/core/boss/moves/throw_fruit.gd`、`prototypes/core/boss/fruit.gd`
- Test: `prototypes/core/tests/self_test.gd`（preload `Macaw`、`Fruit`）

**Interfaces:**
- Consumes: Task 2 的 `BreakGauge`、`Light`；Task 3 的 `Nance.CANOPY`、`Palace.HOME`
- Produces:
  - `moves/move.gd`（`extends RefCounted`，所有招式的基底）：`enum Sig { NONE, PARRY, UNPARRY }`；欄位 `boss`、`step := 0`、`t := 0.0`（目前階段經過秒數）、`telegraphing := false`、`attacking := false`、`signal_kind := Sig.NONE`、`body_interruptible := true`；方法 `begin() -> void`、`tick(delta: float) -> bool`（回傳 true＝招式結束）、`interruptible() -> bool`（＝`telegraphing and body_interruptible`）、`on_glow_hit() -> bool`（預設 false；回傳 true＝招式就此結束）、`on_parried() -> void`（預設：`boss.hitbox.stop()`、`attacking = false`）、`cancel() -> void`（預設：停判定、`boss.light.set_state(OFF)`）、`go(s: int) -> void`（設 `step`、`t = 0`）
  - `seven_macaw.gd`（`extends Node2D`；D1）：
    - 訊號：`move_started(name: String)`、`gauge_filled`、`glow_struck(light_name: String)`、`setup_succeeded(phase: int)`、`window_missed`、`interrupted`、`summon_requested(cap: int)`、`flashed`、`intro_finished`
    - `enum State { DOWN, INTRO, GAP, MOVE, INTERRUPTED, BROKEN }`；`const SIZE := Vector2(180, 140)`；`const LIGHT_NAMES := ["jaw", "teeth", "eye"]`；`const LIGHT_OFFSETS := [Vector2(60, -60), Vector2(70, -95), Vector2(50, -120)]`（面向右時相對腳底；面向左時 x 取負）
    - `const MOVES := {"summon": preload(...), "throw_fruit": preload(...)}`（之後的 Task 各自加）
    - 欄位：`tn`、`target: Node2D`、`phase := 1`、`state`、`state_time`、`facing := -1`、`gauge`（BreakGauge）、`light`、`hurtbox`、`hitbox`、`move`、`move_name := ""`、`cycle_index := 0`、`cycle_enabled := true`（false：只由 `start_move` 出招，測試用）、`summons: Array = []`（boss_fight 維護）、`interrupt_cooldown_left := 0.0`、`parryable := false`（每幀開頭依 `move.signal_kind == PARRY` 更新，供 `player._try_parry` 讀）
    - `func begin_phase(p: int, first_move := "") -> void`：`phase = p`、取消招式、`gauge.clear()`、`interrupt_cooldown_left = 0`、位置＝`home(p)`、`face_target()`、光源 OFF 並移到該段位置、`cycle_index`＝first_move 在循環中的 index（找不到為 0）、`state = GAP`、可見、受擊層恢復
    - `func park(p: int) -> void`：同上但 `state = DOWN`（接近場地時停在原位、不出招）
    - `func deactivate(hide := false) -> void`：取消招式、停判定、光源 OFF、`state = DOWN`；hide 時 `visible = false` 並 `hurtbox.set_deferred("collision_layer", 0)`
    - `func play_intro() -> void`：`state = INTRO`：飛到 `Nance.PERCH` → 光源 GLOW `intro_eat_time` 秒 → 光源 OFF、飛回 `Nance.CANOPY` → `state = DOWN`、發 `intro_finished`
    - `func start_move(name: String) -> bool`：不在 `MOVES` 回傳 false；否則取消目前招式、建立新招式、`move_name = name`、`face_target()`、`state = MOVE`、發 `move_started`
    - `static func next_in_cycle(cycle: PackedStringArray, index: int, has_summons: bool, known: Dictionary) -> Array`：從 `index % size` 開始最多看一圈，跳過不在 `known` 的名稱與「`has_summons` 時的 summon」，回傳 `[名稱, 下一個 index]`；一圈都跳過或循環為空回傳 `["", index]`（D6）
    - `func add_gauge(amount: int) -> void`：`gauge.add(amount, tn.gauge_max)` 回傳 true → `_break()`
    - `func parried() -> void`：`move` 存在、`move.attacking` 且 `signal_kind == PARRY` → `move.on_parried()`、`add_gauge(tn.gauge_parry)`
    - `func fly_to(to: Vector2, speed: float, delta: float) -> bool`（`position.move_toward`，距離 < 4 回傳 true）
    - `func face_target() -> void`（依 target 的 x 設 `facing`，同 x 不變；更新光源位置）
    - `func cycle() -> PackedStringArray`（依 phase 回傳 `tn.phaseN_cycle`）、`func summon_cap() -> int`（phase 1 → `summon_cap_p1`，其他 → `summon_cap_p3`）、`func home(p: int) -> Vector2`（1 → `Nance.CANOPY`，其他 → `Palace.HOME`）、`func configure_body_hitbox() -> void`（`SIZE * 1.1`、中心在身體中央）
  - 狀態行為：`GAP` 經過 `boss_move_gap` 且 `cycle_enabled` → `next_in_cycle` → 有名稱就 `start_move`，沒有就重新計時；`MOVE` 每幀 `move.tick`，結束 → `GAP`；`INTERRUPTED` 經過 `boss_interrupt_stagger` → `GAP`；`BROKEN` 經過 `boss_stagger_time` → `gauge.miss(tn.gauge_miss_reset)`、光源 OFF、發 `window_missed`、`GAP`
  - `_break()`：取消招式、`state = BROKEN`、光源 BRIGHT、發 `gauge_filled`
  - 受擊（`hurtbox` 在 `ENEMY_HURT`）：`BROKEN`／`DOWN`／`INTRO` 中只閃白；近戰且 amount > 0 → `add_gauge(gauge_melee)`；吹箭且 `move.interruptible()` 且冷卻 0 → 取消招式、`state = INTERRUPTED`、冷卻＝`tn.dart_interrupt_cooldown`、發 `interrupted`、`add_gauge(gauge_dart_interrupt)`。Boss 沒有血量
  - 光源受擊：`Light.effect(light.state, source.get("can_setup") == true)`：`GLOW_HIT` 只在 `state == MOVE` 處理（其他狀態忽略）→ `move.on_glow_hit()` 為 true 時 `move.cancel()`、結束招式（→ `GAP`）；`add_gauge(gauge_glow_hit)`；發 `glow_struck(LIGHT_NAMES[phase - 1])`。`SETUP`（只會在 BROKEN）→ `deactivate()`、發 `setup_succeeded(phase)`
  - 每幀 `hitbox.collect()` → `receive(1, self, &"enemy")`
  - 繪圖：身體方塊（珠寶金，段數越後越暗）、眼睛＝面向；`move.telegraphing` 時輪廓亮起，`signal_kind` 為 PARRY／UNPARRY 時頭上畫白色圓形／暗紫鋸齒（複製 `enemy._draw_signal` 的畫法，加 `ponytail: yagni: 複製 enemy.gd 的訊號繪圖 | upgrade if: 第三個使用者出現時抽成共用`）；`BROKEN` 時身上畫 5 道白色裂紋折線；`INTERRUPTED` 時半透明藍
  - `summon.gd`：`body_interruptible = false`；前搖 `summon_telegraph`（`signal_kind = NONE`，只亮輪廓）→ 發 `boss.summon_requested(boss.summon_cap())` → 結束
  - `throw_fruit.gd`：飛到 `Nance.CANOPY`（`boss_fly_speed`）→ 前搖 `throw_telegraph`（PARRY）→ 在 `boss.position + Vector2(facing * 70, -80)` 產生 `Fruit`，朝 `target.global_position + Vector2(0, -90)` → 結束
  - `fruit.gd`（`extends Node2D`）：欄位 `tn`、`boss`、`direction`、`ground_y := 900.0`、`parryable := true`、`move_name := "throw_fruit"`；自帶 `Hitbox`（40×40，mask `PLAYER_HURT`，`_ready` 設定，第 3 個物理幀才 `start()`）；每幀直線前進 `fruit_speed`，命中 → `receive(1, self, &"enemy")` 後消失；到地面或飛超過 2400 px 消失；`func parried() -> void`：`boss.add_gauge(tn.gauge_parry)`（boss 仍有效時）、碎掉消失；畫橘黃色圓

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 4：Boss 主體、召喚、擲果 ----

## Boss 單元測試：第 phase 段的場地＋角色（Boss 起始位置左邊 500 px、面向右、站在地上）＋Boss（不自動出招）
func boss_setup(phase: int) -> Array:
	var w := Node2D.new()
	add_child(w)
	w.add_child(Nance.new() if phase == 1 else Palace.new())
	var home: Vector2 = Nance.CANOPY if phase == 1 else Palace.HOME
	var p := Player.new()
	p.tn = fresh_tuning()
	p.scripted = true
	p.position = Vector2(home.x - 500.0, Nance.GROUND_Y)
	w.add_child(p)
	var b = Macaw.new()
	b.tn = p.tn
	b.target = p
	b.cycle_enabled = false
	w.add_child(b)
	b.begin_phase(phase)
	await frames(3)
	return [w, p, b]


func count_of(w: Node, scr) -> int:
	var n := 0
	for c in w.get_children():
		if is_instance_of(c, scr):
			n += 1
	return n


## 只當飛鏢來源用（不加進場景）
func fake_dart(can_setup: bool) -> Node:
	var d := Dart.new()
	d.can_setup = can_setup
	return d


func test_cycle_next_rules() -> void:
	var known := {"summon": 1, "a": 1, "b": 1}
	var c := PackedStringArray(["summon", "a", "b"])
	check(Macaw.next_in_cycle(c, 0, false, known) == ["summon", 1], "沒有造物時照順序出召喚")
	check(Macaw.next_in_cycle(c, 0, true, known) == ["a", 2], "場上有造物時跳過召喚")
	check(Macaw.next_in_cycle(c, 2, true, known) == ["b", 0], "到尾回到開頭")
	check(Macaw.next_in_cycle(PackedStringArray(["typo", "a"]), 0, false, known) == ["a", 0], "未知名稱跳過")
	check(Macaw.next_in_cycle(PackedStringArray(["typo"]), 0, false, known)[0] == "", "整圈都出不了招回傳空字串")
	check(Macaw.next_in_cycle(PackedStringArray(), 0, false, known)[0] == "", "空循環回傳空字串")


func test_boss_cycle_runs_in_order() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var names := []
	b.move_started.connect(func(n): names.append(n))
	b.cycle_enabled = true
	b.begin_phase(1)
	await frames(150)
	check(names.size() >= 2 and names[0] == "summon" and names[1] == "throw_fruit", "第 1 段依循環先召喚再擲果，實際 %s" % [names])
	await free_world(s[0])


func test_boss_phase_home_and_light_position() -> void:
	var s: Array = await boss_setup(2)
	var b = s[2]
	check(b.position.is_equal_approx(Palace.HOME), "第 2 段從宮殿的起始位置開始")
	check(b.facing == -1, "面向角色（在左邊）")
	check(b.light.position.is_equal_approx(Macaw.LIGHT_OFFSETS[1] * Vector2(-1, 1)), "光源在玉牙的位置，實際 %s" % b.light.position)
	check(b.light.state == Light.State.OFF, "換段後光源熄滅")
	await free_world(s[0])


func test_boss_gauge_from_melee_only_when_damaging() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	b.hurtbox.receive(4, s[1], &"melee")
	check(b.gauge.value == 8, "近戰命中 +8，實際 %d" % b.gauge.value)
	b.hurtbox.receive(0, s[1], &"melee")
	check(b.gauge.value == 8, "傷害 0 的近戰不累積")
	b.hurtbox.receive(1, null, &"dart")
	check(b.gauge.value == 8, "不在前搖時射中身體不累積")
	check(b.phase == 1, "近戰與吹箭不會打掉血條")
	await free_world(s[0])


func test_boss_break_stagger_and_miss() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var got := []
	b.gauge_filled.connect(func(): got.append("full"))
	b.window_missed.connect(func(): got.append("miss"))
	b.add_gauge(100)
	check(b.state == Macaw.State.BROKEN and b.light.state == Light.State.BRIGHT, "滿了 → 硬直、光源最亮")
	b.hurtbox.receive(4, s[1], &"melee")
	check(b.gauge.value == 100, "硬直中命中不累積")
	await frames(228)
	check(b.state == Macaw.State.BROKEN, "硬直應持續 4 秒")
	await frames(20)
	check(b.state != Macaw.State.BROKEN and b.gauge.value == 50 and b.light.state == Light.State.OFF, "錯過 → 破綻 50、熄滅、恢復行動")
	check(got == ["full", "miss"], "訊號順序，實際 %s" % [got])
	await free_world(s[0])


func test_boss_setup_only_by_setup_dart_on_bright() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var got := []
	b.setup_succeeded.connect(func(ph): got.append(ph))
	var x := fake_dart(false)
	var h := fake_dart(true)
	b.light.receive(1, h, &"dart")
	check(got.is_empty(), "熄滅時射中沒有效果")
	b.add_gauge(100)
	b.light.receive(1, x, &"dart")
	check(got.is_empty() and b.state == Macaw.State.BROKEN, "最亮時 Xbalanque 的箭沒有效果")
	b.light.receive(1, h, &"dart")
	check(got == [1] and b.state == Macaw.State.DOWN, "最亮時 Hunahpu 的箭 → 設局成功、Boss 停止行動")
	x.free()
	h.free()
	await free_world(s[0])


func test_boss_summon_cap_and_not_interruptible() -> void:
	var caps := []
	for ph in [1, 3]:
		var s: Array = await boss_setup(ph)
		var b = s[2]
		b.summon_requested.connect(func(cap): caps.append(cap))
		b.start_move("summon")
		await frames(5)
		b.hurtbox.receive(1, null, &"dart")
		check(b.state == Macaw.State.MOVE, "召喚的前搖不能用射身體打斷")
		await wait_until(func(): return caps.size() == (1 if ph == 1 else 2), 60)
		await free_world(s[0])
	check(caps == [1, 2], "召喚上限：第 1 段 1、第 3 段 2，實際 %s" % [caps])


func test_throw_fruit_interrupt_and_cooldown() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	b.start_move("throw_fruit")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	b.hurtbox.receive(1, null, &"dart")
	check(b.state == Macaw.State.INTERRUPTED and b.gauge.value == 10, "前搖中射中身體 → 打斷、破綻 +10")
	await frames(45)
	check(count_of(s[0], Fruit) == 0, "被打斷就不擲果")
	check(b.state == Macaw.State.GAP, "0.6 秒後恢復")
	b.start_move("throw_fruit")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	b.hurtbox.receive(1, null, &"dart")
	check(b.state == Macaw.State.MOVE and b.gauge.value == 10, "3 秒冷卻內再射中不打斷")
	await free_world(s[0])


func test_throw_fruit_parried_shatters() -> void:
	var s: Array = await boss_setup(1)
	var p = s[1]
	var b = s[2]
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	b.start_move("throw_fruit")
	var fruit = null
	for i in 120:
		for c in s[0].get_children():
			if c is Fruit:
				fruit = c
		if fruit != null:
			break
		await frames(1)
	check(fruit != null, "前搖結束應擲出果子")
	await wait_until(func(): return not is_instance_valid(fruit) or fruit.global_position.distance_to(p.global_position + Vector2(0, -90)) < 200.0, 120)
	p.intent.attack_pressed = true
	var gone: bool = await wait_until(func(): return not is_instance_valid(fruit), 30)
	check(gone and p.health.hp == 5, "招架成功：果子碎掉、不受傷")
	check(b.gauge.value == 15, "擋下果子破綻 +15，實際 %d" % b.gauge.value)
	check(p.parry_stats.minute_rows()[0].successes == 1, "記一筆招架成功")
	await free_world(s[0])
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作** `move.gd`、`seven_macaw.gd`、`summon.gd`、`throw_fruit.gd`、`fruit.gd`（照 Interfaces）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/seven_macaw.gd prototypes/core/boss/moves/move.gd prototypes/core/boss/moves/summon.gd prototypes/core/boss/moves/throw_fruit.gd prototypes/core/boss/fruit.gd prototypes/core/tests/self_test.gd
git commit -m "Add Seven Macaw core with cycle, break gauge, lights, summon and fruit throw (MV-PROTO-003)"
```

---

### Task 5: 第 1 段其餘招式與白茫

**Files:**
- Create: `prototypes/core/boss/moves/eat_fruit.gd`、`prototypes/core/boss/moves/dive.gd`、`prototypes/core/boss/moves/false_flash.gd`、`prototypes/core/ui/whiteout.gd`
- Modify: `prototypes/core/boss/seven_macaw.gd`（`MOVES` 加三招）
- Test: `prototypes/core/tests/self_test.gd`（preload `FalseFlash`、`Whiteout`）

**Interfaces:**
- Consumes: Task 4 的 `move.gd`、`boss.fly_to`、`boss.light`、`boss.configure_body_hitbox()`
- Produces:
  - `eat_fruit.gd`：飛到 `Nance.PERCH` → 光源 GLOW、停 `eat_time` 秒 → 光源 OFF、結束；`on_glow_hit()` 回傳 true（中斷；下一招的移動會飛回樹冠）
  - `dive.gd`：飛到 `Nance.CANOPY` → 前搖 `dive_telegraph`（UNPARRY），**前搖開始時**記下 `aim = target.global_position`、`configure_body_hitbox()` → 以 `dive_speed` 直線衝向 `aim`（`attacking`、判定啟用），到達或 y ≥ `GROUND_Y` 時停在地面 → 停判定、喘 `dive_rest` 秒 → 結束
  - `false_flash.gd`：`body_interruptible = false`；飛到 `Nance.CANOPY` → 前搖 `flash_telegraph`（`signal_kind = NONE`；Boss 畫展翅與全身聚光：身體兩側各 6 道金色光線，前搖越後越長）→ 發 `boss.flashed` → 結束；`static func is_facing(player_x: float, player_facing: int, boss_x: float) -> bool`（同 x 視為面向）
  - `whiteout.gd`（`extends Control`，全螢幕）：`const MAX_ALPHA := 0.9`、`var tn`、`var t := -1.0`（< 0＝沒有白茫）、`func start() -> void`、`func stop() -> void`、`func is_active() -> bool`、`static func alpha_at(s: float, tn) -> float`（0～in 線性升到 MAX、hold 維持、out 線性降到 0、之後 0；不閃爍）；`_process` 推進 `t`、畫白色全螢幕矩形

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 5：第 1 段其餘招式與白茫 ----

func test_eat_fruit_on_branch_with_jaw_glow() -> void:
	var s: Array = await boss_setup(1)
	var b = s[2]
	var names := []
	b.glow_struck.connect(func(n): names.append(n))
	b.start_move("eat_fruit")
	var lit: bool = await wait_until(func(): return b.light.state == Light.State.GLOW, 90)
	check(lit and b.position.distance_to(Nance.PERCH) < 4.0, "吃果子停在低枝、下顎微亮，實際 %s" % b.position)
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")
	check(b.move == null and b.light.state == Light.State.OFF, "微亮被射中 → 中斷、熄滅")
	check(b.gauge.value == 12 and names == ["jaw"], "微亮命中破綻 +12、記下顎")
	x.free()
	b.start_move("eat_fruit")
	await wait_until(func(): return b.light.state == Light.State.GLOW, 90)
	await frames(140)
	check(b.move != null, "吃果子持續 2.5 秒")
	await frames(15)
	check(b.move == null and b.light.state == Light.State.OFF, "2.5 秒後吃完")
	await free_world(s[0])


func test_dive_lands_at_telegraph_position() -> void:
	var s: Array = await boss_setup(1)
	var p = s[1]
	var b = s[2]
	b.start_move("dive")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	var aim: Vector2 = p.global_position
	p.position.x -= 400.0
	var landed: bool = await wait_until(func(): return b.position.y >= Nance.GROUND_Y - 1.0, 120)
	check(landed and absf(b.position.x - aim.x) < 40.0, "俯衝落在前搖開始時的角色位置，實際 %s／%s" % [b.position, aim])
	await frames(60)
	check(b.move != null and b.move_name == "dive", "落地喘 1.2 秒")
	await frames(20)
	check(b.move == null, "喘完結束")
	await free_world(s[0])


func test_false_flash_facing_rule_and_not_interruptible() -> void:
	check(FalseFlash.is_facing(100.0, 1, 500.0), "Boss 在右、角色面右 → 面向")
	check(not FalseFlash.is_facing(100.0, -1, 500.0), "背對 → 沒事")
	check(FalseFlash.is_facing(500.0, -1, 500.0), "同 x 視為面向")
	var s: Array = await boss_setup(1)
	var b = s[2]
	var flashed := []
	b.flashed.connect(func(): flashed.append(true))
	b.start_move("false_flash")
	await frames(10)
	b.hurtbox.receive(1, null, &"dart")
	check(b.state == Macaw.State.MOVE, "假光閃耀不能用射身體打斷")
	await wait_until(func(): return not flashed.is_empty(), 70)
	check(flashed.size() == 1, "前搖 1 秒後閃光")
	await free_world(s[0])


func test_whiteout_curve() -> void:
	var t := fresh_tuning()
	check(is_zero_approx(Whiteout.alpha_at(0.0, t)), "開始時 0")
	check(is_equal_approx(Whiteout.alpha_at(0.3, t), Whiteout.MAX_ALPHA) and is_equal_approx(Whiteout.alpha_at(1.7, t), Whiteout.MAX_ALPHA), "0.3～1.7 秒維持")
	check(is_zero_approx(Whiteout.alpha_at(2.0, t)) and is_zero_approx(Whiteout.alpha_at(2.5, t)), "2 秒後消失")
	var prev := -1.0
	for i in 31:
		var a := Whiteout.alpha_at(i * 0.01, t)
		check(a >= prev, "淡入單調遞增（%.2f 秒）" % (i * 0.01))
		prev = a
	prev = 2.0
	for i in 31:
		var a := Whiteout.alpha_at(1.7 + i * 0.01, t)
		check(a <= prev, "淡出單調遞減（%.2f 秒）" % (1.7 + i * 0.01))
		prev = a
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**四個檔案並在 `MOVES` 登記 `eat_fruit`、`dive`、`false_flash`
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/moves/eat_fruit.gd prototypes/core/boss/moves/dive.gd prototypes/core/boss/moves/false_flash.gd prototypes/core/ui/whiteout.gd prototypes/core/boss/seven_macaw.gd prototypes/core/tests/self_test.gd
git commit -m "Add eat fruit, dive and false flash moves with whiteout overlay (MV-PROTO-003)"
```

---

### Task 6: 第 2 段招式與反光柱

**Files:**
- Create: `prototypes/core/boss/moves/flail.gd`、`prototypes/core/boss/moves/wail.gd`、`prototypes/core/boss/moves/throne_charge.gd`、`prototypes/core/boss/pillar.gd`
- Modify: `prototypes/core/boss/seven_macaw.gd`（`MOVES` 加三招）
- Test: `prototypes/core/tests/self_test.gd`（preload `Pillar`）

**Interfaces:**
- Consumes: Task 3 的 `Palace.THRONE_X`、`Palace.pillar_xs`；Task 4 的 move 基底
- Produces:
  - `flail.gd`：朝角色走（`boss_walk_speed`），水平距離 ≤ 150 或走滿 `boss_chase_max` 秒就停 → 前搖 `flail_telegraph`（PARRY），前搖開始時 `hitbox.configure(tn.flail_box, Vector2(0, -SIZE.y / 2), PLAYER_HURT)` → 判定 `flail_active` 秒 → 結束；被招架 → 停判定、結束（D4）
  - `wail.gd`：原地，光源 GLOW `wail_time` 秒 → OFF、結束；`on_glow_hit()` 回傳 true
  - `throne_charge.gd`：走到 `x = max(target.x − 350, Palace.LEFT + 10)`（每幀重算目標，到達才進前搖）→ 前搖 `charge_telegraph`（UNPARRY，可被射身體打斷），`configure_body_hitbox()`、面向寶座 → 以 `charge_speed` 衝到 `Palace.THRONE_X`（判定啟用）→ 停判定，對 `Palace.pillar_xs(tn.pillar_count, target.global_position.x)` 每個 x 產生 `Pillar` → 等 `pillar_warn + pillar_active` 秒 → 結束
  - `pillar.gd`（`extends Node2D`，原點在地面）：`tn`、`parryable := false`、`move_name := "pillars"`、`var t := 0.0`；`Hitbox` 120×960、中心 (0, −480)，`_ready` 設定；`t >= pillar_warn` 時 `start()`，`t >= pillar_warn + pillar_active` 時消失；每幀 `collect()` → `receive(1, self, &"enemy")`；繪圖：預告期地面一個亮白光點＋細線，啟用期整根亮白光柱

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 6：第 2 段招式與反光柱 ----

func test_flail_approaches_and_can_be_parried() -> void:
	var s: Array = await boss_setup(2)
	var p = s[1]
	var b = s[2]
	var t = p.tn
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	b.start_move("flail")
	var ready: bool = await wait_until(func(): return b.move != null and b.move.telegraphing and b.move.t >= t.flail_telegraph - 0.1, 120)
	check(ready and absf(b.position.x - p.position.x) <= 151.0, "先走到角色身邊再前搖，實際距離 %.0f" % absf(b.position.x - p.position.x))
	check(b.parryable, "亂揮翅膀可招架")
	p.intent.attack_pressed = true
	var ok: bool = await wait_until(func(): return b.gauge.value == 15, 30)
	check(ok and p.health.hp == 5, "招架成功：破綻 +15、不受傷")
	await free_world(s[0])


func test_wail_teeth_glow() -> void:
	var s: Array = await boss_setup(2)
	var b = s[2]
	var names := []
	b.glow_struck.connect(func(n): names.append(n))
	b.start_move("wail")
	await frames(2)
	check(b.light.state == Light.State.GLOW, "哀嚎時玉牙微亮")
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")
	check(b.move == null and names == ["teeth"], "微亮被射中 → 中斷、記玉牙")
	x.free()
	await free_world(s[0])


func test_throne_charge_puts_player_between_and_drops_pillars() -> void:
	var s: Array = await boss_setup(2)
	var p = s[1]
	var b = s[2]
	p.position.x = Palace.LEFT + 900.0
	await frames(2)
	b.start_move("throne_charge")
	var ready: bool = await wait_until(func(): return b.move != null and b.move.telegraphing, 150)
	check(ready and b.position.x < p.position.x and p.position.x < Palace.THRONE_X, "前搖時角色在他與寶座之間，實際 Boss %.0f、角色 %.0f" % [b.position.x, p.position.x])
	check(not b.parryable, "撞寶座不可招架")
	var hit: bool = await wait_until(func(): return b.position.x >= Palace.THRONE_X - 1.0, 120)
	var px: float = p.position.x
	await frames(2)
	var xs := []
	for c in s[0].get_children():
		if c is Pillar:
			xs.append(c.position.x)
	check(hit and xs.size() == 3, "撞上寶座後落 3 道反光柱，實際 %s" % [xs])
	var near_player := false
	for x in xs:
		near_player = near_player or absf(x - px) < 30.0
	check(near_player, "其中一道落在角色當時的位置")
	await free_world(s[0])


func test_pillar_warns_then_hits_once() -> void:
	var w := make_world()
	var p = await make_player(w)
	var pl = Pillar.new()
	pl.tn = p.tn
	pl.position = Vector2(0, 0)
	w.add_child(pl)
	await frames(45)
	check(p.health.hp == 5, "預告 0.8 秒內不傷人")
	await frames(30)
	check(p.health.hp == 4, "光柱落下扣 1 血，實際 %d" % p.health.hp)
	await frames(10)
	check(not is_instance_valid(pl), "0.4 秒後消失")
	await free_world(w)
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**四個檔案並登記 `flail`、`wail`、`throne_charge`
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/moves/flail.gd prototypes/core/boss/moves/wail.gd prototypes/core/boss/moves/throne_charge.gd prototypes/core/boss/pillar.gd prototypes/core/boss/seven_macaw.gd prototypes/core/tests/self_test.gd
git commit -m "Add flail, wail and throne charge with reflected light pillars (MV-PROTO-003)"
```

---

### Task 7: 第 3 段招式

**Files:**
- Create: `prototypes/core/boss/moves/stagger_pounce.gd`、`prototypes/core/boss/moves/beam.gd`
- Modify: `prototypes/core/boss/seven_macaw.gd`（`MOVES` 加兩招）
- Test: `prototypes/core/tests/self_test.gd`（preload `Beam`）

**Interfaces:**
- Consumes: Task 4 的 move 基底；`Palace.LEFT`／`RIGHT`
- Produces:
  - `stagger_pounce.gd`：前搖 `pounce_telegraph`（PARRY，可被射身體打斷），前搖開始時記 `aim_x = target.x`、`configure_body_hitbox()` → 沿地面以 `pounce_speed` 衝向 `aim_x`（判定啟用），到達（±20）或走滿 `pounce_max` 停 → 停判定、不穩 `pounce_rest` 秒 → 結束；被招架 → 停判定、直接進入不穩
  - `beam.gd`：`enum Step { CHARGE, FIRE, WOBBLE }`；`body_interruptible = false`；CHARGE：面向角色、光源 GLOW、`signal_kind = UNPARRY`、`telegraphing`、設定光束判定（D17：長度＝Boss 前緣到面向那側的 `Palace.LEFT`／`RIGHT`，高度帶 `beam_band`，中心 y＝−(band.x+band.y)/2）`beam_charge` 秒 → FIRE：光源 OFF、判定啟用 `beam_active` 秒（畫一條亮白水平光帶）→ 結束；`on_glow_hit()`（只在 CHARGE）→ 光源 OFF、進 WOBBLE `beam_wobble` 秒（晃動、近戰空檔）→ 結束，回傳 false

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 7：第 3 段招式 ----

func test_stagger_pounce_parry_then_unsteady() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	p.set_weapon(Weapons.Weapon.BALLGEAR)
	b.start_move("stagger_pounce")
	await wait_until(func(): return b.move != null and b.move.telegraphing, 30)
	check(b.parryable, "失衡撲擊可招架")
	await wait_until(func(): return b.move.attacking, 60)
	await wait_until(func(): return absf(b.position.x - p.position.x) < 250.0, 60)
	p.intent.attack_pressed = true
	var ok: bool = await wait_until(func(): return b.gauge.value == 15, 30)
	check(ok and p.health.hp == 5, "招架成功：破綻 +15、不受傷")
	await frames(50)
	check(b.move_name == "stagger_pounce" and b.move != null and not b.move.attacking, "被擋下後落地不穩（近戰空檔）")
	await free_world(s[0])


func test_beam_eye_glow_interrupt_wobbles() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	var names := []
	b.glow_struck.connect(func(n): names.append(n))
	b.start_move("beam")
	await frames(5)
	check(b.light.state == Light.State.GLOW and not b.parryable, "蓄力時眼睛微亮、不可招架")
	b.hurtbox.receive(1, null, &"dart")
	check(b.move != null and b.move.step == Beam.Step.CHARGE, "光束不能用射身體打斷")
	var x := fake_dart(false)
	b.light.receive(1, x, &"dart")
	x.free()
	check(b.move.step == Beam.Step.WOBBLE and names == ["eye"], "射中微亮 → 打斷、晃動")
	await frames(55)
	check(b.move != null, "晃 1.0 秒")
	await frames(10)
	check(b.move == null and p.health.hp == 5, "晃完結束、光束沒有射出")
	await free_world(s[0])


func test_beam_hits_standing_player() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	b.start_move("beam")
	await frames(110)
	check(p.health.hp == 4, "沒打斷 → 光束打中站著的角色，實際 %d" % p.health.hp)
	await free_world(s[0])


func test_beam_single_jump_clears() -> void:
	var s: Array = await boss_setup(3)
	var p = s[1]
	var b = s[2]
	var t = p.tn
	b.start_move("beam")
	await wait_until(func(): return b.move != null and b.move.step == Beam.Step.CHARGE and b.move.t >= t.beam_charge - 0.1, 90)
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await frames(50)
	check(p.health.hp == 5, "單跳跳得過光束，實際 %d" % p.health.hp)
	await free_world(s[0])
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**兩個檔案並登記 `stagger_pounce`、`beam`
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/moves/stagger_pounce.gd prototypes/core/boss/moves/beam.gd prototypes/core/boss/seven_macaw.gd prototypes/core/tests/self_test.gd
git commit -m "Add stagger pounce and eye beam moves (MV-PROTO-003)"
```

---

### Task 8: 測試日誌

**Files:**
- Create: `prototypes/core/boss/fight_log.gd`
- Test: `prototypes/core/tests/self_test.gd`（preload `FightLog`）

**Interfaces:**
- Produces（`extends RefCounted`）：
  - `const STALL_SECONDS := 60.0`、`const PROGRESS := ["gauge_full", "glow_hit", "setup"]`
  - 欄位：`events: Array`（每筆 `{"t": float, "type": String, …}`）、`tester`、`stamp`、`keep_phase := false`、`path_base`（不含副檔名）、`closed := false`
  - `func open(p_tester: String, p_stamp: String, dir: String) -> Error`：`DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))`，開 `<dir>/<tester>_<stamp>.jsonl` 寫入
  - `func add(t: float, type: String, data := {}) -> void`：組成事件、加進 `events`、`store_line(JSON.stringify(ev))`、`flush()`；`closed` 後忽略
  - `func close(t: float, end_type: String) -> void`：只做一次；`add(t, end_type)`（`"clear"` 或 `"quit"`）、關檔、寫 `<path_base>.md`（`summary_markdown(t)`）
  - `static func summarize(evs: Array, end_t: float) -> Dictionary`：`attempts`（死亡數＋1）、`deaths`、`cleared`（有 `clear`）、`phase_attempts: Array`（三段各幾次 `attempt_start`）、`phase_time: Array`（D7）、`stalls: Array`（每筆 `{"from", "to", "phase"}`；以「第一筆事件時間、各 PROGRESS 事件時間、end_t」排序後相鄰差 > 60 秒的區間；段＝`t < to` 的最後一筆帶 `phase` 事件的段）、`counts: Dictionary`（各事件類型次數）
  - `func summary_markdown(end_t: float) -> String`：標題「Boss 戰測試日誌摘要：<tester>」、開始時間、段落保留開／關、結果（通關／中途離開）、總嘗試次數（死亡幾次）、各段表（段｜嘗試｜累計時間秒，一位小數）、「超過 60 秒沒有進展」表（沒有寫「（無）」）、事件次數表
  - `static func stamp_from(dt: Dictionary) -> String`（`YYYYMMDD_HHMMSS`）
  - `static func safe_name(code: String) -> String`：空白與 `/\:*?"<>|` 換成 `_`；去頭尾空白後為空回傳 `anon`

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 8：測試日誌 ----

const TEST_LOG_DIR := "user://selftest_boss_logs"


func remove_test_logs() -> void:
	var path := ProjectSettings.globalize_path(TEST_LOG_DIR)
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


func test_log_summary_math() -> void:
	var ev := [
		{"t": 0.0, "type": "attempt_start", "phase": 1, "keep": false},
		{"t": 30.0, "type": "glow_hit", "phase": 1, "light": "jaw"},
		{"t": 100.0, "type": "death", "phase": 1, "by": "dive"},
		{"t": 110.0, "type": "attempt_start", "phase": 1, "keep": false},
		{"t": 150.0, "type": "gauge_full", "phase": 1},
		{"t": 152.0, "type": "setup", "phase": 1},
		{"t": 200.0, "type": "attempt_start", "phase": 2, "keep": false},
		{"t": 330.0, "type": "quit"},
	]
	var s := FightLog.summarize(ev, 330.0)
	check(s.attempts == 2 and s.deaths == 1 and not s.cleared, "總嘗試 2（死 1 次）、未通關，實際 %s" % [s])
	check(s.phase_attempts == [2, 1, 0], "各段嘗試次數，實際 %s" % [s.phase_attempts])
	check(is_equal_approx(s.phase_time[0], 142.0) and is_equal_approx(s.phase_time[1], 130.0) and is_zero_approx(s.phase_time[2]), "各段時間 142／130／0，實際 %s" % [s.phase_time])
	check(s.stalls == [{"from": 30.0, "to": 150.0, "phase": 1}, {"from": 152.0, "to": 330.0, "phase": 2}], "超過 60 秒沒進展的區間，實際 %s" % [s.stalls])
	check(s.counts.get("glow_hit", 0) == 1 and s.counts.get("attempt_start", 0) == 3, "事件次數")


func test_log_stamp() -> void:
	check(FightLog.stamp_from({"year": 2026, "month": 10, "day": 5, "hour": 9, "minute": 3, "second": 7}) == "20261005_090307", "時間戳格式")


func test_log_safe_name() -> void:
	check(FightLog.safe_name("A01") == "A01", "一般代號不變")
	check(FightLog.safe_name("a b/c:d") == "a_b_c_d", "空白與路徑字元換成底線")
	check(FightLog.safe_name("  ") == "anon", "空白代號用 anon")


func test_log_writes_jsonl_and_summary_once() -> void:
	var lg = FightLog.new()
	check(lg.open("tester01", "20261005_120000", TEST_LOG_DIR) == OK, "能建立日誌")
	lg.add(0.0, "attempt_start", {"phase": 1, "keep": false})
	lg.add(5.0, "death", {"phase": 1, "by": "dive"})
	lg.close(9.0, "quit")
	lg.close(10.0, "quit")
	var lines := FileAccess.get_file_as_string(TEST_LOG_DIR + "/tester01_20261005_120000.jsonl").strip_edges().split("\n")
	check(lines.size() == 3, "3 筆事件（含 quit 一次），實際 %d" % lines.size())
	var last = JSON.parse_string(lines[2])
	check(last != null and last.type == "quit", "最後一筆是 quit")
	var md := FileAccess.get_file_as_string(TEST_LOG_DIR + "/tester01_20261005_120000.md")
	check(md.contains("總嘗試次數：2") and md.contains("中途離開"), "摘要寫出嘗試次數與結果")
	remove_test_logs()
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作** `fight_log.gd`
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/fight_log.gd prototypes/core/tests/self_test.gd
git commit -m "Add boss fight test log with pure summary (MV-PROTO-003)"
```

---

### Task 9: 文字卡、開頭選單、HUD

**Files:**
- Create: `prototypes/core/ui/text_card.gd`、`prototypes/core/ui/start_menu.gd`、`prototypes/core/boss/card_text.gd`
- Modify: `prototypes/core/ui/hud.gd`、`prototypes/core/player/twin.gd`
- Test: `prototypes/core/tests/self_test.gd`（preload `TextCard`、`StartMenu`、`CardText`）

**Interfaces:**
- Produces:
  - `twin.gd`：`display_name` 改為 `"胡納普"`、`"希巴拉克"`（MV-NAME-001 H01、H02）；`test_hud_twin_lines` 的預期值改成 `lines[0].contains("胡納普")`、`lines[1].contains("希巴拉克")`
  - `card_text.gd`（`extends RefCounted`；D10）：`const BOSS_NAME := "七金剛鸚鵡"`；`const CARDS := {"arm": …, "couple": …, "toothache": …, "teeth": …, "death": …, "awaken": …, "clear": …}`，內容照下表（固定文字，逐字使用）
  - `text_card.gd`（`extends Control`，全螢幕，初始隱藏）：`signal closed`、`var min_time := 0.5`、`var shown_time := 0.0`、`var text := ""`；`func show_card(s: String) -> void`；`func confirm() -> void`（顯示中且 `shown_time >= min_time` 才關閉並發 `closed`）；`_process`：顯示中累加時間，`Input.is_action_just_pressed("attack")` 時 `confirm()`；繪圖：全螢幕暗底（alpha 0.92）、置中多行文字（字級 34、寬 1200）、下方「攻擊鍵繼續」
  - `start_menu.gd`（`extends Control`）：`signal chosen(mode: String, keep_phase: bool)`、`var index := 0`、`var keep_phase := false`；`func labels() -> PackedStringArray`（`["練習房", "Boss 戰", "Boss 段落保留：關"]`，開時「開」）；`func move(dir: int) -> void`（夾在 0～2）；`func confirm() -> void`（0 → `chosen("room", keep_phase)`、1 → `chosen("boss", keep_phase)`、2 → 切換 `keep_phase`）；`_process`：`look_up`／`look_down` just_pressed 移動、`attack` just_pressed 確認；繪圖：標題「核心原型」、三行選項（選中的亮色加 ▶）、下方「上下選擇　攻擊鍵確認」；不提任何設局線索
  - `hud.gd`：`var show_hint := true`（false 時不畫底部除錯鍵提示）；`var boss_name := ""`（空字串＝不畫 Boss 區）、`var boss_segments := 3`、`var boss_gauge := 0.0`（0～1）；Boss 區畫在上方中央：名稱、三格血條（剩下的亮金、打掉的暗灰）、下方破綻條（滿時白色）；`twin_lines()` 中 `weapon_enabled` 為 false 的人武器欄顯示「—」（D20）

文字卡內容（只寫原典有的事，Christenson p.82～86；名稱依 MV-NAME-001）：

| 鍵 | 文字 |
|---|---|
| `arm` | 七金剛鸚鵡大叫一聲，從樹頂摔落地面。<br>胡納普衝上前去抓他，卻被他扯下了手臂。<br><br>他捧著下顎回到家中，把手臂掛在火上。<br>奇瑪瑪特問：「你帶了什麼回來？」<br>「兩個騙子射了我。這條手臂就掛在這裡，等他們來拿回去。」 |
| `couple` | 兄弟倆去找兩位老人：一位頭髮全白，一位彎著腰。<br>「請陪我們去七金剛鸚鵡那裡，取回我們的手臂。我們跟在後面，就說是你們的孫子。」<br>「好。」兩位老人說。 |
| `toothache` | 七金剛鸚鵡坐在寶座邊上，牙痛得不停哭喊。<br>奇瑪瑪特在寶座旁。<br>他看見老人身後的兩個孩子，猛然站了起來。 |
| `teeth` | 七金剛鸚鵡跪了下來：「可憐可憐我，治好我的牙吧。」<br>老人取出他的牙，換上一粒粒發亮的白玉米。<br>他的臉立刻垮了下來，看起來不再像王。 |
| `death` | 老人又摘去他眼中的貴金屬。他不覺得痛，只是呆呆望著前方。<br>他身上的光一點一點熄滅了。<br><br>七金剛鸚鵡死了。他的妻子奇瑪瑪特也隨之死去。<br>兩位老人帶走了他的珠寶。 |
| `awaken` | 胡納普從火上取回手臂，兄弟倆把它裝回原處，手臂完好如初。<br><br>希巴拉克想起開墾田地的那一天：斧頭自己砍倒了樹。 |
| `clear` | 七金剛鸚鵡的驕傲被拿走了。<br><br>（原型到此結束，謝謝試玩。） |

（表中 `<br>` 在程式裡寫成 `\n`。）

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 9：文字卡、開頭選單、HUD ----

func test_card_ignores_confirm_before_min_time() -> void:
	var c = TextCard.new()
	add_child(c)
	var closed := []
	c.closed.connect(func(): closed.append(true))
	c.show_card(CardText.CARDS["arm"])
	check(c.visible, "顯示文字卡")
	c.confirm()
	check(c.visible and closed.is_empty(), "顯示不到 0.5 秒時不接受確認（避免狂按攻擊直接跳過）")
	await frames(35)
	c.confirm()
	c.confirm()
	check(not c.visible and closed.size() == 1, "0.5 秒後確認關閉，只發一次")
	c.queue_free()
	await frames(1)


func test_card_texts_complete_without_gameplay_hints() -> void:
	for k in ["arm", "couple", "toothache", "teeth", "death", "awaken", "clear"]:
		check(CardText.CARDS.has(k) and not String(CardText.CARDS[k]).is_empty(), "缺文字卡 %s" % k)
	for k in CardText.CARDS:
		for word in ["破綻", "設局", "光源", "微亮", "最亮", "吹箭", "背對", "二段跳", "弱點"]:
			check(not String(CardText.CARDS[k]).contains(word), "文字卡 %s 不應提示玩法（%s）" % [k, word])


func test_start_menu_items_and_toggle() -> void:
	var m = StartMenu.new()
	add_child(m)
	var got := []
	m.chosen.connect(func(mode, keep): got.append([mode, keep]))
	check(m.labels() == PackedStringArray(["練習房", "Boss 戰", "Boss 段落保留：關"]), "兩個選項＋段落保留開關")
	m.move(1)
	m.move(1)
	m.confirm()
	check(m.keep_phase and m.labels()[2] == "Boss 段落保留：開", "切換段落保留")
	m.move(-1)
	m.confirm()
	m.move(-1)
	m.move(-1)
	m.confirm()
	check(got == [["boss", true], ["room", true]], "選 Boss 戰與練習房，實際 %s" % [got])
	m.queue_free()
	await frames(1)


func test_hud_armless_and_boss_fields() -> void:
	var w := make_world()
	var p = await make_player(w)
	var hud = Hud.new()
	hud.player = p
	add_child(hud)
	p.twins[0].weapon_enabled = false
	check(hud.twin_lines()[0] == "胡納普　—", "斷臂時武器欄顯示「—」，實際 %s" % hud.twin_lines()[0])
	hud.boss_name = CardText.BOSS_NAME
	hud.boss_segments = 2
	hud.boss_gauge = 0.5
	hud.show_hint = false
	await frames(2)
	hud.queue_free()
	await free_world(w)
```

（`test_hud_armless_and_boss_fields` 另靠 `SCRIPT ERROR` 計數確認 Boss 區繪圖沒有錯誤。）

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**三個新檔與 `hud.gd` 修改
- [ ] **Step 4: 執行測試確認通過**（含 `test_hud_twin_lines` 等 002 舊測試）
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/ui/text_card.gd prototypes/core/ui/start_menu.gd prototypes/core/boss/card_text.gd prototypes/core/ui/hud.gd prototypes/core/tests/self_test.gd
git commit -m "Add text cards, start menu and boss HUD (MV-PROTO-003)"
```

---

### Task 10: Boss 戰流程（一）：進場、開場、戰鬥中的連動

**Files:**
- Create: `prototypes/core/boss/boss_fight.gd`
- Test: `prototypes/core/tests/self_test.gd`（preload `BossFight`）

**Interfaces:**
- Consumes: Task 1～9 全部
- Produces（`extends Node2D`）：
  - `signal finished`；`enum Stage { APPROACH, INTRO, FIGHT, CARD, EXIT, DONE }`
  - `const BG_LEVELS := [Color(0.34, 0.31, 0.22), Color(0.24, 0.22, 0.17), Color(0.15, 0.14, 0.12), Color(0.08, 0.06, 0.05)]`（每拔掉一個光源暗一階）
  - 設定欄位（`add_child` 前設定）：`tn`（預設 `Tune.data`）、`tester := "anon"`、`keep_phase := false`、`log_dir := "user://boss_logs"`、`player_scripted := false`（true：角色一律由測試或展示模式操控）
  - 執行欄位：`world: Node2D`（場地、角色、Boss、造物、飛鏢都在這裡）、`nance`、`palace`、`player`、`boss`、`camera`、`feedback`、`hud`、`whiteout`、`card`（三者在同一個 `CanvasLayer`，依序疊放）、`log`（FightLog）、`stage`、`phase := 1`、`lights_removed := 0`、`awakened := false`、`intro_seen := false`、`palace_card_seen := false`、`player_locked := false`、`couple_following := false`、`couple_x: float`
  - `_ready`：建 `world`、兩個場地、角色（`Nance.REST`、`scripted = player_scripted`、相機掛在角色上）、Boss（`park(1)`）、回饋（照練習房接角色訊號；Boss 的 `interrupted`、`glow_struck` 播 `interrupt`）、UI（`hud.show_hint = false`）；開日誌（`FightLog.safe_name(tester)`、`stamp_from(Time.get_datetime_dict_from_system())`）並 `print("BOSSLOG %s" % ProjectSettings.globalize_path(log_dir))`；`_apply_loadout()`；`stage = APPROACH`；相機範圍 `Nance.REGION`
  - `_apply_loadout()`：`player.twins[0].weapon_enabled = phase == 1 or awakened`、`player.abilities_enabled = awakened`
  - `func now() -> float`（開戰後秒數）、`func arena(p := phase) -> Node`（1 → nance，其他 → palace）
  - `func background_color() -> Color`（`BG_LEVELS[clampi(lights_removed, 0, 3)]`）；`_draw` 用它畫兩個區域的背景，並畫跟隨中的老夫婦（兩個灰盒）
  - `_physics_process`：`APPROACH` 時角色 x > `arena().ENTRY_X` → `_enter_arena()`；跟隨中的老夫婦朝「角色 x − 160」移動（跑速 × 0.9）；`EXIT` 時 `Palace.on_exit(player.position)` → `_finish()`（Task 11）；每幀更新 HUD 的 `boss_name`（只在 `FIGHT`）、`boss_segments = 3 − lights_removed`、`boss_gauge`
  - `_enter_arena()`：關入口、相機範圍＝`arena().VIEW`；宮殿時老夫婦停止跟隨、`palace.couple_static = true`；第 1 段且未看過開場 → `stage = INTRO`、鎖定角色（`scripted = true`、清空 `intent`）、`boss.play_intro()`、等 `intro_finished`、`intro_seen = true`、解除鎖定（`scripted = player_scripted`）→ `_start_fight()`；第 2 段且未看過 → `await show_card("toothache")`、`palace_card_seen = true` → `_start_fight()`；其他 → `_start_fight()`
  - `_start_fight()`：`stage = FIGHT`、`boss.begin_phase(phase, first_move_once)` 後清空 `first_move_once`、`log.add(now(), "attempt_start", {"phase": phase, "keep": keep_phase})`
  - `func show_card(key: String) -> void`（協程）：`stage = CARD`、`world.process_mode = PROCESS_MODE_DISABLED`、`card.show_card(CardText.CARDS[key])`、`await card.closed`、`world.process_mode = PROCESS_MODE_INHERIT`（D3）
  - `func fill_summons(cap: int) -> void`：`boss.summons` 中爬行型、飛行型各補到 cap（爬行型在 Boss x ±250、地面；飛行型在 Boss x ±150、地面上方 500；x 夾在場地內）；`target = player`、`tn = tn`；`died` → 從 `boss.summons` 移除、碎光點＋`shatter` 音效；Boss 的 `summon_requested` 接到這裡
  - 連動：`boss.gauge_filled` → `log gauge_full`、`player.force_twin(0)`；`boss.glow_struck(n)` → `log glow_hit {"light": n}`；`boss.window_missed` → `log missed_window`；`boss.flashed` → `FalseFlash.is_facing(player.global_position.x, player.facing, boss.global_position.x)` 時 `whiteout.start()`、`log whiteout`（所有事件都帶 `"phase": phase`）
  - `func clear_battlefield() -> void`：清掉 `world` 裡的飛鏢、果子、反光柱、`boss.summons`；`boss.deactivate()`；`whiteout.stop()`
  - `func debug_fill_gauge() -> void`（F11）：只在 `FIGHT`：`boss.add_gauge(tn.gauge_max)`
  - `func start_at(p: int, first_move := "") -> void`（除錯與測試）：p＝1～3：`intro_seen = true`、`palace_card_seen = true`、`phase = p`、`lights_removed = p − 1`、`_apply_loadout()`、`first_move_once = first_move`、角色放到 `arena().ENTRY_X + 100`、`_enter_arena()`；p＝4 在 Task 11 補
  - 欄位 `var first_move_once := ""`（只給 `start_at` 與展示模式用）

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 10：Boss 戰流程（一）----

## 完整 Boss 戰（日誌寫到測試資料夾、文字卡不需等 0.5 秒）；start_phase 1～3 直接開打、4＝覺醒後的出口、0＝從樹下篝火開始
func make_fight(start_phase := 0, cycle := false) -> Node:
	var f = BossFight.new()
	f.tn = fresh_tuning()
	f.tester = "selftest"
	f.log_dir = TEST_LOG_DIR
	f.player_scripted = true
	add_child(f)
	await frames(3)
	f.card.min_time = 0.0
	f.boss.cycle_enabled = cycle
	if start_phase > 0:
		f.start_at(start_phase)
		await frames(2)
	return f


func free_fight(f) -> void:
	f.queue_free()
	await frames(2)
	remove_test_logs()


func log_types(f) -> Array:
	var out := []
	for e in f.log.events:
		out.append(e.type)
	return out


func test_fight_starts_at_tree_rest() -> void:
	var f = await make_fight()
	check(f.stage == BossFight.Stage.APPROACH and f.phase == 1, "從第 1 段的接近開始")
	check(f.player.position.distance_to(Nance.REST) < 50.0, "角色在樹下篝火")
	check(not f.nance.gate_closed and not f.palace.gate_closed, "兩個入口一開始都打開")
	check(f.boss.position.is_equal_approx(Nance.CANOPY) and f.boss.state == Macaw.State.DOWN, "Boss 停在樹冠、不出招")
	check(FileAccess.file_exists(f.log.path_base + ".jsonl"), "開戰就建立日誌")
	await free_fight(f)


func test_fight_entry_closes_gate_and_plays_intro() -> void:
	var f = await make_fight()
	f.player.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
	await frames(3)
	check(f.nance.gate_closed and f.stage == BossFight.Stage.INTRO and f.player_locked, "進場：入口關上、開場、角色不能操作")
	check(f.hud.boss_name == "", "開場時還沒有名字與血條")
	var lit: bool = await wait_until(func(): return f.boss.light.state == Light.State.GLOW, 90)
	check(lit and f.boss.position.distance_to(Nance.PERCH) < 4.0, "開場：降到低枝、下顎微亮")
	var fought: bool = await wait_until(func(): return f.stage == BossFight.Stage.FIGHT, 400)
	check(fought and not f.player_locked and f.hud.boss_name == CardText.BOSS_NAME, "開場後開打、名字與血條出現")
	check(f.boss.position.is_equal_approx(Nance.CANOPY), "開場結束回到樹冠")
	check(log_types(f) == ["attempt_start"], "開打記 attempt_start，實際 %s" % [log_types(f)])
	await free_fight(f)


func test_fight_summons_fill_to_cap() -> void:
	var f = await make_fight(1)
	f.fill_summons(1)
	f.fill_summons(1)
	await frames(2)
	check(count_of(f.world, Crawler) == 1 and count_of(f.world, Flyer) == 1, "第 1 段各補到 1 隻、不重複")
	f.fill_summons(2)
	await frames(2)
	check(count_of(f.world, Crawler) == 2 and count_of(f.world, Flyer) == 2 and f.boss.summons.size() == 4, "第 3 段各補到 2 隻")
	await free_fight(f)


func test_fight_gauge_full_swaps_to_hunahpu() -> void:
	var f = await make_fight(1)
	f.player.swap_twin()
	await frames(1)
	f.debug_fill_gauge()
	await frames(2)
	check(f.player.twin_index == 0 and f.boss.state == Macaw.State.BROKEN, "破綻滿：自動換成 Hunahpu、Boss 硬直")
	check(log_types(f).has("gauge_full"), "記 gauge_full")
	await free_fight(f)


func test_fight_flash_whiteouts_only_facing() -> void:
	var f = await make_fight(1)
	f.player.facing = 1
	f.boss.flashed.emit()
	check(f.whiteout.is_active() and f.player.health.hp == 5, "面向 Boss → 白茫、不扣血")
	f.whiteout.stop()
	f.player.facing = -1
	f.boss.flashed.emit()
	check(not f.whiteout.is_active(), "背對 → 沒事")
	check(log_types(f).count("whiteout") == 1, "白茫記一次")
	await free_fight(f)


func test_fight_card_freezes_world() -> void:
	var f = await make_fight(1)
	var p = f.player
	p.intent.move_x = 1.0
	f.show_card("arm")
	var x: float = p.position.x
	await frames(10)
	check(f.world.process_mode == Node.PROCESS_MODE_DISABLED and is_equal_approx(p.position.x, x), "文字卡顯示時戰場暫停")
	f.card.confirm()
	await frames(10)
	check(f.world.process_mode == Node.PROCESS_MODE_INHERIT and p.position.x > x, "關閉後恢復")
	await free_fight(f)


func test_fight_background_darkens_per_light() -> void:
	for i in 3:
		check(BossFight.BG_LEVELS[i + 1].get_luminance() < BossFight.BG_LEVELS[i].get_luminance(), "背景每一階都更暗（%d → %d）" % [i, i + 1])
	var f = await make_fight(3)
	check(f.lights_removed == 2 and f.background_color() == BossFight.BG_LEVELS[2], "第 3 段是戰鬥中最暗的一階")
	await free_fight(f)
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作** `boss_fight.gd`（照 Interfaces；死亡、設局換段、出口留到 Task 11）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/boss_fight.gd prototypes/core/tests/self_test.gd
git commit -m "Add boss fight flow for entry, intro, summons, auto swap, whiteout and cards (MV-PROTO-003)"
```

---

### Task 11: Boss 戰流程（二）：設局換段、死亡重試、結尾出口

**Files:**
- Modify: `prototypes/core/boss/boss_fight.gd`
- Test: `prototypes/core/tests/self_test.gd`

**Interfaces:**
- Consumes: Task 10 的 `boss_fight.gd`
- Produces：
  - `static func retry_phase(died_in: int, keep: bool) -> int`（第 3 段且 keep 為 false → 2；其他 → 原段；規格第 6 節）
  - `static func rest_point(p: int) -> Vector2`（1 → `Nance.REST`，其他 → `Palace.REST`）
  - 設局（接 `boss.setup_succeeded`）：`log setup`、`clear_battlefield()`、`lights_removed = 段`、隱藏 Boss 血條，然後：
    - 第 1 段：`await show_card("arm")`、`await show_card("couple")` → `phase = 2`、`_apply_loadout()`、`boss.park(2)`、角色傳送到 `Palace.PATH_START`（血量不補，D14）、老夫婦從 `PATH_START.x − 160` 開始跟隨、相機範圍 `Palace.REGION`、`stage = APPROACH`
    - 第 2 段：`await show_card("teeth")` → `phase = 3`、`_start_fight()`（Boss 從第 3 段開頭、記 `attempt_start`）
    - 第 3 段：`await show_card("death")`、`await show_card("awaken")` → `awakened = true`、`_apply_loadout()`、`boss.deactivate(true)`、相機範圍 `Palace.EXIT_VIEW`、`stage = EXIT`
  - 死亡（`_ready` 把 `player.died` 以 `CONNECT_DEFERRED` 接過來）：`log death {"phase": 段, "by": 死因}`（D12：`player.last_hurt_source` 的 `move_name`；沒有該屬性 → `summon`；null → `unknown`）→ `_retry(retry_phase(段, keep_phase))`
  - `_retry(p)`：`clear_battlefield()`、`phase = p`、`lights_removed = p − 1`、`player.respawn(rest_point(p))`、`_apply_loadout()`、該場地 `open_gate()`、`boss.park(p)`、相機範圍＝該區 `REGION`、`camera.reset_smoothing()`、`stage = APPROACH`；開場與第 2 段開場文字卡因 `intro_seen`／`palace_card_seen` 不再出現
  - `func reset_area() -> void`（F10；D18）：只在 `APPROACH`、`FIGHT` 時 `_retry(phase)`（不記死亡、不退段）
  - `_finish()`：`stage = DONE`、`log.close(now(), "clear")`、`await show_card("clear")`、發 `finished`
  - 離開：`_exit_tree()` 與 `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` 都呼叫 `log.close(now(), "quit")`（`close` 只生效一次）
  - `start_at(4)`：`phase = 3`、`lights_removed = 3`、`awakened = true`、`_apply_loadout()`、`boss.deactivate(true)`、`palace.couple_static = true`、角色放到 `Palace.RIGHT − 300`、相機範圍 `Palace.EXIT_VIEW`、`stage = EXIT`

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 11：Boss 戰流程（二）----

func kill_player(f, by: String) -> void:
	f.boss.move_name = by
	f.player.health.hp = 1
	f.player.hurtbox.receive(1, f.boss, &"enemy")
	await frames(3)


func setup_now(f) -> void:
	f.debug_fill_gauge()
	await frames(1)
	var h := fake_dart(true)
	f.boss.light.receive(1, h, &"dart")
	h.free()
	await wait_until(func(): return f.card.visible, 10)


func next_card(f, key: String) -> bool:
	var ok: bool = f.card.visible and f.card.text == CardText.CARDS[key]
	f.card.confirm()
	await frames(2)
	return ok


func test_retry_table_and_rest_points() -> void:
	check(BossFight.retry_phase(1, false) == 1 and BossFight.retry_phase(1, true) == 1, "死在第 1 段 → 第 1 段")
	check(BossFight.retry_phase(2, false) == 2 and BossFight.retry_phase(2, true) == 2, "死在第 2 段 → 第 2 段")
	check(BossFight.retry_phase(3, false) == 2, "死在第 3 段、預設 → 第 2 段")
	check(BossFight.retry_phase(3, true) == 3, "死在第 3 段、段落保留 → 第 3 段")
	check(BossFight.rest_point(1) == Nance.REST and BossFight.rest_point(2) == Palace.REST and BossFight.rest_point(3) == Palace.REST, "篝火位置")


func test_setup_phase1_goes_to_path_and_palace() -> void:
	var f = await make_fight(1)
	var p = f.player
	f.fill_summons(1)
	await setup_now(f)
	check(await next_card(f, "arm"), "第 1 段設局 → 斷臂文字卡")
	check(await next_card(f, "couple"), "接著請老夫婦同行")
	check(f.stage == BossFight.Stage.APPROACH and f.phase == 2 and f.lights_removed == 1, "進入小路、下一段是第 2 段")
	check(p.position.distance_to(Palace.PATH_START) < 50.0 and f.couple_following, "在小路起點、老夫婦跟著")
	check(not p.twins[0].weapon_enabled and not p.abilities_enabled, "Hunahpu 斷臂、能力仍停用")
	check(f.boss.summons.is_empty() and count_of(f.world, Crawler) == 0, "設局清空召喚的造物")
	p.position = Vector2(Palace.ENTRY_X + 50.0, Palace.GROUND_Y)
	await wait_until(func(): return f.card.visible, 10)
	check(await next_card(f, "toothache"), "第一次進宮殿 → 牙痛文字卡")
	check(f.stage == BossFight.Stage.FIGHT and f.palace.gate_closed and f.boss.phase == 2, "第 2 段開打、入口關上")
	await free_fight(f)


func test_setup_phase2_and_3_then_awaken() -> void:
	var f = await make_fight(2)
	var p = f.player
	await setup_now(f)
	check(await next_card(f, "teeth"), "第 2 段設局 → 換牙文字卡")
	check(f.stage == BossFight.Stage.FIGHT and f.phase == 3 and f.boss.phase == 3, "直接進第 3 段")
	check(log_types(f).count("attempt_start") == 2, "第 3 段開打也記 attempt_start")
	await setup_now(f)
	check(await next_card(f, "death"), "第 3 段設局 → 死亡文字卡")
	check(await next_card(f, "awaken"), "接著取回手臂、覺醒")
	check(f.stage == BossFight.Stage.EXIT and f.lights_removed == 3, "進入結尾出口")
	check(p.twins[0].weapon_enabled and p.abilities_enabled, "Hunahpu 武器恢復、兩項能力解鎖")
	check(not f.boss.visible, "Boss 已倒下")
	await free_fight(f)


func test_death_returns_to_rest_by_table() -> void:
	var f = await make_fight(3)
	await kill_player(f, "beam")
	check(f.phase == 2 and f.lights_removed == 1 and f.stage == BossFight.Stage.APPROACH, "死在第 3 段（預設）→ 第 2 段")
	check(f.player.position.distance_to(Palace.REST) < 50.0 and f.player.health.hp == 5, "回宮殿篝火、血量補滿")
	check(not f.palace.gate_closed, "入口重新打開")
	var last: Dictionary = f.log.events[f.log.events.size() - 1]
	check(last.type == "death" and last.phase == 3 and last.by == "beam", "日誌記下死在第 3 段、死因 beam，實際 %s" % [last])
	await free_fight(f)
	f = await make_fight(0)
	f.keep_phase = true
	f.start_at(3)
	await frames(2)
	await kill_player(f, "beam")
	check(f.phase == 3 and f.lights_removed == 2, "段落保留開 → 仍從第 3 段")
	f.player.position = Vector2(Palace.ENTRY_X + 50.0, Palace.GROUND_Y)
	await frames(3)
	check(f.stage == BossFight.Stage.FIGHT and not f.card.visible and f.boss.phase == 3, "重試直接開打第 3 段，不再顯示文字卡")
	await free_fight(f)


func test_reset_area_keeps_phase_without_death() -> void:
	var f = await make_fight(3)
	f.reset_area()
	await frames(2)
	check(f.phase == 3 and f.stage == BossFight.Stage.APPROACH, "F10：同一段重來，不退回第 2 段")
	check(f.player.position.distance_to(Palace.REST) < 50.0, "回宮殿篝火")
	check(not log_types(f).has("death"), "F10 不記死亡")
	await free_fight(f)


func test_retry_skips_intro() -> void:
	var f = await make_fight()
	f.player.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
	await wait_until(func(): return f.stage == BossFight.Stage.FIGHT, 400)
	await kill_player(f, "dive")
	check(f.player.position.distance_to(Nance.REST) < 50.0, "死在第 1 段 → 樹下篝火")
	f.player.position = Vector2(Nance.ENTRY_X + 50.0, Nance.GROUND_Y)
	await frames(3)
	check(f.stage == BossFight.Stage.FIGHT, "重試跳過開場")
	await free_fight(f)


func test_death_during_break_resets_boss() -> void:
	var f = await make_fight(1)
	f.player.swap_twin()
	f.debug_fill_gauge()
	await frames(2)
	await kill_player(f, "dive")
	check(f.boss.state == Macaw.State.DOWN and f.boss.light.state == Light.State.OFF and f.boss.gauge.value == 0, "重試：Boss 回到該段開頭、光源熄滅、破綻 0")
	check(f.player.twin_index == 0, "回到 Hunahpu")
	await free_fight(f)


func test_exit_robot_uses_new_abilities() -> void:
	var f = await make_fight(4)
	var p = f.player
	p.facing = 1
	await drive(p, [{"frames": 1, "swap": true}, {"frames": 25}, {"frames": 1, "dart": true}])
	var broke: bool = await wait_until(func(): return f.palace.barrier.is_broken, 150)
	check(broke, "覺醒後 Xbalanque 的工具能砍開出口木障")
	await drive(p, [{"frames": 1, "swap": true}, {"frames": 25}])
	p.intent.move_x = 1.0
	await wait_until(func(): return p.position.x >= Palace.EXIT_LEDGE.position.x - 150.0, 120)
	await drive(p, CLIMB)
	var done: bool = await wait_until(func(): return f.card.visible, 30)
	check(done and f.stage == BossFight.Stage.DONE and f.card.text == CardText.CARDS["clear"], "Hunahpu 二段跳上出口 → 通關文字卡")
	check(FileAccess.file_exists(f.log.path_base + ".md") and log_types(f).back() == "clear", "通關寫入摘要")
	await free_fight(f)


func test_fight_quit_writes_summary() -> void:
	var f = await make_fight(1)
	var base: String = f.log.path_base
	f.queue_free()
	await frames(2)
	check(FileAccess.file_exists(base + ".md"), "中途離開也寫摘要")
	var lines := FileAccess.get_file_as_string(base + ".jsonl").strip_edges().split("\n")
	var last = JSON.parse_string(lines[lines.size() - 1])
	check(last != null and last.type == "quit", "最後一筆是 quit")
	remove_test_logs()
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作**（照 Interfaces）
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/boss/boss_fight.gd prototypes/core/tests/self_test.gd
git commit -m "Add setup transitions, death retry with phase keep and awakening exit (MV-PROTO-003)"
```

---

### Task 12: 入口（main.gd）、展示模式、錄影檢查

**Files:**
- Create: `prototypes/core/launch_args.gd`
- Modify: `prototypes/core/main.gd`、`prototypes/core/project.godot`（`config/name="MV Core｜核心原型"`）
- Test: `prototypes/core/tests/self_test.gd`（preload `LaunchArgs := preload("res://launch_args.gd")`；不 preload `main.gd`，見 Global Constraints）

**Interfaces:**
- Consumes: Task 9 的 `StartMenu`；Task 10、11 的 `BossFight`
- Produces：
  - `launch_args.gd`（`extends RefCounted`）：`static func parse(args: PackedStringArray) -> Dictionary`：回傳 `{"mode": String, "demo": String, "tester": String, "boss_phase": int}`；`--self-test` → `selftest`；`--demo`／`--demo-pit`／`--demo-explore`／`--demo-parry` → `room`＋該參數；`--demo-boss-intro`（phase 0）、`--demo-boss-flash`（phase 1）、`--demo-boss-p3`（phase 3）→ `boss`＋該參數；`--boss` → `boss`、phase 0；`--boss-phase N` → `boss`、N 在 1～4 才採用，否則 0；`--tester X` → `FightLog.safe_name(X)`，沒給或缺值 → `anon`；其他 → `menu`
  - `main.gd` 的 `_ready` 用 `LaunchArgs.parse(OS.get_cmdline_user_args())` 決定模式
  - 模式切換：`show_menu()`（菜單記得上次的段落保留開關）、`start_room(demo := "")`（練習房＋HUD 包在一個容器節點；既有四種 demo 照舊）、`start_boss(phase := 0, demo := "")`（`BossFight`，`tester`、`keep_phase` 帶入；`finished` → `show_menu()`）；同時只有一個模式，切換時釋放前一個
  - 展示模式（`player_scripted = true`）：`--demo-boss-intro`：角色放到 `Nance.ENTRY_X + 50`；`--demo-boss-flash`：`start_at(1, "false_flash")`、角色放到 `Nance.CANOPY.x − 500`、面向右；`--demo-boss-p3`：`start_at(3)`、角色放到 `Palace.HOME.x − 600`、面向右
  - 按鍵：`menu_back`（Esc／Start）在練習房或 Boss 戰中 → `show_menu()`；Boss 戰中：F9＝存數值、印數值表、招架紀錄、`fight.log.summary_markdown(fight.now())`；F10＝`fight.reset_area()`；F11＝`fight.debug_fill_gauge()`；1／2／3＝`fight.player.set_weapon(...)`；練習房的 F9／F10／1／2／3 照舊
  - 檔頭註解列出全部參數

- [ ] **Step 1: 寫失敗的測試**

```gdscript
# ---- MV-PROTO-003 Task 12：入口與參數 ----

func test_launch_args_parse() -> void:
	check(LaunchArgs.parse(PackedStringArray()).mode == "menu", "沒有參數 → 開頭選單")
	check(LaunchArgs.parse(PackedStringArray(["--self-test"])).mode == "selftest", "--self-test")
	var a := LaunchArgs.parse(PackedStringArray(["--boss"]))
	check(a.mode == "boss" and a.boss_phase == 0 and a.tester == "anon", "--boss 直接進 Boss 戰，代號預設 anon")
	a = LaunchArgs.parse(PackedStringArray(["--boss-phase", "3", "--tester", "A 01"]))
	check(a.mode == "boss" and a.boss_phase == 3 and a.tester == "A_01", "--boss-phase 與 --tester（清理檔名字元）")
	check(LaunchArgs.parse(PackedStringArray(["--boss-phase", "9"])).boss_phase == 0, "段數超出範圍 → 從頭")
	check(LaunchArgs.parse(PackedStringArray(["--tester"])).tester == "anon", "--tester 缺值 → anon")
	a = LaunchArgs.parse(PackedStringArray(["--demo-parry"]))
	check(a.mode == "room" and a.demo == "--demo-parry", "既有展示模式進練習房")
	a = LaunchArgs.parse(PackedStringArray(["--demo-boss-p3"]))
	check(a.mode == "boss" and a.boss_phase == 3 and a.demo == "--demo-boss-p3", "Boss 展示模式")
```

- [ ] **Step 2: 執行測試確認失敗**
- [ ] **Step 3: 實作** `launch_args.gd`、`main.gd` 與 `project.godot`
- [ ] **Step 4: 執行測試確認通過**
- [ ] **Step 5: 錄影檢查**（每個指令執行後 `grep -c "SCRIPT ERROR"` 為 0；用 Read 工具看幀圖）

```bash
rm -rf /tmp/p3_intro /tmp/p3_flash /tmp/p3_p3 && mkdir -p /tmp/p3_intro /tmp/p3_flash /tmp/p3_p3
godot --path prototypes/core --write-movie /tmp/p3_intro/frame.png --fixed-fps 30 --quit-after 240 -- --demo-boss-intro > /tmp/p3_intro.log 2>&1
godot --path prototypes/core --write-movie /tmp/p3_flash/frame.png --fixed-fps 30 --quit-after 150 -- --demo-boss-flash > /tmp/p3_flash.log 2>&1
godot --path prototypes/core --write-movie /tmp/p3_p3/frame.png --fixed-fps 30 --quit-after 240 -- --demo-boss-p3 > /tmp/p3_p3.log 2>&1
```

Expected（目視）：開場 Boss 降到低枝、下顎小光點脈動，之後名字與三格血條出現；假光閃耀前搖有展翅光線、沒有圓形或鋸齒，閃光後畫面白茫淡入、維持、淡出；第 3 段背景最暗一階時，失衡撲擊的白色圓形與光束蓄力的暗紫鋸齒、眼睛微亮都清楚可辨。另跑一次不帶參數的 `godot --path prototypes/core --quit-after 60` 確認開頭選單畫得出來。看不清楚的項目要調顏色或大小後重錄，並記在執行報告。

- [ ] **Step 6: Commit**

```bash
git add prototypes/core/launch_args.gd prototypes/core/main.gd prototypes/core/project.godot prototypes/core/tests/self_test.gd
git commit -m "Add start menu entry, boss arguments, demo modes and menu return (MV-PROTO-003)"
```

---

### Task 13: README、派工單、規格、執行報告

**Files:**
- Modify: `prototypes/core/README.md`、`todo/todo.md`、`todo/spec/MV-PROTO-003_交織式Boss.md`（「基本資訊」狀態與「Git Commit」節）
- Create: `report/MV-PROTO-003_交織式Boss_{YYYY-MM-DD_HHmm}_執行報告.md`

**Interfaces:** 無程式介面。

- [ ] **Step 1: 改寫 README**：標題改「核心專案｜MV-PROTO-003 交織式 Boss」；「要回答的問題」換成本規格三題；「執行」加開頭選單、`--boss`、`--tester <代號>`、`--boss-phase`；操作表加 Esc／Start 回選單；新增「Boss 戰」一節（流程：樹下篝火 → nance 樹 → 小路 → 宮殿篝火 → 宮殿 → 出口；死亡回哪個篝火；段落保留開關；除錯鍵 F10、F11 只給 Brian）；「Brian 試打步驟」（規格「Brian 試打」的數值與可讀性問題逐項列出，F9 印數值表與日誌摘要，寫回原型驗證計畫）；「外人測試的做法」（事前只說操作與「這是一場 Boss 戰」，不提破綻、光源、設局、背對；用 `--tester <代號>`；日誌位置＝啟動時主控台印出的 `BOSSLOG` 路徑；Brian 要另外記的：卡住原因、事後訪談「打贏還是解開」的原話）；驗收 ①～④ 對照表；試玩紀錄表；自動驗證指令改 `--quit-after 60000`；展示模式加三個 Boss 參數；MV-PROTO-002 的內容移到「上一個原型：MV-PROTO-002」一節保留（001 一節照舊）。
- [ ] **Step 2: 執行完整測試**（測試指令；Expected：`fail=0`、`SCRIPT ERROR` 0；PASS 總數＝101＋本計畫新增數）
- [ ] **Step 3: 更新派工單與規格**：`todo/todo.md` 的 MV-PROTO-003 改 `⏸️ 暫停`、暫停原因「等待人工決策（Brian 試打與外人測試）」，說明欄加規格、計畫、報告連結與測試數；規格書狀態改「實作完成，待試打」、「Git Commit」節列出本分支的 commit。
- [ ] **Step 4: 寫執行報告**（`type: task-report`；含：做了什麼、測試結果、錄影檢查結果、計畫決定 D1～D20 中執行時有調整的、延後的問題、Brian 試打與外人測試的步驟、名稱表未定案提醒）
- [ ] **Step 5: Commit**

```bash
git add prototypes/core/README.md todo/todo.md todo/spec/MV-PROTO-003_交織式Boss.md report/
git commit -m "Document interleaved boss prototype and hand off for playtests (MV-PROTO-003)"
```
