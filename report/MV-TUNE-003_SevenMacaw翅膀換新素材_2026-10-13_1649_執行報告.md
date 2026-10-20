---
type: task-report
id: MV-TUNE-003
name: Seven Macaw 翅膀換新素材
status: ✅ 完成
retry_count: 0
pause_reason: "-"
started_at: 2026-10-13
completed_at: 2026-10-13_1734
generated_at: 2026-10-13_1649
---

# MV-TUNE-003 Seven Macaw 翅膀換新素材：執行報告

## 基本資訊

| 項目 | 內容 |
|---|---|
| 任務 ID | MV-TUNE-003 |
| 分支 | `feature/MV-TUNE-003_SevenMacaw翅膀換新素材`（從 `develop` `9232b5b` 開），未合併、未推送 |
| 規格 | [規格書](../todo/spec/MV-TUNE-003_SevenMacaw翅膀換新素材.md)（TUNE3-1～4）、[實作計畫](../todo/spec/MV-TUNE-003_SevenMacaw翅膀換新素材_實作計畫.md) |
| 狀態 | ✅ Brian 2026-10-13 看影片驗收通過；本機合併回 `develop`（未推送） |
| 重試次數 | 0 |

## 需求說明

b2b1 的 Seven Macaw 從單張立繪切件，近側翅膀和身體畫在一起，只能上舉約 3°。MV-ASSET-016 把身體（W-01，無翅膀）和近側翅膀（W-02）分開畫；本工單改從兩張圖切，讓翅膀真的拍起來。

## 實作內容

| Task | Commit | 內容 |
|---|---|---|
| 1 切件工具 | `4d97b5e` | `cut_rig.py` 新增 `layers`（某幾根骨頭改從另一張圖切，兩點對位）、`erase`（多邊形內當背景） |
| 2 重切 | `6472a99` | `sevenmacaw_joints.json` 改讀 W-01＋W-02；新增 `overlap`（單向重疊）；合成圖匯入成 `enm_sevenmacaw_rest.png` 當比對基準；`BODY` 重量 |
| 3 拍翅 | `d359dc8` | `sevenmacaw_anims.json` 的近側／遠側翅膀角度；新測試 `test_macaw_wings_flap`、`test_macaw_no_shoulder_hole` |
| 4 影片與文件 | 本次 | 重錄影片、README／ART_SPEC／規格書／todo |

### 每個動作最後的 `wing_arm` 範圍（負＝上抬）

| 動作 | 範圍 | 規格目標 |
|---|---|---|
| `fly` | −30 ～ +24 | 約 −30 ↔ +20 |
| `flail` | −30 ～ +26 | 約 −30 ↔ +20 |
| `dive` | −26 ～ 0（衝刺格 −26） | 約 −25 以上 |
| `spread` | −28 ～ 0 | 張到上限附近 |
| `wail` | −28 ～ −24 | 張到上限附近 |
| `fall` | −30 ～ −10 | 往上張 |
| `stagger` | −24 ～ 0 | 往上張 |
| `idle_perch` | −5 ～ +3 | ≥ −8 |
| `idle_ground` | −3 ～ +5 | ≥ −8 |
| `eat`、`throw`、`beam`、`down` | +3；0～+7；0～+18；+6～+20（未改） | ≥ −8 |

遠側翅膀 `wing_arm_l` ≈ −0.5 × `wing_arm`（反向擺動）。上抬目標 30° 全部用到，沒有因為露縫而降角度，也不需要加 `caps`。

## 判斷與決定（Rulings）

