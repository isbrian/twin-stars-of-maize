# MV-SLICE-001c1 Boss 特效正式化

更新時間：2026-10-14

## 基本資訊

| 項目 | 內容 |
|------|------|
| 分支 | `feature/MV-SLICE-001c1_特效`（從 `develop` `1742aa4` 開） |
| 影響範圍 | `game/`（新增 `world/fx/` 與 `--fx-view` 展示；`core/boss/light_source.gd`、`pillar.gd`、`moves/beam.gd`（或畫光束的地方）、`seven_macaw.gd`、`ui/whiteout.gd` 只加 `fx_drawn` 旗標判斷；`core/boss/boss_fight.gd` 在遊戲模式掛特效；`world/scenery_view.gd` 宮殿假光）、`tools/rig_src/sevenmacaw_joints.json`（加身上光點 `points`）與重新匯入的 rig json |
| 上層 | [MV-SLICE-001 總規格](MV-SLICE-001_垂直切片.md)：子專案 c 拆成 c1 特效（本文件）→ c2 Boss 過場 → c3 地面事件；內容量另開子專案 |
| 前置 | MV-SLICE-001b2b2（已合併） |
| 引擎 | Godot 4.7.2 |
| 狀態 | 規格 Brian 2026-10-14 核准；實作計畫待審 |

## 背景與目的

垂直切片是作品集展示用（SLICE-1）。Seven Macaw 的特效目前都是程式畫的灰盒形狀；戰鬥靠讀招，特效就是招式的可讀性。c1 把 Boss 專屬的特效做成正式品質，並提供「光一點一點熄滅」的效果給 c2 的死亡演出使用。

## 盤點（2026-10-14，AI 實查）

| 特效 | 現在 | 時序與判定（不改） |
|---|---|---|
| 光源（`core/boss/light_source.gd`） | 熄滅＝暗色小圓；微亮＝脈動小光點；最亮＝白圓＋8 條放射線＋擴散光環 | 狀態 OFF／GLOW／BRIGHT 由 Boss 決定 |
| 假光閃耀（`moves/false_flash.gd`、`ui/whiteout.gd`） | 前搖只有展翅動作、沒有聚光畫面；白茫＝整片均勻白 | `flash_telegraph`；白茫 `whiteout_in`／`whiteout_hold`／`whiteout_out`、最大白度 0.9（`Whiteout.alpha_at`） |
| 寶座反光柱（`core/boss/pillar.gd`） | 落點白圓＋細線 → 白色長方形 | `pillar_warn` → `pillar_active`；判定 `SIZE` 120×960 |
| 眼中光束（`moves/beam.gd`） | 蓄力只有眼睛微亮；光束＝白色長方形 | `beam_charge`（1.2 秒）→ `beam_active`（0.5 秒）、離地 `beam_band`；判定矩形＝Boss 前緣到場地邊界 |
| 場地變暗（`world/scenery_view.gd` `set_darkness`） | 整個場景圖層依 `lights_removed` 調暗 1.0／0.75／0.5／0.3 | `boss_fight._apply_lights` 呼叫 |
| 身上的光、光熄滅 | 沒有 | — |

- 慣例：`core/` 的玩法節點自己畫灰盒；遊戲模式（`boss_fight` 的 `gs != null`）由 `world/` 掛外觀並用旗標關掉灰盒（`portrait_drawn`）。
- 宮殿的「火光」是篝火（`RestPoint`），不在場景圖層裡，`set_darkness` 不會調暗它。
- Boss 衝撞寶座的前搖已顯示暗紫鋸齒（不可招架），反光柱落點不必重複。

## 定案（Brian，2026-10-14）

