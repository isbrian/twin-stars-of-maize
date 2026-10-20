# MV-SLICE-001c3b 地面事件的素材與動作 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 c3a 地面過場的佔位換成正式素材（Codex 生成 7 張）與新動作（雙胞胎、老鼠、祖母），並讓工具自己揮砍、修球具落地後 0.4 秒看不到。

**Architecture:** 素材走既有流程（工單 → Codex → `assets-test/c3b_art/` → `import_art.py` → `game/art/prop/`）。動作寫進既有的動作檔（12 fps、不內插），由現有的骨架與 `npc_animator` 播放。過場腳本只換外觀與動作：`silhouette.gd` 的 `kind` 不變、改畫正式圖，五段腳本的流程、旗標、長度不改。

**Tech Stack:** Godot 4.7.2、GDScript；Python 3（`tools/import_art.py`）；Codex CLI（`/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`）；ffmpeg。

**Spec:** [MV-SLICE-001c3b_地面事件素材與動作.md](MV-SLICE-001c3b_地面事件素材與動作.md)

## Global Constraints

- 7 張圖與遊戲高度：`prop_animal_deer.png` 170、`prop_animal_rabbit.png` 60、`prop_animal_coati.png` 70、`prop_food_corn.png` 50、`prop_food_beans.png` 25、`prop_tail_deer.png` 30、`prop_tail_rabbit.png` 30（自測容許 ±10%）。動物側面、面向左。
- 畫風照現有角色基準圖：平塗色塊、粗輪廓、有限色盤、洋紅底 #FF00FF；不畫投影、漸層、光暈；不要文字、類文字符號、東亞紋樣（中文 prompt 會往東亞造型偏，要主動排除）。每張最多生成 3 次；AI 用 Read 親眼驗收，Codex 的自評不算。
- Codex 指示固定寫：非互動執行、不要徵求同意、直接做；不 commit、不推送、不下載外部檔案、只寫 `assets-test/c3b_art/`、不自行宣告通過。呼叫一定接 `< /dev/null`。
- 新動作（12 fps、不內插；雙胞胎兩人共用 `twin_anims.json`）：雙胞胎 `plant`（單次）、`grab`（單次，停在最後一格）；老鼠 `climb`、`gnaw`、`talk`（循環）；祖母 `doze`（循環，約 2 秒一次起伏）。
- 近側手是 `hand_r`（`rig_view.gd` 的 `NearArm` 從 `upperarm_r` 起）；尾巴用 `actor.hold(tail, "hand_r")` 掛上。
- 動物夜色：`ANIMAL_NIGHT := SceneryView.NIGHT.lerp(Color.WHITE, 0.4)`（場景夜色和白色之間）；灌木、土塊、老鼠照舊原色。
- 過場流程、旗標、台詞、長度（每段 12～28 秒、天亮 4～10 秒）不改；c3a 的自測照舊要過。
- 註解、文件繁體中文；commit 英文、結尾 `(MV-SLICE-001c3b)`；全套自測基準 588 項；`body->get_space` 也算錯誤。
- 驗證腳本 `/tmp/wt/st_only.sh`、`gate.sh`、`step6.sh` 沿用 c3a（不存在就照 c3a 計畫的 Global Constraints 重建；`step6.sh` 的錯誤計數加 `body->get_space`）。

## Review Focus

1. Codex 的圖洋紅去背不乾淨（邊緣殘留粉紅）：遊戲裡動物、食物不該有粉紅邊——Task 1 `test_c3b_art_corners_transparent` 只驗四角，另由 AI 在深色底放大檢查邊緣並寫進工單。
2. 祖母在過場外（平時）睡著也要打盹：進祖母家時 `npc_asleep` 就該播 `doze`，不是只有過場中——Task 3 `test_grandmother_dozes_when_asleep`。
3. 跳過收工時，揮砍的碎屑粒子不該留在畫面上——Task 3 `test_dusk_skip_leaves_no_particles`。
4. 尾巴在兄弟倆後退時跟著手走、交還時一起消失——Task 3 `test_tail_follows_hand`。
5. 球具在咬繩交還的當下就可撿，離開再回來仍只有一個——Task 3 `test_gear_pickup_at_handover`（c3a 的 `test_gear_left_on_floor_survives_reentry` 照舊）。

---

### Task 1: 素材工單 MV-ASSET-020 與匯入

