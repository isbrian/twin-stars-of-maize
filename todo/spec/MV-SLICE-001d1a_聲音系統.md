# MV-SLICE-001d1a 聲音系統

更新時間：2026-10-19

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001d1a_聲音系統`（從 `develop` `3d8d08f` 開） |
| 影響範圍 | `game/core/audio/audio.gd`（新，autoload `Audio`）、`game/core/audio/sound_table.gd`（新）、`game/art/audio/`（新，正式音檔）、`game/project.godot`（autoload、匯流排）、`game/core/fx/feedback.gd`；接入點：`game/core/enemies/enemy.gd`、`game/core/boss/seven_macaw.gd`、`game/core/boss/moves/*`、`game/core/boss/boss_fight.gd`、`game/world/room_flow.gd`、`game/world/game_world.gd`、`game/world/cutscene/`（toothache、teeth、death、awaken） |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：d 拆成 d1a 聲音系統（本文件）→ d1b 新音效進遊戲 → d2 外圍 → d3 打包（SLICE-d-1、d-2） |
| 前置 | MV-SLICE-001c 全部完成；音檔：MV-ASSET-004～007 的定稿 |
| 設計依據 | [AUDIO_SPEC](../../AUDIO_SPEC.md) 第 2 節（聲音語彙）、第 5 節（環境音）、第 7 節（混音優先序）；[MV-ASSET-007](../../docs/assets/MV-ASSET-007_素材工單_SevenMacaw音訊.md)（Seven Macaw 各音效的用途） |
| 引擎 | Godot 4.7.2 |
| 狀態 | ✅ 完成：影片與手把試玩通過（Brian 2026-10-20），推送並開 PR 到 `develop` |

## 背景與目的

切片的「正式品質」要求畫面與聲音都是正式素材，但遊戲裡現在**全部是程式合成的佔位音效**（`core/fx/sfx.gd`），沒有環境音、沒有配樂，已經生成並驗收過的音檔一個都還沒進遊戲。d1a 建立聲音系統，把已有的音檔接上；缺的音效在 d1b 補（素材工單 MV-ASSET-021 同時進行）。

## 盤點（2026-10-19，AI 實查）

- 入口：`core/fx/feedback.gd` 的 `play(sound: StringName)`，從 `sfx.gd` 合成的音效庫取聲音，6 個 `AudioStreamPlayer` 輪流用。每個房間（`room.gd`）與 Boss 戰（`boss_fight.gd`）各自建一份 `Feedback`。沒有匯流排、沒有循環聲音。
- 已用的合成 id：`swing`、`hit`、`dart`、`interrupt`、`hurt`、`heal`、`pogo`、`shatter`、`swap`、`parry`、`double_jump`、`tool_out`、`chop`、`barrier_break`、`thud`。
- 前搖：一般敵人 `enemy.gd` 的 `State.TELEGRAPH`＋`parryable`（爬行型、飛行型、反光型共用）；Seven Macaw 的招式 `moves/move.gd` 的 `signal_kind`（`NONE`／`PARRY`／`UNPARRY`）。
- 房間：資料裡已有 `theme`（`home`、`field`、`yard`、`forest` × 9）；Boss 段落（`boss`）沒有 theme。換房由 `room_flow.gd` 負責（`room_changed` 訊號）。
- Boss 段落：`boss_fight.gd` 的 `Stage { APPROACH, INTRO, FIGHT, CARD, EXIT, DONE }`，`phase` 1～3；覺醒過場 `world/cutscene/awaken.gd`。
- 已有音檔（`assets-test/`，未進版控）：

| 類別 | 檔案 | 位置 |
|---|---|---|
| 聲音語彙 | `sfx_voc_{alive,danger,echo,glass,hollow,real,tell_heavy,tell_parry}_01～03.wav`（24 個） | `batch0/audio/` |
| 環境音 | `amb_01_forest.wav`、`amb_02_home.wav`、`amb_03_ballcourt.wav`（各 11 MB）、`amb_01_forest_glass.wav`（玻璃顫音層） | `batch1/audio/` |
| 配樂 | `mus_b01_sevenmacaw.wav`（90 秒循環，16.5 MB）、`mus_s01_awaken.wav`（4 秒） | `batch2/audio/` |
| Seven Macaw | `sfx_boss_sm_*`：19 種、共 31 個（含變體） | `batch2/audio/` |
| 事件 | `sfx_evt_cover_01.wav` | `batch2/audio/` |

- 工具：`ffmpeg` 在 `/opt/homebrew/bin/ffmpeg`。

## 定案（Brian，2026-10-19）

| ID | 議題 | 定案 | 理由 |
|---|---|---|---|
| SLICE-d-1 | d 的拆法 | 拆成 d1 聲音 → d2 外圍（標題、主選單、繪本前篇、HUD 檢查）→ d3 打包 | 三塊互不依賴；聲音量最大；打包放最後才打包到完整內容 |
| SLICE-d-2 | d1 再拆 | d1a 聲音系統＋已有音檔 → d1b 新音效進遊戲；素材工單 MV-ASSET-021 與 d1a 同時進行 | 已有的音檔馬上能接，不用等生成 |
| SLICE-d-3 | 缺的音效 | 照 MV-ASSET-007：開素材工單交 Codex CLI 用固定 seed 程式合成 | 音色與現有 Seven Macaw 音效一致、可重建、沒有授權問題 |
| SLICE-d-4 | 腳步材質 | 土＋硬地（木平台、宮殿）兩種 × 兩兄弟 × 4 變體（d1b） | 草和土在作品集展示裡聽不出差別 |
| SLICE-d-5 | 前兆聲 | 一般敵人與 Seven Macaw 的每次前搖都放前兆聲（可招架／不可招架），混音最優先；Seven Macaw 的專屬音效疊在前兆聲上 | 聲音語彙是這部作品的核心賣點 |
| SLICE-d-6 | 探索段配樂 | 不放，探索只有環境音；房間依地點切 AMB-01／02／03，交叉淡化 | 照 AUDIO_SPEC；讓 Boss 配樂出來時更有層次 |
| SLICE-d-7 | 人聲 | 換人、與祖母交換的「非語言回應」改用樂器短音（兩兄弟各一種音色）（d1b） | 程式合成做不出像樣的人聲 |
| SLICE-d-8 | 虛假聲 | 玻璃顫音層依最近一隻活著的假光造物的距離淡入、全部打完就消失；碎裂成光點放 `voc_glass` | 玩家聽得出「這裡清乾淨了」 |
| SLICE-d-9 | 過場音效 | 地面三個事件與 c2 過場缺的動作音放進 MV-ASSET-021（d1b）；已有的 Seven Macaw 過場音效 d1a 直接接 | 過場沒聲音會很明顯 |
| SLICE-d-10 | 其他語彙 | 危險＝地上荊棘（距離層）、活物＝跟 NPC 與老鼠互動、真實＝篝火休息；殘響不用 | 殘響屬於死者，切片裡沒有對應對象 |
| SLICE-d-11 | Boss 配樂 | 各段開打時淡入（從頭播）、該段結束時淡出；過場中不放；覺醒放 MUS-S01 | 過場的聲音空間留給演出 |
| SLICE-d-12 | 音檔格式 | 環境音與配樂轉 OGG（循環），短音效留 WAV | 長音檔約縮到 1/10；短音效延遲最低 |
| SLICE-d-13 | 驗收 | 聲音展示影片＋手把從頭玩一次 | 先聽重點段落，再從頭玩確認整體 |
| SLICE-d1a-2 | 不同種前兆同一幀 | 可招架與不可招架同時出現時兩個都播；節流只對同一種（Brian 2026-10-20，最終審查提問） | 兩種前兆的應對不同，玩家都要聽到 |
| SLICE-d1a-3 | 結尾房 | 靜音（沒有環境音）（Brian 2026-10-20，最終審查提問） | 結尾畫面留白 |
| SLICE-d1a-1 | 架構 | 全域聲音單例 `Audio`（autoload）＋資料表；`feedback.play()` 轉呼叫 `Audio`，資料表沒有的 id 回退到合成佔位 | 環境音與配樂跨房間不斷；d1b 只補資料、不改接入點 |

## 範圍

### 架構

| 檔案 | 職責 |
|---|---|
| `core/audio/audio.gd`（autoload `Audio`） | 開機時建匯流排與播放器池；`play(id, pos := null)`（短音效）、`has_sound(id)`、`set_ambience(id)`、`play_music(id)`／`stop_music(fade)`、距離層更新 |
| `core/audio/sound_table.gd` | 純資料：`SOUNDS := {id: {files: [...], bus, volume_db}}`、`THEME_AMBIENCE`（房間 theme → 環境音 id）、混音常數 |
| `art/audio/` | 正式音檔：環境音與配樂為 OGG（匯入設成循環），短音效為 WAV；來源 WAV 留在 `assets-test/` |

- **匯流排**：`Master` 底下 `Music`、`Amb`、`Sfx`、`Tell`。`Music`、`Amb` 各掛一個 `AudioEffectCompressor`，sidechain 接 `Tell`（前兆一響，配樂與環境音被壓低）。`Sfx` 不被壓（AUDIO_SPEC 第 7 節：玩家自己的動作回饋排第 2）。匯流排在 `Audio._ready()` 用程式建（不另存 `.tres`，和專案程式驅動的做法一致）。
- **變體**：`files` 有多個時隨機選，不連續重複同一個。
- **新舊銜接**：`feedback.play(id)` → `Audio.has_sound(id)` 為真就交給 `Audio.play(id)`；否則照舊播 `sfx.gd` 的合成佔位。接入點的寫法不變；d1b 只在 `SOUNDS` 補檔名。
- **前兆節流**：同一種前兆在 0.15 秒內只播一次（關門戰多隻敵人同時前搖時不疊成一團）。

### 環境音

- 房間 theme 對到環境音：`home`、`field` → AMB-02；`yard` → AMB-03；`forest` → AMB-01；Boss 段落（沒有 theme）→ AMB-01。對照表寫在 `sound_table.gd` 的 `THEME_AMBIENCE`（房間資料不加新欄位）。
- `room_flow` 換房時呼叫 `Audio.set_ambience(id)`：id 相同就不動、不重啟；不同就在 1.5 秒內交叉淡化。
- 回主選單時環境音淡出；主選單本身沒有聲音（d2 再決定）。結尾房（`kind` 為 `ending`）靜音（SLICE-d1a-3）。

### 距離層（掛在 `Amb`，每幀更新）

| 層 | 音檔 | 來源 | 音量 |
|---|---|---|---|
| 玻璃顫音 | `amb_01_forest_glass` | 目前房間裡活著的假光造物（三種都算）；Boss 段落不算 | 最近一隻在 300 px 內為最大、900 px 以外為 0，中間線性；沒有來源為 0 |
| 危險嗡聲 | `voc_danger`（循環） | 目前房間的地上荊棘（`hazard.gd`） | 最近一處在 150 px 內為最大、600 px 以外為 0 |

### 觸發點

| 時機 | 聲音 | 接在哪裡 |
|---|---|---|
| 一般敵人進入前搖 | `parryable` 為真：`tell_parry`；否則 `tell_heavy`（`Tell`） | `enemy.gd` 切到 `State.TELEGRAPH` 的地方 |
| Seven Macaw 前搖訊號出現 | `signal_kind` 從 `NONE` 變成 `PARRY`／`UNPARRY` 時同上 | `seven_macaw.gd` 每幀比對目前招式的 `signal_kind` |
| Seven Macaw 各招與過場 | 19 種 `boss_sm_*`＋`evt_cover`，依 MV-ASSET-007 的用途一對一接 | 各招式腳本（`moves/*`）、宮殿過場（`toothache`、`teeth`、`death`） |
| 假光造物碎裂 | `voc_glass`（取代合成 `shatter`） | 資料表對應，接入點不改 |
| 跟祖母、老夫婦、老鼠互動 | `voc_alive` | `game_world._on_interacted` |
| 篝火休息 | `voc_real` | 休息流程 |
| Boss 各段 `FIGHT` 開始 → 離開 `FIGHT` | MUS-B01 淡入 1 秒（從頭播）→ 淡出 1.5 秒 | `boss_fight` 的 stage 切換 |
| 覺醒過場 | MUS-S01 | `awaken.gd` |

### 混音初始值（寫在 `sound_table.gd` 開頭，試聽後再調）

| 項目 | 值 |
|---|---|
| 匯流排 | `Tell` 0 dB、`Sfx` −3 dB、`Music` −8 dB、`Amb` −12 dB |
| 距離層最大音量 | −14 dB（相對 `Amb`） |
| 前兆時的 sidechain 壓低 | 約 6～8 dB，0.3 秒內恢復 |

### 轉檔

- `ffmpeg` 把 3 個環境音、玻璃層、MUS-B01、MUS-S01 轉成 OGG Vorbis（`-q:a 6`），放進 `art/audio/`；循環的在 `.import` 設 `loop=true`。
- 量測並寫進執行報告：循環接縫（最後一幀與第一幀的樣本差）、整體響度與原 WAV 差 ≤ 1 LU。
- 短音效（語彙、Seven Macaw、事件）原樣複製 WAV。

### 不做（d1b 或之後）

- 新音效：腳步、跳躍、翻滾、武器揮擊與命中、招架、受擊、治療、換人、與祖母交換、可可豆、碎片、技能槽、老鼠突襲、工具自己動、地面三個事件與 c2 過場缺的動作音、介面（d1b；素材工單 MV-ASSET-021）。
- 聆聽機制與「聆聽時淡出配樂」（MV-PROTO-006）。
- 音量設定選單（SLICE-4 不做設定選單）。
- 標題畫面的聲音（d2）。

## 自測

1. 資料表：`SOUNDS` 每個 id 的檔案都存在、載得進來；`bus` 都是 `Music`／`Amb`／`Sfx`／`Tell` 之一。
2. 匯流排：開機後 5 條匯流排都在；`Music`、`Amb` 的壓縮器 sidechain 是 `Tell`。
3. 環境音：每個房間都對得到環境音 id；同 id 換房不重啟；不同 id 交叉淡化，淡化結束後只剩一個在播。
4. 前兆：一般敵人進前搖時 `Tell` 播出對應的前兆（可招架／不可招架各測一次）；Seven Macaw 的 `signal_kind` 改變時同樣播出；0.15 秒內不重播。
5. 變體：同一個 id 連播兩次不會選到同一個檔（變體數 ≥ 2 的）。
6. 配樂：Boss 進 `FIGHT` 時播 MUS-B01、離開時淡出、覺醒時播 MUS-S01。
7. 距離層：沒有來源時為 0；來源在最近距離時為最大；最後一隻假光造物死掉後回到 0。
8. 回退：資料表裡沒有的 id（例如 `swing`）仍播合成佔位，不會變成靜音。
9. 全套自測全過（基準 602＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`。

自測在 headless 下跑（dummy audio driver）；只驗「該播的有播、該停的有停、音量對」，聽感由驗收負責。

## 風險與退路

| 風險 | 退路 |
|---|---|
| sidechain 壓縮的效果不明顯 | 改成前兆播放時用 tween 把 `Music`、`Amb` 降 6 dB 再回來 |
| 環境音轉 OGG 後循環接縫有爆音 | 用匯入的 loop offset，或 `ffmpeg` 在首尾做極短交叉淡化 |
| `voc_danger`（約 2 秒）不是為循環做的，循環時有接縫 | 首尾交叉淡化；仍不順就改成每 1.5 秒重新觸發一次 |
| 前兆太頻繁、太吵 | 節流時間可調；必要時同時只播一個前兆 |
| headless 測不到真實播放 | 自測檢查播放器狀態與音量；聽感靠影片與手把驗收 |

## 驗收標準

實作完成（AI）：

- [x] 自測全部通過，沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`／`body->get_space`（629／0）
- [x] 轉檔量測（接縫、響度）寫進[執行報告](../../report/MV-SLICE-001d1a_聲音系統_2026-10-20_0116_執行報告.md)
- [x] 錄聲音展示影片（`assets-test/d1a_video/d1a_sound_tour.mp4`，161 秒，-16.6 LUFS、-1.8 dBTP）：地面換房、森林戰鬥（前兆、碎裂、玻璃層）、荊棘、篝火、Boss 三段與覺醒

驗收（Brian）：

- [x] 聽影片——2026-10-20「影片可以」
- [x] 手把從頭玩到結尾——2026-10-20 試玩 d1a 版（紀錄沒有錯誤），再試玩含 d1a 的 d1b 版：「試玩可以」：前兆每次都聽得到嗎？有沒有刺耳或太小聲的？換房間的聲音順不順？

## Git Commit

分支 `feature/MV-SLICE-001d1a_聲音系統`（從 `develop` `3d8d08f` 開）：