| # | 決定 | 理由 | 做錯的代價 |
|---|---|---|---|
| 1 | 翅膀骨頭 z 改 12／11／10（原 6／5／4） | 翅膀變成獨立圖層後，原本的 z 會讓近側翅膀跑到身體後面 | 只改 z |
| 2 | `polys` 也作用在圖層骨頭 | 只靠距離分會把飛羽直線切開 | 一個 helper＋測試 |
| 3 | 合成圖用 `fit_height: 450` 匯入，不是 `scale_like` | 合成圖內容高 942、原圖 946，`scale_like` 會差 0.4% | 一筆匯入設定 |
| 4 | 新增切件選項 `overlap`（單向重疊） | 翅膀分開後，脖子後方的金色披肩羽依距離分給了脖子和頭，轉頭時會跟著轉並露出底色；`caps` 是雙向的，會讓脖子又帶走披肩羽 | 一個欄位＋3 行 |
| 5 | torso poly 蓋住披肩羽；torso overlap 墊在脖子邊緣下方（上緣截在 y 300）；pelvis overlap 墊在腹部接縫；wing_fore 下緣 620→640 | 轉頭與轉身時不露底色；截在 y 300 是為了不讓看不見的墊底像素把受擊框拉高 23 px；wing_fore 下緣原本把一段墨線切到 wing_arm | 只改 joints 資料 |
| 6 | `BODY` = `Rect2(-154, -327, 272, 327)`（原 `-153, -317, 271, 317`） | 披肩羽現在屬於 torso，是看得見的身體；量到 (-154.11, -327.23, 272.08, 326.73) | 受擊框上緣高 8 px |
| 7 | `test_macaw_no_shoulder_hole` 的方框半邊用 30 遊戲 px（計畫寫 60） | 60 會包進頭冠與翅膀之間的天空凹口，遠側翅膀一抬就把凹口封住、被算成洞，導致現有角度就量到 894 px | 離肩膀 30～60 px 的接縫只靠檢查圖確認 |

## 驗證（fresh evidence，2026-10-13）

| 項目 | 結果 |
|---|---|
| 自測 `MIN_PASS=336 bash /tmp/wt/b2a_verify.sh` | 336／0，`SCRIPT ERROR`／`Parse Error`／`flushing queries` 0 次 |
| `import_rig.py --check`、`import_art.py --check` | 兩個結束碼都是 0 |
| `tools/test_cut_rig.py`＋`tools/test_import_art.py` | 37 項 OK |
| crawler、flyer | 從 `9232b5b` 起沒有任何變更 |
| `--shots` | 第一次：`home` 16.89 ms，其餘 10 個 16.14～16.30 ms；第二次：11 個全部 16.17～16.30 ms（`home` 16.17）。第一次的 `home` 是第一個畫面的暖機波動 |
| 肩膀檢查圖（遊戲尺寸 ×2；fly#0、flail#8、fall#2、spread#5、dive#8） | 肩膀 ±30 px 內封閉透明 0 px；±60 內的紅色區塊確認是頭冠與翅膀之間的天空 |
| 換頭檢查圖（脖子 −15°／頭 −12°；實際最大 down 末幀、eat） | 實際最大角度乾淨；−15° 檢查姿勢在頭頸交界上方有一個小缺口（約 10×17 遊戲 px），遊戲裡的動作不會轉到這個角度 |

## 影片與 AI 抽格

- 影片：`assets-test/tune003_video/tune003_rigs.mp4`（1920×1080、30 fps、7528 格、250.9 秒，完整解碼沒有錯誤）
- Seven Macaw 段落：彩色約 0:41～2:05，灰階約 2:46～4:11（四種頭依序各播一輪全部動作）
- 抽格（每 0.5 秒，含左下標籤，共 169 格）：
  - 四種頭（完整、下顎受傷、白玉米牙、失明）都依序換上
  - `dive` 衝刺、`flail`、`spread`、`wail`、`fall`、`stagger` 的近側翅膀明顯往上張；待機類幾乎不動
  - 放大 `dive` 上抬格（彩色與灰階）：肩膀接縫乾淨，光點黃點在頭上

## 驗收步驟（Brian）

```bash
open "assets-test/tune003_video/tune003_rigs.mp4"
```

1. 看 Seven Macaw 段落（0:41 起）：翅膀像在拍翅嗎？
2. `dive` 衝刺那一格翅膀幾乎豎直（−26°），會不會太誇張？
3. 待機類（樹上、地面）只加了一點呼吸感，要不要更多？

## 驗收結果

- Brian 2026-10-13 看影片：「翅膀有在拍了，可以合併」。`dive` 衝刺角度、待機幅度、頭冠羽尖沒有另外提出問題，維持現狀。

## 剩餘事項

- `develop` 尚未推送（本機領先 origin）
- 審查延後的 Minor（合成圖翅膀邊緣用取代而非疊加、`erase` 切到頭冠羽尖等）未處理，日後需要再開工單
- 換頭 −15° 檢查姿勢的小缺口：若日後動作要轉到 −15° 以上，再把 torso overlap 往上延伸（受擊框 `BODY` 會跟著變高，需同步更新）