**Files:**
- Create: `docs/assets/MV-ASSET-020_素材工單_地面事件.md`
- Modify: `tools/import_art.py`（7 列）
- Create（不進版控）：`assets-test/c3b_art/*.png`、總覽 `assets-test/c3b_art/c3b_check.jpg`
- Create: `game/art/prop/` 7 張（匯入產物）
- Test: `game/tests/test_c3b.gd`（新）

**Interfaces:**
- Produces：`res://art/prop/prop_animal_deer.png`、`prop_animal_rabbit.png`、`prop_animal_coati.png`、`prop_food_corn.png`、`prop_food_beans.png`、`prop_tail_deer.png`、`prop_tail_rabbit.png`。

- [ ] **Step 1：寫工單**（格式照 MV-ASSET-019：用途、依據、設計決定、使用說明表、每張一段 prompt 與「看什麼」）。7 張各一段四段式 prompt（角色、任務、限制、輸出格式）；動物附上 `assets-test/batch2/chr/` 的雙胞胎與老鼠基準圖當畫風參考（實際檔名執行時查）。動物要「奔跑中、側面、面向左、四腳都看得到」；尾巴「單獨一撮、像被抓下來握在手裡的那一截，不畫血或傷口」。
- [ ] **Step 2：交 Codex**：`codex exec -s workspace-write --ephemeral --color never -C <repo> -o /tmp/wt/codex_020_last.md "<指示：讀工單、照 prompt 原文生成 7 張到 assets-test/c3b_art/、限制見 Global Constraints>" < /dev/null > /tmp/wt/codex_020.log 2>&1`（背景）。
- [ ] **Step 3：AI 驗收**：逐張 Read 原圖；做總覽 `c3b_check.jpg`（上排原圖、下排縮到遊戲高度並排在田地夜色底上）；不通過的照「退回時給具體描述」重生（每張最多 3 次）；結果表寫回工單。
- [ ] **Step 4：失敗測試 `test_c3b.gd`**
  - `test_c3b_art_present_and_sized`：7 張 `load()` 不為 null，`get_height()` 在 Global Constraints 的高度 ±10%。
  - `test_c3b_art_corners_transparent`：每張四角像素 alpha == 0。
- [ ] **Step 5：跑** `bash /tmp/wt/st_only.sh test_c3b`。Expected：FAIL（圖不存在）。
- [ ] **Step 6：`import_art.py` 加 7 列**（`src` `assets-test/c3b_art/<檔名>`、`dst` `prop/<檔名>`、`fit_height` 照表、去洋紅同其他 prop 列）→ `python3 tools/import_art.py` → `godot --headless --path game --import`。
- [ ] **Step 7：跑** `bash /tmp/wt/st_only.sh test_c3b`、`python3 tools/import_art.py --check`。Expected：PASS、結束碼 0。
- [ ] **Step 8：Commit** `git commit -m "Add the ground event art ticket and import the seven props (MV-SLICE-001c3b)"`

### Task 2: 新動作

**Files:**
- Modify: `game/rig/twin_anims.json`（`plant`、`grab`）、`game/rig/rat_anims.json`（`climb`、`gnaw`、`talk`）、`game/rig/xmucane_anims.json`（`doze`）
- Modify（若測試要求）：`game/world/rig_showcase.gd`（展示清單）
- Test: `game/tests/test_c3b.gd`

**Interfaces:**
- Produces：上面 6 個動作名；`actor.play(...)`、`npc_animator.play(...)` 播得出來。

