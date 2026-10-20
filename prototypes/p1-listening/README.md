# PROTO-001｜聆聽與聲紋（探路用原型，可丟棄）

> 對應工單：舊企劃 [TODO.md](https://github.com/isbrian/Game-Popol-Vuh/blob/linear-plan-v0.1/TODO.md) EPIC-007 PROTO-001（舊倉庫 tag `linear-plan-v0.1`）
> 設計依據：舊企劃 [CORE_GAMEPLAY.md](https://github.com/isbrian/Game-Popol-Vuh/blob/linear-plan-v0.1/CORE_GAMEPLAY.md)「議題 10」、[AUDIO_SPEC.md](../../AUDIO_SPEC.md) 第 2、10 節
> 惡魔城版：聆聽規則沿用本原型的驗證結果（[VISION.md](../../VISION.md) 6.2）；本原型能否直接沿用，由 MV-PROTO-000 評估。惡魔城版的聲音語彙另新增「前兆」類，不在本原型範圍內

## 要回答的問題

玩家能不能只靠聲音加聲紋，分辨五類聲音語彙（活物、真實、虛假、危險、殘響）？

驗收門檻（AUDIO_SPEC 第 10 節）：沒玩過的人分類正確率至少 80%。

## 執行

需要 Godot 4.7。

```bash
godot --path prototypes/p1-listening
```

## 操作

| 按鍵 | 動作 |
|---|---|
| A、D | 移動 |
| Space | 跳躍（聆聽時不能跳） |
| 按住 F | 聆聽：畫面去色、只能慢走、鏡頭拉遠，方塊發出聲音並浮現聲紋；站到方塊前時，其他方塊的聲音自動壓低 |
| 1～5 | 站到方塊前作答：1 活物、2 真實、3 虛假、4 危險、5 殘響 |
| M | 切換靜音模式（只看聲紋，測聽障玩家能不能玩） |
| R | 重新洗牌，開新一輪 |

## 盲測步驟

1. 找 2～3 位沒看過設計文件的人，戴耳機。
2. 先唸一次五類的一句話說明（見下表），不要示範。
3. 有聲音模式玩 2 輪，再切到靜音模式玩 2 輪。
4. 每次作答都會印在終端機（`ANSWER round=… muted=… actual=… guess=… correct=…`），把輸出存下來。

| 類別 | 一句話說明（唸給試玩者聽） |
|---|---|
| 活物 | 活的東西，有心跳 |
| 真實 | 真實的東西，會共振 |
| 虛假 | 假的東西，裡面是空的 |
| 危險 | 危險的東西，會一直低鳴 |
| 殘響 | 死者留下的回音 |

## 驗證用參數

```bash
# 強制聆聽，錄下畫面（截圖驗證用）
godot --path prototypes/p1-listening --write-movie /tmp/p1/frame.png --fixed-fps 30 --quit-after 75 -- --demo-listen

# 把五類佔位音效匯出成 WAV
godot --headless --path prototypes/p1-listening -- --export-wav /tmp/p1_wav
```