| ID | 議題 | 決定 | 理由 |
|---|---|---|---|
| SLICE-c-1 | c 的拆法 | c1 特效 → c2 Boss 過場 → c3 地面事件，各自規格→計畫→實作 | 三塊互相獨立；特效影響戰鬥可讀性、不依賴新動作，先做 |
| SLICE-c-2 | 內容量不足（約 10 分半 → 30 分鐘） | 另開子專案（c 之後、d 之前） | 補房間、敵人、事件長度是關卡設計，和演出特效無關；演出做完再計時更準 |
| SLICE-c-3 | 通關後存檔 | 歸 c2 | 問題出在覺醒到結尾之間沒有篝火，正是 c2 要重做的演出 |
| SLICE-c1-1 | 做法 | 程式繪製（漸層光暈、加亮混合、少量光點），不開美術工單 | 光效本來就是程式效果，可以和招式時序精準同步、隨時微調 |
| SLICE-c1-2 | 範圍 | 只做 Boss 特效（不含一般戰鬥訊號） | 符合總規格的 c 範圍 |
| SLICE-c1-3 | 光熄滅 | c1 做效果、c2 演出時觸發 | 和光源、場地變暗同一套光的做法 |
| SLICE-c1-4 | 驗收 | 影片＋手把試玩 | 特效是招式可讀性，要實際打才知道 |
| SLICE-c1-5 | 光源 | A 柔光暈 | 和角色的手繪感最搭、不搶畫面 |
| SLICE-c1-6 | 假光閃耀 | A 光點匯聚 → 白光從他身上擴散 | 看得出光是他發出的，下次知道要背對他 |
| SLICE-c1-7 | 反光柱 | A 柔光光柱 | 和其他光效同一套語言；實心邊界清楚 |
| SLICE-c1-8 | 眼中光束 | A 瞄準虛線＋柔光光束 | 地面虛線預告高度與範圍，知道要跳 |
| SLICE-c1-9 | 場地變暗 | A 宮殿假光一組組熄、火光留著 | 照設計文件「假光暗一階、死亡後只剩火光」的字面 |
| SLICE-c1-10 | 身上的光與熄滅 | A 金飾光點一顆顆熄 | 「一點一點熄滅」；平常也有「華麗而空洞」的假光閃爍 |
| SLICE-c1-11 | 架構 | `world/fx/` 另掛特效外觀，core 加 `fx_drawn` 旗標關灰盒 | 和骨架取代立繪同一套慣例；玩法程式幾乎不動；原型模式照舊灰盒 |

示意畫面（不進版控）：`.superpowers/brainstorm/64043-1791919582/content/`（`light-source.html`、`false-flash.html`、`pillar.html`、`beam.html`、`darkness.html`）。

## 範圍

### 特效

| 特效 | 樣子 | 時機與約束 |
|---|---|---|
| 光源 | 暖白色加亮光暈。微亮：小光暈，0.5 秒週期呼吸（大小與透明度）；最亮：大片光暈（中心白、外圍金）＋柔和擴散光環（約 0.9 秒一圈）；熄滅：暗色小點（位置看得到、沒有光） | 跟著 `light_source.state`；光暈畫在光源位置（跟著頭骨上的光點） |
| 假光閃耀前搖 | 周圍飄出 8～12 個細小光點往他身上聚、身上光暈越來越強；**不畫圓形或鋸齒**（那是招架訊號） | `flash_telegraph` 期間，強度隨前搖進度 0 → 1 |
| 白茫 | 白光從他的畫面位置向外擴散，在 `whiteout_in` 內蓋滿全畫面，維持、淡出 | 任何時刻全畫面的平均白度 ≥ `Whiteout.alpha_at`（不比現在看得更清楚）；維持段全畫面 0.9；淡出照原曲線 |
| 反光柱落點 | 地上一團會閃的光斑（寬＝柱寬）＋從上到下的虛線 | `pillar_warn` 期間 |
| 反光柱 | 中心白、兩側金、往下流動的光帶，外圍一層薄柔光 | `pillar_active` 期間；**實心部分寬度＝判定寬度 120 px**，柔光每邊 ≤ 8 px 且半透明 |
| 光束蓄力 | 眼睛是微亮柔光暈（同光源）；地上閃出一條虛線，標出光束的高度與範圍 | `beam_charge` 期間；虛線＝判定矩形的中線、範圍相同 |
| 光束 | 眼睛到光束起點的斜向亮線（不算判定）；貼地光束：中心白、上下金邊、往前流動，外圍薄柔光 | `beam_active` 期間；**實心矩形＝判定矩形** |
| 場地變暗 | 宮殿牆上金飾、寶座各有假光光暈，分 3 組；`lights_removed` 每加 1，熄掉一組（0.8 秒淡出）；場景暗度數值照舊（1.0／0.75／0.5／0.3）；篝火不受影響 | `_apply_lights` 時；讀檔或重試直接到該段時，假光狀態直接對應（不播淡出） |
| 身上光點 | Seven Macaw 金飾、寶石上約 10 個閃爍小光點（各自週期、錯開），全身一層淡淡的假光光暈 | 遊戲模式一直有；跟著骨頭動；換頭不受影響（光點不在頭上） |
| 光熄滅 | `extinguish(seconds)`：光點從翅膀尖往胸口依序熄滅，光暈同時淡到 0，身體顏色變暗（約 ×0.5） | c1 只提供效果與測試；c2 決定何時呼叫 |