- [ ] **Step 1：失敗測試**
  - `test_c3b_anims_present`：雙胞胎兩人的骨架（`hunahpu`、`xbalanque`）都有 `plant`、`grab`；老鼠有 `climb`、`gnaw`、`talk`；祖母有 `doze`；`loop`：`plant`、`grab` false，其餘 true；`doze` 長度 1.8～2.4 秒。
  - `test_grab_ends_with_hand_forward`：`grab` 最後一格的 `hand_r` 在骨架座標裡位於肩膀前方（x 大於肩膀 x）、高度在胸口附近（介於骨盆與頭之間）。
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c3b`。Expected：FAIL。
- [ ] **Step 3：寫關鍵姿勢**（格式同現有動作：`fps` 12、`frames` 的 `t`、`bones` 角度、`root`）。姿勢照規格「新動作」表；`grab` 從 `lunge` 最後一格起身；`climb` 用 `root` 與 `body` 轉 −80～−90 度表現直立；祖母 `doze` 用骨盆下沉（`root` y 往下）＋`torso` 前傾＋`head` 垂下。
- [ ] **Step 4：跑** `bash /tmp/wt/gate.sh test_c3b test_rig test_npc_rig test_twin_animator`。Expected：全 PASS（每格接縫覆蓋的既有測試會自動涵蓋新動作；展示清單測試若要求就把新動作加進 `rig_showcase.gd`）。
- [ ] **Step 5：抽格**：`godot --path game -- --rig-view --frames /tmp/wt/c3b_rig`（只截新動作的段落拼成 `assets-test/c3b_video/c3b_poses.jpg`），AI 看姿勢是否讀得出（插、握、爬、咬、比劃、打盹），不像就改關鍵姿勢重跑 Step 4。
- [ ] **Step 6：Commit** `git commit -m "Add plant, grab, climb, gnaw, talk and doze animations (MV-SLICE-001c3b)"`

### Task 3: 過場換上正式素材與動作

**Files:**
- Modify: `game/world/cutscene/silhouette.gd`、`field_animals.gd`、`field_dusk.gd`、`rat_deal.gd`、`gear_rope.gd`、`game/events/gear_drop.gd`、`game/world/room.gd`
- Modify: `game/tests/test_c3a.gd`（只在它檢查佔位細節時）
- Test: `game/tests/test_c3b.gd`

**Interfaces:**
- Consumes：Task 1 的 7 張圖、Task 2 的 6 個動作；c3a 的 `cs.place()`、`actor.hold()`、`runner.play()`、`room.npc_asleep`。
- Produces（`silhouette.gd`）：`var texture: Texture2D`（依 `kind` 設好：`deer`→鹿、`rabbit`→兔子、`critter`→長鼻浣熊、`tail_deer`、`tail_rabbit`、`corn`、`beans`、`cacao`）；`const ANIMAL_NIGHT`；動物種類（`deer`、`rabbit`、`critter`）`modulate = ANIMAL_NIGHT`；`func bounce(k: float) -> void`（依移動進度上下彈跳：鹿幅度 18 px、2 步；兔子 24 px、4 跳；長鼻浣熊 10 px、5 步）。
- Produces（`field_dusk.gd`）：`static func chop(cs, tool: Node2D, at: Vector2, kind: String) -> void`（`kind` `"axe"` 來回揮 3 下、每下 ±40 度；`"stick"` 上下翻 3 下；每下在 `at` 放一次 `CPUParticles2D` 碎屑（葉片綠 `Color(0.35, 0.55, 0.2)`、土屑褐 `Color(0.45, 0.3, 0.18)`，`one_shot`、約 12 顆、0.6 秒），放進過場（`cs.place`，交還時一起釋放））。
- Produces（`room.gd`）：`npc_asleep` 為 true 時 `npc_anim.play("doze")`，false 時 `npc_anim.play("idle")`（沒有 `npc_anim` 的灰盒房間不動作）。

- [ ] **Step 1：失敗測試（`test_c3b.gd`，設置沿用 `test_c3a.gd` 的 `setup()`／`finish()`）**
  - `test_silhouettes_use_art`：每個 `kind` 建一個 `Silhouette`，`texture` 等於對應的 `res://art/prop/...`；動物的 `modulate` 等於 `ANIMAL_NIGHT`，食物與尾巴是白色。
  - `test_dusk_plants_and_chops`：清完田地後在過場中輪詢：雙胞胎替身播過 `plant`、過場的 `Cast` 底下出現過 `CPUParticles2D`；看完（`time_scale` 8）長度仍 12～28 秒（用 `time_scale` 1 的版本量；可併入既有長度測試）。
  - `test_dusk_skip_leaves_no_particles`：一開始就跳過，交還後房間與過場底下都沒有 `CPUParticles2D`。
  - `test_animals_grab_and_tail_follows_hand`（即 Review Focus 的 `test_tail_follows_hand`）：動物復原中雙胞胎替身播過 `grab`、`held` 是 `tail_deer`／`tail_rabbit` 的剪影；後退時尾巴的全域位置跟著替身移動（兩個時間點的位移差 < 5 px）；交還後尾巴不在場上。
  - `test_rat_talks_in_deal`：交換中老鼠替身播過 `talk`。
  - `test_rope_climb_and_gnaw`：咬繩中老鼠替身播過 `climb`、`gnaw`。
  - `test_gear_pickup_at_handover`：咬繩跳過後，在 `runner.cutscene_running()` 仍為 true（黑邊還在收）時 `room.pickups.size() == 1`；之後也只有一個。
  - `test_grandmother_dozes_when_asleep`：有 `rat_caught` 進祖母家、跳過咬繩後 `room.npc_anim.anim == "doze"`（屬性名執行時查 `npc_animator.gd`）；撿球具、跳過天亮後是 `idle`。
