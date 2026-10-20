# MV-SLICE-001d1b 新音效進遊戲

更新時間：2026-10-20

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001d1b_新音效進遊戲`（從 `feature/MV-SLICE-001d1a_聲音系統` `3a4f74e` 開；d1a 合併後改以 `develop` 為基準） |
| 影響範圍 | `game/art/audio/`（新音檔）、`game/core/audio/audio.gd`、`sound_table.gd`；接入點：`game/world/room.gd`、`game/core/boss/boss_fight.gd`、`game/core/player/player.gd`、`rat.gd`、`tool_spirit.gd`、`game/core/enemies/*.gd`、`game/world/twin_animator.gd`、`game/rig/twin_anims.json`、`game/world/pickup.gd`、`game/events/event_runner.gd`、`game/ui/*.gd`、`game/world/cutscene/*.gd`、`game/world/rooms/home.gd` |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：d1a 聲音系統 → d1b（本文件）→ d2 外圍 → d3 打包 |
| 前置 | [MV-SLICE-001d1a](MV-SLICE-001d1a_聲音系統.md)（`Audio`、資料表、回退）；[MV-ASSET-021](../../docs/assets/MV-ASSET-021_素材工單_切片缺的音效.md)（123 個檔，AI 驗收通過） |
| 設計依據 | [AUDIO_SPEC](../../AUDIO_SPEC.md) 第 6、7 節；MV-ASSET-021 的定案 A21-1～7 |
| 引擎 | Godot 4.7.2 |
| 狀態 | ✅ 完成：手把試玩通過（Brian 2026-10-20「試玩可以」），推送並開 PR；展示影片與 MV-ASSET-021 試聽檔未另外回報 |

## 背景與目的

d1a 之後，遊戲裡的揮擊、命中、受擊、腳步、敵人、拾取、介面、地面與 Boss 過場的動作聲，都還是程式合成的佔位或沒有聲音。MV-ASSET-021 已生成 61 種、123 個正式音檔。d1b 把它們接進遊戲，讓切片的聲音全部是正式素材（「正式品質」的標準）。

## 盤點（2026-10-20，AI 實查）

- 目前走合成佔位的 id（`feedback.play`，`room.gd`、`boss_fight.gd`）：`swing`、`hit`、`pogo`、`dart`、`hurt`、`heal`、`swap`、`parry`、`double_jump`、`tool_out`、`chop`、`barrier_break`、`thud`、`interrupt`。
- 角色訊號（`player.gd`）：`swung`、`hit_landed(target)`、`dart_fired`、`hurt_taken`、`healed`、`swapped`、`parried`、`double_jumped`、`tool_sent`、`pogo_bounced`；招架落空在 `_record_parry(WHIFF)`，**沒有訊號**。
- 跑步：`twin_anims.json` 的 `run`，6 格、12 fps、循環；沒有「腳著地」標記。
- 地面：房間資料有 `theme`、`platforms`；沒有地面材質欄位。宮殿是 Boss 段落第 2、3 段的場地（`palace_arena.gd`）。
- 選單：`title_menu`、`pause_menu`、`shop`（祖母兌換）、`equip_page`、`text_card` 都經 `menu_input.gd`。
- 老鼠技能：`rat.gd`（鑽地 → 在敵人腳下竄出）；工具自己動：`tool_spirit.gd`（`chopped`）。
- d1a 延後、本次一起修的 4 項：命中停頓讓 `Audio` 的淡化暫停；MUS-S01 放完 `Audio.music` 仍是 `mus_s01`；結束時「resources still in use」多了音檔；`boss_fight.gd` 的 `_sync_music` 插在 `_update_forest_hint` 的說明與本體之間。

## 定案（Brian，2026-10-20）

| ID | 議題 | 定案 | 理由 |
|---|---|---|---|
| SLICE-d1b-1 | 腳步觸發 | 雙胞胎 `run` 動作標出腳著地的格，播到就放 | 聲音跟畫面對得上；跑快跑慢自動跟著變 |
| SLICE-d1b-2 | 硬地範圍 | 宮殿地面＋祖母家屋內＋木平台算硬地；其他都是土 | 宮殿是石地、屋內是夯實地板、平台是木頭 |
| SLICE-d1b-3 | 敵人的移動與攻擊 | 依距離淡出、畫面外聽不到（帶左右聲道）；前兆維持全音量 | 不然整間房的敵人一起沙沙響 |
| SLICE-d1b-4 | 前兆播放器 | 前兆用專用播放器，不和一般音效搶 | 腳步、揮擊、命中進來後，前兆可能被截斷；前兆是混音第一優先 |
| SLICE-d1b-5 | 過場腳步 | 雙胞胎有，其他人沒有 | 只有雙胞胎有腳步素材；老人與祖母走得慢、無聲也自然 |
| SLICE-d1b-6 | d1a 延後的小問題 | 修 4 個便宜的（見盤點） | 每個幾行、各配一個測試 |
| SLICE-d1b-7 | 合成佔位 | 保留當備援；另加自測「程式裡用到的每個 id 都在資料表」，確保備援不會默默蓋掉漏接 | 漏接也不會靜音，但自測抓得到 |

沿用 d1a：`feedback.play(id)` 的接入點寫法不變；混音、匯流排、限幅器不改。

## 範圍

### 對照表：id → 音檔 → 時機

| id | 音檔（MV-ASSET-021） | 時機 | 接在哪裡 |
|---|---|---|---|
| `step_dirt_hunahpu`／`step_dirt_xbalanque`／`step_hard_hunahpu`／`step_hard_xbalanque` | S21-01～04 | `run` 播到腳著地的格（依目前的兄弟與地面） | `twin_animator.gd`（遊戲與過場共用） |
| `jump`／`land`／`roll` | S21-05、06、08 | 起跳、從空中落地、翻滾開始 | `player.gd` 新增訊號或在狀態切換處呼叫 |
| `double_jump` | S21-07 | 二段跳（取代合成） | 資料表對應 |
| `swing_axe`／`swing_stick` | S21-09、11 | 揮擊（依目前武器） | `swung` 的接入點改傳武器別的 id |
| `hit_axe`／`hit_stick` | S21-10、12 | 近戰命中（依目前武器） | `hit_landed` 的接入點 |
| `parry`（`parry_ok`）／`parry_miss` | S21-13、14 | 招架成功（取代合成）／落空 | 新增 `parry_whiffed` 訊號，在 `_record_parry(WHIFF)` 發出 |
| `dart` | S21-15 | 吹箭發射（取代合成） | 資料表對應 |
| `dart_hit`／`dart_weak` | S21-16、17 | 吹箭打中物件或地形／打中 Seven Macaw 微亮的光源（打斷前搖另由 `interrupt` 放，不重複） | `dart.gd` 命中處 |
| `interrupt` | S21-17（同 `dart_weak`） | 吹箭打斷前搖 | 資料表對應（素材工單沒有「打斷」，用「命中弱點」，見下方說明） |
| `hurt`／`heal` | S21-18、19 | 受擊、喝熱湯（取代合成） | 資料表對應 |
| `swap_hunahpu`／`swap_xbalanque` | S21-20、21 | 換人後依「被切到的兄弟」 | `swapped` 的接入點 |
| `enemy_move_*`／`enemy_attack_*`（crawler／flyer／reflector） | S21-22～26 | 移動中每步（約 0.35 秒一次，只在有移動時）、出招 | 各敵人腳本；**`AudioStreamPlayer2D`**，`max_distance` 約一個畫面寬 |
| `thud`（反光型擋下） | S21-27 | 反光型正面擋下 | `reflector` 的 `thudded`（木障另用 `barrier_thud`） |
| 反光型光束 | `boss_sm_beam_charge`／`beam_fire`（A21-3） | 反光型蓄力、發射 | `reflector.gd`；音量 -6 dB、走距離衰減 |
| `chop`／`tool_dig` | S21-28、29 | 工具自己砍灌木／翻土 | `tool_spirit.gd`、收工過場 |
| `rat_burrow`／`rat_emerge` | S21-30、31 | 老鼠鑽地、竄出 | `rat.gd` |
| `pick_cacao`／`pick_fragment`／`pick_item` | S21-32～34 | 撿可可豆、血量碎片、工具或球具 | `pickup.gd`、`event_runner.gd` |
| `barrier_break`／`barrier_thud` | S21-35、36 | 木障打破／打到沒破 | 資料表對應（`thud` 的木障接入點改 id） |
| `pogo` | S21-37 | 下劈打中水晶彈起（取代合成） | 資料表對應 |
| `npc_exchange` | S21-38 | 祖母兌換成功 | `shop.gd` 的 `confirm()` 成功時 |
| `thorn_hurt` | S21-39 | 踩到荊棘被彈回 | `room._thorn_respawn` |
| `tool_out` | S21-11（同 `swing_stick`，音量 -4 dB） | 送出工具 | 資料表對應（素材工單沒有，見下方說明） |
| 過場 16 種（`cs_*`） | S21-40～55 | 依 MV-ASSET-021 G6 表的「用在」欄 | `opening`、`arm`、`field_animals`、`rat_deal`、`gear_rope`、`teeth`、`death`、`awaken` 各過場腳本 |
| `ui_move`／`ui_confirm`／`ui_back` | S21-56～58 | 選單移動、確認、返回或取消 | `title_menu`、`pause_menu`、`shop`、`equip_page` |
| `ui_skill_switch` | S21-59 | 裝備頁更換技能槽 | `equip_page` |
| `ui_page_open`／`ui_page_close` | S21-60、61 | 裝備頁、文字卡打開／關上 | `equip_page`、`text_card` |

**素材工單沒有、本規格決定沿用的 2 項**（請審時確認）：
- `interrupt`（吹箭打斷前搖）→ 用 `dart_weak`。打斷就是「打中要害」，玩家聽到同一個聲音，學得更快。
- `tool_out`（送出工具）→ 用 `swing_stick`、音量 -4 dB。是「揮出去」的動作；另做新音效要再交派一次。

### 腳步

- `twin_anims.json` 的 `run` 加 `steps` 欄位（腳著地的格號，預計 2 個），`twin_animator.gd` 播到那格時放腳步。
- 依目前操作的兄弟選 `hunahpu`／`xbalanque`；依角色腳下的地面選 `dirt`／`hard`。
- 硬地判定：站在 `platforms` 上；房間資料 `floor: "hard"`（`home` 加這一欄）；Boss 段落第 2、3 段的宮殿地面。其餘是土。
- 過場：雙胞胎替身走路也放腳步（SLICE-d1b-5），其他角色不放。
- 只在地面上：空中、翻滾、受擊硬直中不放。

### 前兆專用播放器（SLICE-d1b-4）

- `Audio` 另建 2 個前兆專用的播放器（`Tell` 匯流排）；一般音效的 12 個輪流播放器不再播前兆。

### d1a 延後的 4 項（SLICE-d1b-6）

1. `Audio` 的 tween 加 `set_ignore_time_scale(true)`：命中停頓（`Engine.time_scale = 0`）時淡化照常。
2. 不循環的配樂放完時，`Audio.music` 清成 `&""`、播放器釋放。
3. `Audio._exit_tree`：停掉所有播放器、清快取（結束時不再多出音檔的「resources still in use」）。
4. `boss_fight.gd`：`_update_forest_hint` 的說明搬回它自己上方。

### 不做

- 新的生成或重做音效（試聽不合適的列進清單，另開工單）。
- 人聲、音量設定選單（SLICE-4）、聆聽（MV-PROTO-006）。
- 移除合成佔位（SLICE-d1b-7 保留）。
- 試聽前的全域低通（MV-ASSET-021 提醒的高頻嘶聲，等試聽結果再決定）。

## 自測

1. 資料表：新增的每個 id 的檔案存在、載得到；**程式裡所有 `feedback.play(&"…")`、`Audio.play(&"…")` 用到的 id 都在 `SOUNDS`**（掃描原始碼；SLICE-d1b-7）。
2. 腳步：`run` 有 `steps`；跑步時每個循環放 2 次腳步；胡納普與希巴拉克各用自己的檔；站在平台、祖母家、宮殿用 `hard`，森林用 `dirt`；空中與翻滾時不放。
3. 武器：斧頭與掘棒的揮擊、命中各用自己的 id；招架成功放 `parry`、落空放 `parry_miss`。
4. 換人：切到胡納普放 `swap_hunahpu`、切到希巴拉克放 `swap_xbalanque`。
5. 敵人：移動與攻擊聲走 `AudioStreamPlayer2D`；移動中才放；前兆仍走 `Tell`、全音量。
6. 前兆專用播放器：一般音效連播 20 個後再前兆，前兆照樣播出、不被截斷。
7. 拾取、木障、荊棘、老鼠、工具、兌換：各觸發一次，`play_count` 對應的 id +1。
8. 介面：主選單、暫停、兌換、裝備頁的移動、確認、返回；文字卡開關。
9. 過場：16 種過場音效在對應過場中各出現 ≥ 1 次（跑過場、讀 `play_count`）。
10. d1a 延後 4 項：命中停頓中淡化照常完成；MUS-S01 放完後 `Audio.music == &""`；其餘兩項靠審查與結束時沒有新的警告。
11. 全套自測全過（基準 630＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`。

## 風險與退路

| 風險 | 退路 |
|---|---|
| 腳步太密、太吵 | 腳步匯流排音量（`Sfx` 下的 `db`）調低；必要時每循環只放 1 次 |
| 合成白噪音的高頻嘶聲（MV-ASSET-021 提醒） | 試聽後在 `Sfx` 加低通，或列進重做清單 |
| 敵人移動聲在關門戰疊太多 | 同種敵人移動聲 0.1 秒內只放一次 |
| 過場時間點對不上動作 | 照過場腳本的 `await` 位置放；影片抽格對照 |

## 驗收標準

實作完成（AI）：

- [x] 自測全部通過，沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`（664／0）
- [x] 聲音展示（`--sound-tour`）加上腳步、戰鬥、拾取、介面與過場段落，重錄影片（`assets-test/d1b_video/d1b_sound_tour.mp4`，343 秒，-19.7 LUFS、-1.3 dBTP）；另做 MV-ASSET-021 試聽檔（123 個檔＋時間表）

驗收（Brian）：

- [ ] 聽影片（同時試聽 MV-ASSET-021：不合適的告訴我編號與原因）——未另外回報
- [x] 手把從頭玩到結尾——2026-10-20「試玩可以」（試玩紀錄沒有錯誤）

## Git Commit

分支 `feature/MV-SLICE-001d1b_新音效進遊戲`（從 `feature/MV-SLICE-001d1a_聲音系統` `3a4f74e` 開）：