- 最暗一階（0.3）也要看得清光源（設計文件 2.5；前搖訊號不在 c1 範圍、沒有改動）。
- 所有特效不改任何玩法數值、時序、判定。

### 不做

- 一般戰鬥訊號（前搖輪廓、招架圓形、不可招架鋸齒、招架光環、裂紋、命中光屑、擊倒碎片）
- 死亡演出本身（c2）、Boss 過場（c2）、地面事件（c3）、聲音（d）

## 架構

- 新增 `game/world/fx/`：每個特效一支外觀腳本（例如 `light_fx.gd`、`flash_fx.gd`、`pillar_fx.gd`、`beam_fx.gd`、`palace_lights.gd`、`macaw_glints.gd`），讀對應 core 節點的狀態來畫；共用的光暈貼圖（`GradientTexture2D` 放射狀）與加亮混合材質集中一處。
- core 節點加 `var fx_drawn := false`：為 true 時不畫灰盒（光源、光柱、光束、白茫；Seven Macaw 的灰盒身體已由 `portrait_drawn` 關掉）。
- `boss_fight` 在遊戲模式（`gs != null`）掛上各特效並設 `fx_drawn = true`；原型模式不掛、照舊灰盒。
- 身上光點：`tools/rig_src/sevenmacaw_joints.json` 的 `points` 加 `glint_1`…`glint_N`（掛翅膀、軀幹、尾羽的骨頭），`cut_rig.py`／`import_rig.py` 重新產生 rig json（分件 PNG 不變）；`rig_view.point()` 取位置。
- `MacawGlints.extinguish(seconds)`：熄滅順序依光點離胸口的距離由遠到近。
- 展示：新增開發用參數 `--fx-view`（同 `--rig-view`：1920×1080 的 SubViewport、`--frames` 逐格輸出、彩色一輪＋灰階一輪），在宮殿與 nance 場景依序播放光源三種狀態、假光閃耀前搖與白茫、反光柱、光束、場地三次變暗、身上光點與熄滅；用來錄驗收影片。

## 自測（新增 `game/tests/test_fx.gd`）