- [ ] **Step 2：跑** `bash /tmp/wt/st_only.sh test_c3b`。Expected：Task 3 的測試 FAIL，Task 1、2 的 PASS。
- [ ] **Step 3：實作**照 Interfaces：
  - `field_animals.gd`：動物移動用 `cs.animate` 時順便呼叫 `bounce(k)`；撲完 `cs.play(me, "grab")`，尾巴改成 `me.hold(tail, "hand_r")`（取代 c3a 的掛在固定位置）。
  - `field_dusk.gd`：`interact` → `plant`；`_work` 每叢灌木先飛過去再 `chop(...)`、之後灌木淡出；過場長度維持 12～28 秒（必要時縮短飛行時間）。
  - `rat_deal.gd`：每句 `say` 前 `rat_a.play("talk")`、說完回 `idle`。
  - `gear_rope.gd`：爬升播 `climb`（取代 `run`）、咬繩播 `gnaw`（取代抖動）；`end_state` 加 `host.room.add_pickup("gear", "gear", Vector2(rope_at(host.room).x, host.room.data.ground_y))`；`gear_drop.gd` 只在進門時已有 `gear_dropped` 才自己放。
  - `room.gd`：`npc_asleep` 的 setter 加上播 `doze`／`idle`。
- [ ] **Step 4：跑** `bash /tmp/wt/gate.sh test_c3b test_c3a test_events test_walkthrough test_npc_rig`。Expected：全 PASS、0 `SCRIPT ERROR`、0 `body->get_space`。
- [ ] **Step 5：Commit** `git commit -m "Dress the ground cutscenes with the new art and animations (MV-SLICE-001c3b)"`

### Task 4: 錄影、截圖、文件

**Files:**
- Create（不進版控）：`assets-test/c3b_video/`（`field.mp4`、`deal.mp4`、`rope.mp4`、`morning.mp4`、`c3b_all.mp4`、`c3b_frames.jpg`）、`assets-test/c3b_shots/`
- Modify: `game/README.md`（地面事件的演出一節：佔位改成正式素材、新動作）、`docs/assets/MV-ASSET-020_素材工單_地面事件.md`（驗收結果）、`todo/todo.md`、`todo/spec/MV-SLICE-001c3b_地面事件素材與動作.md`
- Create: `report/MV-SLICE-001c3b_地面事件素材與動作_<date>_執行報告.md`（時間戳先跑 `date`）

- [ ] **Step 1：錄影**：四個名稱各跑 `godot --path game --fixed-fps 30 -- --cutscene <名稱> --frames /tmp/wt/c3b_frames/<名稱>`，ffmpeg 合成到 `assets-test/c3b_video/`，串接 `c3b_all.mp4`、抽格 `c3b_frames.jpg`。AI 抽格檢查：新素材在畫面上（動物夜色比場景亮、看得出種類）、新動作讀得出、碎屑看得到、尾巴在手上、祖母打盹、球具落地即可撿。
- [ ] **Step 2：截圖**：`godot --path game -- --shots /tmp/wt/c3b_shots`，每個畫面平均幀時間 ≤ 16.7 ms；拼 `assets-test/c3b_shots/c3b_check.jpg`（`home`、`field`、`field_night`）。
- [ ] **Step 3：跑** `bash /tmp/wt/step6.sh`（背景）。Expected：兩個 `--check` 結束碼 0、unittest OK、自測 `fail=0`（588＋新增）、0 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`。
- [ ] **Step 4：文件與 Commit**：README、工單驗收結果、規格書狀態與驗收清單、執行報告（Rulings、驗證、影片路徑）、todo；`git commit -m "Record the dressed ground cutscenes and document them (MV-SLICE-001c3b)"`
