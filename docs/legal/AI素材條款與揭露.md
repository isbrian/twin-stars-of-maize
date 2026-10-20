# AI 生成素材：條款、著作權與揭露

> **工單**：MV-LEGAL-001（承接舊企劃 ART-009、AUD-001）
> **查證日期**：2026-10-01
> **性質**：官方條款與主管機關見解的整理，**不是法律意見**。正式上架販售前，如有疑慮應諮詢律師。條款會變動，正式上架前要重新查一次。

## 結論

**可以用 ChatGPT 生成正式的美術與音訊素材，作品集展示與上架販售都在條款允許範圍內**，但要遵守第 6 節的七條規則。

最需要知道的一件事：**純 AI 生成的素材不受著作權保護**（美國、台灣見解一致）。遊戲可以賣，但別人複製原始的 AI 素材時，很難主張權利；受保護的是本人的創作部分（程式、關卡、編排、實質修改過的素材）。

---

## 1. OpenAI 使用條款（個人服務）

來源：[OpenAI 使用條款](https://openai.com/zh-Hant/policies/terms-of-use/)，生效日期 2026 年 1 月 1 日。適用於 ChatGPT 等「針對個人提供的服務」；ChatGPT Enterprise、API 等企業服務另受「商業條款」規範（網址 openai.com/policies/business-terms/ 現轉至 [OpenAI 服務合約](https://openai.com/zh-Hant/policies/services-agreement/)）。

| 條文要點 | 對本專案的意義 |
|---|---|
| **內容的所有權**：在適用法律允許的範圍內，使用者擁有輸出，OpenAI 把它對輸出的權利（若有）轉讓給使用者 | 條款沒有禁止商業使用；作品集展示與上架販售都可以 |
| **內容相似性**：輸出可能不具唯一性，其他使用者可能收到類似輸出 | 素材沒有獨占性；別人可能生成出很像的東西 |
| **禁止事項**：不得「表示輸出為人為產生，但實際上並非如此」 | 必須誠實揭露 AI 生成，不能宣稱是手繪或作曲 |
| **輸入的權利**：使用者聲明並保證擁有提供輸入所需的權利 | 上傳的參考圖必須是有權使用的（第 6 節規則 4） |
| 必須遵守分享與發佈政策、使用政策 | 見第 2 節 |

## 2. OpenAI 分享與發佈政策

來源：[分享與發佈政策](https://openai.com/zh-Hant/policies/sharing-publication-policy/)（更新日期 2022 年 11 月 14 日）。

| 要求 | 對本專案的意義 |
|---|---|
| 分享前先人工審核每一項生成內容 | 與 ART_SPEC、AUDIO_SPEC 的驗收流程一致 |
| 標註內容出處為您個人或公司名稱 | 作品署名本人 |
| 以「任何使用者都不會錯過或誤解」的方式指出內容是 AI 產生 | **只放片尾不夠**——片尾很多人看不到，要在下載頁／商店頁明示（第 6 節規則 1） |

## 3. 著作權：AI 生成物受不受保護

| 主管機關 | 見解 |
|---|---|
| 美國著作權局 | [Copyright and Artificial Intelligence, Part 2: Copyrightability](https://copyright.gov/ai/Copyright-and-Artificial-Intelligence-Part-2-Copyrightability-Report.pdf)（2025-01-29）：純 AI 生成、或人類對表達元素控制不足的內容不受保護；**只下提示詞不足以成為作者**；人類對輸出的創意選擇、編排或修改，那部分可受保護，個案判斷 |
| 台灣經濟部智慧財產局 | 2023-06-16 經授智字第 11252800520 號函（依[法律事務所整理](https://www.leetsai.com/%E8%87%BA%E7%81%A3%E6%99%BA%E6%85%A7%E8%B2%A1%E7%94%A2%E5%B1%80%E9%A0%92%E5%B8%83%E5%87%BD%E9%87%8B%E8%AA%AA%E6%98%8E%E7%94%9F%E6%88%90%E5%BC%8Fai%E4%B9%8B%E8%91%97%E4%BD%9C%E6%AC%8A%E7%88%AD%E8%AD%B0?lang=zh-TW)）：AI 獨立運算生成、使用者僅下指令而未投入精神創作者，不受著作權法保護；**若生成內容只是重製訓練用的原始著作，著作權仍屬原著作人，商業利用可能涉及重製** |

**對本專案的意義**：

- 受保護的是本人的部分：程式、關卡與系統設計、素材的選擇與編排、骨架動畫、實質修改過的素材。
- 第 6 節規則 5「保留製作紀錄」，就是為了在需要時證明人類的創作投入。
- 生成內容若太像既有作品，有侵權風險，所以 prompt 不能指名特定藝術家或作品（規則 3），驗收時也要檢查相似度。

## 4. Steam

來源：[Steamworks 內容問卷](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)（官方文件）；2026 年 1 月的改版見 [PC Gamer 報導](https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/)。

| 規定 | 對本專案的意義 |
|---|---|
| 上架前要填內容問卷的「生成式 AI」段落 | 美術、音訊屬於「隨遊戲出貨、玩家會接觸到」的內容，**必須申報** |
| 分「預先生成」與「即時生成」兩類 | 本作只有**預先生成**（開發時生成的素材）；沒有執行中即時生成，不需要說明防護措施 |
| 預先生成的內容以一般審查標準檢視；開發者承諾內容不違法、不侵權、與行銷素材一致 | 規則 3、4 的相似度與參考圖檢查，就是在兌現這個承諾 |
| 申報結果會公開顯示在商店頁 | 與 OpenAI「不會被錯過」的揭露要求一致 |
| 開發時用 AI 提升效率的工具（例如寫程式輔助）不是這段的重點 | 程式由本人撰寫、AI 輔助，Steam 不要求申報 |

## 5. itch.io

來源：[Generative AI Disclosure tagging](https://itch.io/t/4309690/generative-ai-disclosure-tagging)、[創作者品質準則](https://itch.io/docs/creators/quality-guidelines)。

| 規定 | 對本專案的意義 |
|---|---|
| 專案頁有「Generative AI disclosure」欄位，選「是」後勾選類別（Graphics、Sound、Text & Dialog、Code），會自動加上標籤 | 本作勾 Graphics、Sound |
| 遊戲頁為選填（鼓勵填寫），素材頁為必填 | 雖是選填，仍要填（OpenAI 揭露要求） |
| 經人工修改的 AI 輸出仍算 AI 生成 | 即使修過圖也要申報 |
| 程式輔助是灰色地帶；版主建議「拿不準就標」 | 建議一併勾 Code |

---

## 6. 本專案的使用規則

| # | 規則 | 依據 |
|---|---|---|
| 1 | **揭露要放在看得到的地方**：下載頁／商店頁明示美術與音訊為 AI 生成；遊戲主選單的「製作說明」與片尾也註明。不寫成「手繪」「原創配樂」等暗示人類創作的說法 | OpenAI 使用條款、分享與發佈政策 |
| 2 | **每一項素材都經本人審核後才採用**：依 ART_SPEC、AUDIO_SPEC 的驗收清單 | 分享與發佈政策 |
| 3 | **prompt 不指名在世藝術家、工作室或特定作品**（例如不寫「Hollow Knight 風格」）；驗收時檢查有沒有明顯像既有作品 | 智慧局函釋（重製風險）、Steam 不侵權承諾 |
| 4 | **上傳給 ChatGPT 的參考圖只用有權使用的**：自己拍的、公有領域或開放授權（例如博物館 CC0 開放典藏）的館藏影像；不上傳來源不明的網路圖片 | OpenAI 使用條款（輸入的權利） |
| 5 | **保留製作紀錄**：每項正式素材保留 prompt、原始輸出、修改後版本（存在 repo 外或不進版控的資料夾） | 美國著作權局、智慧局（證明人類創作投入） |
| 6 | **上架時誠實申報**：Steam 內容問卷勾選預先生成的美術與音訊；itch.io 勾 Graphics、Sound（建議加 Code） | Steam、itch.io |
| 7 | **正式上架前重查本文件的條款**：條款與平台規定會變；ChatGPT 若改用 Team／Enterprise 等企業方案，改看服務合約 | — |

## 7. 使用方案

Brian 使用 **ChatGPT 個人 Plus 方案**（2026-10-01 確認），適用第 1 節的使用條款。若日後改用 Team、Enterprise 等企業方案，改適用服務合約，需重新查證。
