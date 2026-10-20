---
type: analysis-report
name: GitHub 公開上傳評估
generated_at: 2026-10-20_0223
scope: isbrian/Game-Popol-Vuh-Metroidvania（全部分支與歷史）
---

# GitHub 公開上傳評估

## 結論

**建議先維持 Private；作品集先用「下載包＋展示影片」對外**，等 d3（打包）完成、下面 4 個待決定事項有答案後，再決定公開方式。目前沒有發現「一公開就出事」的問題（沒有密鑰、原典譯本沒進版控），但有 4 件事一旦公開就很難收回，要先決定。

## 現況（2026-10-20 實查）

| 項目 | 結果 | 方法 |
|---|---|---|
| 可見性 | **Private**；舊倉庫 `isbrian/Game-Popol-Vuh` 也是 Private | `gh repo view` |
| 授權 | **沒有 LICENSE 檔** | 檢查根目錄 |
| 密鑰／token | **沒有找到**（391 個 commit、6.8 MB） | `gitleaks git --redact`（全部 ref） |
| 原典譯本 | `sources/` **從未進過版控** | 歷史中所有檔名 |
| AI 測試素材 | `assets-test/` **從未進過版控** | 同上 |
| 字型 | Noto Serif／Noto Serif TC，**附 OFL 授權文字**（`assets/fonts/OFL_*.txt`） | 檢查檔案 |
| 進版控的素材 | 1268 個檔；`game/art/` 下的圖與音檔全部是 AI 生成（ChatGPT／Codex） | `git ls-files` |
| 倉庫大小 | 打包後約 65 MB；最大的檔是 16 MB 的字型；歷史裡有原型的 `.godot/imported` 快取（只佔空間，不是風險） | `git count-objects`、歷史最大 blob |
| 作者信箱 | 408 個 commit 用 個人信箱、23 個用 GitHub noreply | `git log --format=%ae` |
| 本機特殊 ref | `refs/codex/turn-diffs/...`（Codex 的檢查點，含一個測試音檔）**只在本機**，一般推送不會送出 | `for-each-ref` |

## 公開前要先決定的事（公開後難以收回）

| # | 事項 | 為什麼 | 建議 |
|---|---|---|---|
| 1 | **授權** | 沒有 LICENSE＝保留所有權利，別人只能看、不能用；但程式、文件、AI 素材適合的授權不同 | 程式與工具：MIT；文件與 AI 素材：不授權（保留所有權利）或 CC BY-NC。AI 生成素材的著作權本身就不確定（見 [AI 素材條款與揭露](../docs/legal/AI素材條款與揭露.md)），不要對它宣稱比實際更強的權利 |
| 2 | **倉庫名稱含聖典名** | [CULTURAL_PRINCIPLES](../CULTURAL_PRINCIPLES.md)：「標題與封面不出現聖典名」。倉庫名不是遊戲標題，但公開後就是對外的名字 | 公開時改用中性名稱（例如正式標題定案後的名字，MV-TITLE-001），或另開乾淨的公開倉庫 |
| 3 | **作者信箱** | 公開後 408 個 commit 的信箱任何人都看得到，也會被爬蟲收集 | 接受；或另開公開倉庫只放快照（不帶歷史）。**不建議改寫現有歷史**（要強制推送、所有分支與 PR 對不上） |
| 4 | **英文繪本的引文** | `docs/book/MV-BOOK-002` 等英文文本裡有冥王台詞；若太貼近 Christenson 譯本的措辭，公開就有著作權疑慮 | 公開前逐句對照譯本，確認是改寫而不是近似抄寫（可併入 MV-NAME-002 的外部來源核對） |

## 公開時要補的（不急，但公開那天要有）

| # | 事項 | 依據 |
|---|---|---|
| 5 | README 首段明示「美術與音訊為 AI 生成（ChatGPT／Codex），程式由人與 AI 協作」 | AI 素材條款規則 1：揭露要放在看得到的地方 |
| 6 | README 交代原典來源（Christenson、Tedlock 譯本）與「本作是改編」 | CULTURAL_PRINCIPLES：來源在片尾與下載頁交代 |
| 7 | 推送一律用一般 `git push origin <分支>`，**不可 `--mirror`／`--all` 推 refs**（會把 `refs/codex/*` 送上去） | 本機特殊 ref |
| 8 | 開設定前再跑一次 `gitleaks git --redact` | 密鑰掃描只代表 2026-10-20 的狀態 |

## 公開方式比較

| 方式 | 優點 | 缺點 |
|---|---|---|
| **A. 維持 Private，對外只放下載包＋影片（推薦，現階段）** | 零風險；作品集看的人主要看成品 | 看不到程式與開發流程 |
| B. 直接把這個倉庫改成 Public | 開發歷史完整可見（規格、計畫、報告很有展示價值） | 第 2、3 項無法挽回；歷史裡的所有內容一併公開 |
| C. 另開一個公開倉庫，放整理過的快照 | 名稱、授權、README 一次做乾淨；不帶歷史、不帶信箱 | 要維護兩個倉庫；看不到開發歷史 |

d3 打包完成、正式標題定案後，再在 B 與 C 之間決定；若選 B，先處理第 1～4 項。