1. 遊戲模式：光源、光柱、光束、白茫的 `fx_drawn` 為 true、特效節點存在；原型模式為 false、沒有特效節點
2. 反光柱：特效實心寬度＝判定寬度（120 px），柔光每邊 ≤ 8 px
3. 光束：特效實心矩形＝判定矩形；蓄力虛線在判定矩形的中線、範圍相同
4. 白茫：取樣多個時刻，全畫面平均白度 ≥ `Whiteout.alpha_at`，維持段＝0.9
5. 假光閃耀前搖：強度隨進度單調增加；沒有圓形或鋸齒訊號
6. 場地變暗：`lights_removed` 0～3 時，亮著的假光組數為 3、2、1、0；篝火的 `modulate` 不變；直接設定段落時不播淡出
7. 身上光點：遊戲模式有 N 個、跟著骨頭（擺姿勢後位置＝`rig.point(glint_i)`）；換頭後數量不變
8. `extinguish()`：結束時亮著的光點為 0、光暈為 0；過程中熄滅順序由遠到近
9. 最暗一階的可讀性：場景暗度 0.3 時，光源微亮光暈中心的灰階亮度 − 宮殿場景（×0.3）的平均灰階亮度 ≥ 0.4
10. 全套自測照舊全過（目前 357 項＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`

## 風險與退路

| 風險 | 退路 |
|---|---|
| 加亮光暈太多、`--shots` 掉到 60 fps 以下 | 光暈用預先產生的貼圖、不用 shader；光點數量減半；仍不夠就關掉光環動畫 |
| 擴散式白茫在淡入初期比現在「看得更清楚」，變簡單 | 測試 4 保證平均白度不低於原曲線；不足就提高擴散速度 |
| 光柱、光束的柔光被誤認成判定 | 柔光每邊 ≤ 8 px、半透明；實心邊界清楚；手把試玩確認 |
| 身上光點和光源（弱點）混淆 | 光點比光源小、偏金色、不放在頭上；光源是唯一會「微亮呼吸」與「最亮爆開」的光 |
| 加 `points` 後 rig json 變動影響既有測試 | 分件 PNG 不變；只多 `points`，既有光點（jaw、teeth、eye）不動 |

## 驗收標準

實作完成（AI）：

- [x] `tools/test_cut_rig.py`、`tools/test_import_art.py` 全部通過；`python3 tools/import_art.py --check`、`python3 tools/import_rig.py --check` 結束碼 0
- [x] 自測全部通過（357 項＋新增），沒有 `SCRIPT ERROR`／`Parse Error`／`flushing queries`
- [x] `--shots` 每個畫面平均 60 fps（含三個 Boss 畫面）
- [x] 用 `--fx-view` 錄特效影片（彩色與灰階），AI 抽格看光源兩級、聚光與白茫、光柱、光束、場地變暗、身上光點、熄滅

驗收（Brian）：

- [x] 看影片：特效的樣子（Brian 2026-10-14 看過、同意合併）
- [ ] 手把試玩：三段 Boss 戰時讀得懂招式（光源、閃耀、光柱、光束），最暗一階也看得清（未另外回報）

## Git Commit

分支 `feature/MV-SLICE-001c1_特效`（從 `develop` `1742aa4` 開）：

| Commit | 內容 |
|---|---|
| `d9537f5`、`935ff5c` | 規格書、實作計畫 |
| `0ab0f89` | Task 1：特效基底（`fx_kit`）與光源柔光暈 |
| `ef06208` | Task 2：反光柱與光束 |
| `73c85b9` | Task 3：假光閃耀的聚光與白茫 |
| `466633d` | 光暈貼圖先被畫過也讀得到像素（Task 4 發現的 Task 1 缺陷） |
| `2efcd38` | Task 4：宮殿假光逐段熄滅 |
| `0ed0d02` | Task 5：身上光點與熄滅 |
| `c03fac8` | Task 6：`--fx-view` 展示、影片、文件 |
| 最終審查修正 | 樹冠上的聚光移進畫面；展示畫面改用實戰位置、重錄影片（commit 見 git log） |

驗證（2026-10-14，最終審查修正後）：自測 377／0、`SCRIPT ERROR`／`Parse Error`／`flushing queries` 0；兩個 `--check` 結束碼 0；unittest 38 項 OK；`--shots` 11 個畫面 16.17～16.30 ms；影片 `assets-test/c1_video/c1_fx.mp4`（1920×1080、30 fps、1599 格、53.3 秒，完整解碼無誤）。
