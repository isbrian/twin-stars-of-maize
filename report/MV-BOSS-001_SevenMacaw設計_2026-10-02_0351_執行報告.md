---
type: task-report
id: MV-BOSS-001
name: Seven Macaw Boss 設計
status: ✅ 完成
retry_count: 0
pause_reason: "-"
started_at: 2026-10-01_2305
completed_at: 2026-10-02_0351
generated_at: 2026-10-02_0351
---

# MV-BOSS-001 Seven Macaw Boss 設計：執行報告

## 基本資訊

| 項目 | 內容 |
|---|---|
| 任務 ID | MV-BOSS-001 |
| 類型 | 文件任務（不開 feature 分支） |
| 分支 | `develop` |
| 狀態 | ✅ 完成 |
| 經過 | 2026-10-01 問完 BOSS-1～5 後交接暫停（接手文件 `~/.claude/plans/session-handoff-2026-10-01_2354.md`）；2026-10-02 新 session 接續 BOSS-6～9 並完成 |

## 需求說明

依 [原型驗證計畫](../docs/design/MV-PROTO-000_原型驗證計畫.md) 第 3 節，以 brainstorming 一次一問定案 Seven Macaw 的三段設局要素、視覺線索、破綻條規則、招式表、演出，作為 MV-PROTO-003 的依據。

## 產出

| 檔案 | 動作 | 內容 |
|---|---|---|
| [docs/design/MV-BOSS-001_SevenMacaw設計.md](../docs/design/MV-BOSS-001_SevenMacaw設計.md) | 新增 | 定案表（BOSS-1～9，共 23 題）、整體流程、共通規則、三段設局、招式表、演出、重試、美術與聲音需求、原典依據與改編、交給原型的問題 |
| [CULTURAL_PRINCIPLES.md](../CULTURAL_PRINCIPLES.md) | 更新 | 改編清單新增 6 項（牙痛發狂、老夫婦待命、換牙與摘眼之間的戰鬥、斷臂只能吹箭、前往宮殿的路程、手臂裝回後覺醒） |
| [ART_SPEC.md](../ART_SPEC.md) | 更新 | Seven Macaw 動作清單與 4 種外觀狀態；角色加 Chimalmat；場景加宮殿與小徑；Seven Macaw 專用特效 |
| [VISION.md](../VISION.md) | 更新 | 6.5 重試加註：分兩個場地的 Boss 以場地為單位重來 |
| [docs/design/MV-PROTO-000_原型驗證計畫.md](../docs/design/MV-PROTO-000_原型驗證計畫.md) | 更新 | MV-BOSS-001 加結果連結；MV-PROTO-003 範圍依設計展開 |
| [README.md](../README.md) | 更新 | 設計文件表加入 Seven Macaw 設計 |
| [todo/todo.md](../todo/todo.md) | 更新 | MV-BOSS-001 改為完成；MV-ASSET-003 說明補上 Chimalmat、宮殿、4 種外觀 |

## 執行紀錄

### Brian 的決定

全部 23 題都選了推薦選項；BOSS-6-2d 回「1+2」（合併兩個選項），補問上限後定為各 1 隻。

| 編號 | 問題 | 決定 |
|---|---|---|
| BOSS-1～5 | 結構、斷臂、過場、老夫婦、破綻 | 見設計文件定案表（2026-10-01） |
| BOSS-6-1 | 招式的關係 | 招式家族、逐段變形 |
| BOSS-6-2a～d | 第 1 段 | 他下來你上去打；吃果子時下顎微亮；背對假光閃耀；召喚爬行＋飛行各 1 |
| BOSS-6-3a～d | 設局之箭、第 2 段 | 只有 Hunahpu 能觸發、破綻滿時自動換人；落地狂亂；哀嚎時玉牙微亮；衝撞寶座震出反光柱 |
| BOSS-6-4a～b | 第 3 段 | 光束蓄力時眼睛微亮、射中打斷；召喚各 2 |
| BOSS-7a～b | 轉場、重試 | 短對話＋可走的路；兩個門口各一個休息點 |
| BOSS-8 | Chimalmat | 宮殿裡出現、不參戰，結尾隨他倒下 |
| BOSS-9a～d | 演出 | 換牙約 5 秒留一句哀求；呆望、光熄滅、靜靜倒下；覺醒後在宮殿出口當場使用；約 5 秒埋伏開場 |

### 原典查證（Christenson，`sources/PopolVuh.txt`）

| 內容 | 頁碼 | 對設計的影響 |
|---|---|---|
| 射中下顎的是 Hunahpu | p.82～83 | BOSS-6-3a 只有 Hunahpu 的箭能觸發 |
| 雙胞胎躲在 nance 樹下的葉叢 | p.82 | BOSS-9d 埋伏開場 |
| 手臂被帶回家、掛在火上 | p.83 | 宮殿背景的手臂、結尾取回 |
| Chimalmat 是 Zipacna、Cabrakan 的母親 | p.80 | BOSS-8 的伏筆理由 |
| 他坐在寶座邊上牙痛哀嚎、主動求治 | p.84～85 | BOSS-4 的「發狂」確定是改編；BOSS-9a 留一句哀求 |
| 換牙後「臉垮了」；摘眼時「只是呆望」；Chimalmat 隨之死去；手臂裝回 | p.86 | BOSS-9b、9c |

### 發現並同步的不一致

- ART_SPEC 原本只有 3 種外觀狀態、Boss 房只有大樹，BOSS-1 需要 4 種狀態與宮殿 → 已更新。
- 草案的「躲到樹幹後」與 ART_SPEC「假光不產生影子」衝突 → BOSS-6-2c 改為背對。
- 吹箭兩兄弟都能用，斷臂後 Hunahpu 可能形同下場 → BOSS-6-3a 以「只有 Hunahpu 能觸發＋自動換人」解決。

### 我自行決定、需要 Brian 知道的細節

- **Chimalmat 那句話的位置**：BOSS-8 定案寫「第 2 段開場說一句『你帶了什麼回來？』」，但原典這句是他剛回到家時問的（p.83），雙胞胎帶老夫婦抵達時他已到家很久。設計文件把這句放在斷臂過場的最後一個鏡頭（他把手臂掛上火時），第 2 段開場她只在寶座旁出現。要照原定放回第 2 段開場，改設計文件第 5 節一格即可。
- **轉場小路不放敵人**：BOSS-7a 原文是「沒有或只有少量小怪」，為了避免玩家死在兩個休息點之間、進度不明，設計文件選「不放」。
- **斷臂期間的動物技能**：BOSS-2 只說「武器槽停用，吹箭仍可用」，沒有提到動物技能。設計文件預設照常，列為 MV-PROTO-003 待確認。

### 收尾驗證

- 相對連結：以 Python 掃描本次新增與修改的 8 個 Markdown 檔（`git -c core.quotepath=false`，避免中文檔名被引號包住而漏掃），85 個相對連結全部存在。
- Mermaid：設計文件第 1 節流程圖以 `mmdc` 實際渲染成 SVG，無錯誤。
- 設計文件自檢：搜尋 TBD／TODO／待定無結果；定案表與內文各節逐項對照無矛盾。

## 交接備註

- MV-PROTO-003 的前置還差 MV-PROTO-002；MV-ASSET-003 的前置 MV-BOSS-001 已滿足，還差 MV-PROTO-001。
- AUDIO_SPEC 的 Seven Macaw 一欄仍寫「依 Boss 設計」，聲音需求已列在設計文件第 7 節，留給 MV-ASSET-003 一併寫進音訊清單。
- 本次 commit 只在 develop，尚未 push。
