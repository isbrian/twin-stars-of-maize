# 正式專案｜MV-SLICE-001 垂直切片

> 總規格：[todo/spec/MV-SLICE-001_垂直切片.md](../todo/spec/MV-SLICE-001_垂直切片.md)
> 目前完成：子專案 a 地面關卡與系統——[規格書](../todo/spec/MV-SLICE-001a_地面關卡與系統.md)、[實作計畫](../todo/spec/MV-SLICE-001a_地面關卡與系統_實作計畫.md)；
> 子專案 b1 場景、物件與 HUD（角色先用靜態立繪）——[規格書](../todo/spec/MV-SLICE-001b1_場景物件與HUD.md)、[實作計畫](../todo/spec/MV-SLICE-001b1_場景物件與HUD_實作計畫.md)；
> 子專案 b2a 雙胞胎的骨架與動作——[規格書](../todo/spec/MV-SLICE-001b2a_雙胞胎動作.md)、[實作計畫](../todo/spec/MV-SLICE-001b2a_雙胞胎動作_實作計畫.md)
> 戰鬥與 Boss 程式從 [prototypes/core](../prototypes/core/README.md) 複製而來；原型保留不動，當參考。

## 執行

需要 Godot 4.7。

```bash
godot --path game
```

開啟後是主選單：**新遊戲**、**繼續**。沒有可讀的存檔時「繼續」是灰的；有存檔時選「新遊戲」要再按一次確認（會蓋掉存檔）。上下選、攻擊鍵或 Enter 決定。

### 開發參數（放在 `--` 之後，只在開發版有效；匯出的發行版忽略，直接進主選單）

| 參數 | 作用 |
|---|---|
| `--room <房間>` | 新遊戲後直接進該房間。`home`、`field` 以外的房間先給齊三把武器、老鼠與劇情旗標 |
| `--boss` | 同 `--room boss`（從 nance 樹前的篝火開始） |
| `--boss-phase <1～4>` | 進 Boss 段落後直接從第 n 段開打（4＝覺醒後的出口） |
| `--rig-view` | 雙胞胎的動作展示畫面：兩兄弟並排把 23 個動作各播兩輪（攻擊、招架照數值表的時間），彩色播完換灰階再播一輪後結束。G 切灰階、空白鍵暫停、→ 暫停時前進一格 |
| `--rig-view --frames <資料夾>` | 同上，但以固定 30 fps 逐格存 1920×1080 的 JPG（不看實際時間），錄驗收影片用，見「雙胞胎的骨架與動作」 |
| `--fx-view` | Boss 特效展示畫面（MV-SLICE-001c1）：宮殿與 nance 場景＋Seven Macaw 骨架，依序播光源三種狀態、假光閃耀（聚光＋白茫）、反光柱、光束、場地三次變暗、身上光點、熄滅；彩色一輪、灰階一輪後結束。G 切灰階、空白鍵暫停 |
| `--fx-view --frames <資料夾>` | 同上，逐格存 1920×1080 的 JPG；要加 Godot 的 `--fixed-fps 30`（放在 `--` 之前）才是實際速度，見「Boss 特效」 |
| `--cutscene <opening\|arm\|couple\|toothache\|teeth\|death\|awaken\|finale\|field\|deal\|rope\|morning>` | 直接播 Boss 戰的某段演出（MV-SLICE-001c2a～c2c）：開場、斷臂（接轉場）、只有轉場、牙痛開場、換牙、死亡（接覺醒）、只有覺醒、結尾（接結束畫面）；或地面事件的過場（MV-SLICE-001c3a）：清完田地（收工＋動物復原）、交換、咬繩、天亮；播完 0.5 秒後結束。加 `--frames <資料夾>`（配 Godot 的 `--fixed-fps 30`）逐格存 1920×1080 的 JPG，見「Boss 戰的演出」 |
| `--sound-tour` | 聲音展示（MV-SLICE-001d1a、d1b）：自動跑祖母家（硬地腳步、篝火、兌換）、田地、空地、森林 2（兩兄弟的腳步、換人、跳躍、二段跳、翻滾、揮擊、吹箭、招架、喝湯、木障）、暫停選單與裝備頁、可可豆與碎片、森林 1（荊棘、命中、老鼠、招架成功）、森林 5（反光型）、地面過場（收工、動物復原、交換、咬繩、天亮）、Boss 開場、斷臂、換牙、三段與死亡、覺醒，約 340 秒，左上角寫每段聽什麼；角色用腳本操作、血量補滿；結束時印出各音效的播放次數。配 Godot 的 `--write-movie <檔名>.avi` 錄成有音軌的影片，見「聲音」 |
| `--shots <資料夾>` | 截圖模式（需要視窗）：依序拍 31 個畫面（`home`、`field`、`field_night`、`yard`；森林 6 間各拍左中右 `forest_N`、`_mid`、`_right`；支路 `forest_a`～`c` 各拍左右；`boss_nance`、`boss_path`、`boss_palace`），每張另存 `_gray.png` 灰階版，並把每個畫面 120 幀的平均幀時間寫進 `frametimes.txt`，拍完自動結束 |

```bash
godot --path game -- --room forest_3
```

## 操作（方案 A）

| 動作 | 手把 | 鍵盤＋滑鼠 |
|---|---|---|
| 移動 | 左搖桿 | A／D 或 ←／→ |
| 上攻／下劈 | 左搖桿上＋攻擊／空中左搖桿下＋攻擊 | W＋攻擊／空中 S＋攻擊 |
| 跳躍（按住跳得更高） | A | Space |
| 翻滾（只能在地面，中段無敵） | B | Shift |
| 攻擊（目前場上的人的武器；球具＝招架） | X | 滑鼠左鍵 |
| 換人 | Y | Tab |
| 吹箭 | RT；右搖桿自由瞄準，沒推右搖桿時左搖桿 8 方向（地上推正下＝斜下），都沒推朝面向 | 滑鼠右鍵，朝游標 |
| 治療（次數用完時在地面按，會喝一碗熱湯） | 十字鍵上 | R |
| 互動（休息、找祖母兌換、撿東西） | 十字鍵下 | E |
| 動物技能槽 1（老鼠的鑽地突襲）／槽 2（切片鎖住） | 十字鍵左／十字鍵右 | Q／F |
| 暫停選單（裝備、回主選單、回到遊戲） | Start | Esc |
| 選單：上下選、攻擊鍵確認、翻滾鍵或 Start 返回 | | |
| 存回數值、印出數值表、招架紀錄、Boss 日誌摘要（開發版） | — | F9 |
| 重來目前的房間／Boss 場地（開發版） | — | F10 |
| Boss 破綻直接加滿（開發版） | — | F11 |
| 改目前這個人的武器（開發版） | — | 1 斧頭／2 掘棒／3 球具 |

第一次需要某個操作時，畫面下方會出現按鍵提示（依最後使用的裝置顯示手把或鍵盤）；做到就消失，看過的提示會存檔。

## 流程與房間

祖母家醒來（只有吹箭）→ 田地撿斧頭與掘棒、清掉 3 叢灌木（斧頭）與 3 個土塊（掘棒）→ 收工與動物復原的過場、入夜，把老鼠逼到牆角 → 交換的過場 → 回祖母家，咬繩的過場、球具掉下 → 撿起（拿到球具與老鼠）→ 天亮的過場→ 家前空地的荊棘消失 → 森林 1～6（支路 A～C 可選）→ Boss 段落 → 出口 → 結尾文字卡 → 主選單。

| 房間（`world/rooms/`） | 內容 |
|---|---|
| `home` 祖母家 | 休息點、祖母兌換熱湯（15 顆一碗，最多帶 2 碗）；左門田地、右門家前空地 |
| `field` 田地 | 開墾田地、入夜抓老鼠 |
| `yard` 家前空地 | 往森林的路被荊棘擋住，拿到球具後消失 |
| `forest_1`～`forest_6` 森林（主路） | 每間 3 個畫面寬、爬行型與飛行型 2～4 隻（MV-SLICE-001c4a），森林 3、5、6 另各 1 隻反光型（MV-SLICE-001c4c1）；森林 2、5 有篝火；森林 2 第一顆下劈水晶與下劈提示；森林 3 有藏點（10 顆可可豆）；森林 5 高處有血量碎片；森林 3、4、6 右端高台通往支路。覺醒後的鎖（MV-SLICE-001c4b）：森林 1 中段、森林 4 左端離地 600 的高台（二段跳）上各一片碎片（森林 4 另有木障擋著）；森林 2 右端 ↔ 森林 5 左端高台上的門是捷徑，兩頭木障破開一次就都開（旗標 `shortcut_25`） |
| `forest_a`～`forest_c` 支路 | 各一間、只有一扇門：A 下劈水晶跨過荊棘、B 荊棘上的窄原木、C 關門戰（3 波）；盡頭各一片血量碎片 |
| `boss` Boss 段落 | 規格第 8～13 房做成一個房間，內部沿用原型的 `boss_fight.gd`：樹下篝火（`nance_camp`）→ nance 樹（第 1 段）→ 小路 → 宮殿篝火（`palace_camp`）→ 宮殿（第 2、3 段、覺醒）→ 出口高台。第 1 段開打前可以往左走回森林 6；覺醒後走到小路最左端也回森林 6，覺醒後從森林 6 進來直接在小路起點（MV-SLICE-001c4b）|
| `exit` 結尾 | 文字卡「垂直切片到此結束。」，按掉回主選單 |

- **可可豆**：敵人掉 1～3 顆；死亡不損失。
- **血量碎片**（MV-SLICE-001c4a、c4b）：切片 6 片，2 片血量上限 +1（5 → 8 格）；記在存檔的「取過的藏點」（`frag_a`～`frag_f`），不另加欄位；血條末端的半格表示收了奇數片。
- **反光型**（`core/enemies/reflector.gd`，MV-SLICE-001c4c1）：站著不走；玩家在正面 960 px 內 → 舉起反光面蓄力 1.0 秒（暗紫鋸齒、光點由暗到亮）→ 貼地水平光束 0.5 秒（碰到牆就停、跳得過）→ 收招 1.0 秒。反光面擋正面（悶響）；前搖中正面吹箭＝打斷；正上方與背後全額扣血；玩家繞到背後要 0.8 秒才轉過來。骨架與動作（MV-SLICE-001c4c2）：8 根骨頭、遊戲高 150、判定 250×150；轉身過半時畫面先翻向玩家、擋下時反光面往後一震、蓄力光點掛在反光面寶石上、光束沿用 Seven Macaw 的光束特效（`beam_fx.gd`）；沒有場景的測試房間仍畫程式佔位。
- **荊棘地形**：地上的一排荊棘；碰到扣 1 格、淡黑、回到最後站穩且離荊棘夠遠的地面；扣到 0 照一般死亡。
- **下劈水晶**：空中下劈打中會彈起；森林 2 第一顆前出現提示，彈起一次就不再出現。
- **關門戰**：走到房間中央兩側升起荊棘牆，3 波敵人，清完出現碎片；中途死亡重來；碎片拿過不再觸發。
- **房間檢查**（`world/room_check.gd`）：`walk_errors(資料, 起點, 終點)` 從地形資料算只靠單跳（上升 ≤ 340、間隔 ≤ 400）走不走得到；自測用它檢查主路；c4b 起可傳上升、間隔上限（`SINGLE_REACH_*` 判斷單跳一定到不了、`MAX_RISE_DOUBLE` 判斷二段跳到得了）。
- **木障**（房間資料 `barriers: [{rect, flag?}]`，MV-SLICE-001c4b）：沿用 `core/level/barrier.gd`，只有覺醒後希巴拉克的飛鏢能標記、工具砍碎；有 `flag` 的破開後設旗標、不再立起，沒有的每次進房立起。外觀是森林木障（MV-ASSET-017 C-04），從底部往上鋪、不伸出高台。房間左右牆與木障頂端都在 y −1000（`Kit.TOP`），二段跳翻不過去。
- **覺醒後的提示**：第一次走進小路（宮殿左緣以西），畫面下方顯示 4 秒「森林裡有以前到不了的地方」，旗標 `hint_forest_return`。
- **休息**：在篝火或祖母家按互動鍵 → 血量、治療次數、技能資源回滿，敵人重生，存檔。
- **死亡**：回到最後休息的地方（不存檔）。Boss 段落裡的死亡照原型：死在第 1 段回樹下篝火，死在第 2、3 段回宮殿篝火。
- **鑽地突襲**：老鼠往面前 700 px 內最近的地面敵人鑽過去咬一口並讓牠硬直；資源 3 格，近戰命中 4 次回 1 格，休息回滿。

## 美術素材（MV-SLICE-001b1）

- 遊戲只讀 `game/art/`（`bg/` 場景、`prop/` 物件、`ui/` HUD、`chr/` 角色立繪）；**不要手動放檔案或改圖**。
- 來源是 `assets-test/`（不進版控）的定稿圖，由 [tools/import_art.py](../tools/import_art.py) 的 `ENTRIES` 處理成遊戲尺寸（縮放、裁切 `crop`、洋紅去背 `key`、鏡像接圖 `mirror`），並重寫 [art/MANIFEST.md](art/MANIFEST.md)。輸出固定：同樣的來源一定產生同樣的位元組。
- 加新素材：在 `ENTRIES` 加一筆 → 跑下面三行 → 連同 `.import` 一起提交。

```bash
python3 tools/import_art.py
godot --headless --path game --import
python3 -m unittest tools/test_import_art.py
```

`python3 tools/import_art.py --check` 只比對不寫入，有差異時退出碼 1。
- 場景：每個房間的資料只寫 `theme`（與 `variant`），四層圖與視差倍率在 `world/scenery.gd` 的主題表；Boss 段落的三個區段（nance 樹、小路、宮殿）在 `world/scenery_view.gd` 的 `build_boss()`。
- 角色全部用骨架：雙胞胎、爬行型、飛行型、Seven Macaw、NPC（祖母、老夫婦、老鼠、Chimalmat），見下面三節；b1 的靜態立繪 `world/portrait.gd` 已在 MV-SLICE-001b2b2 移除。受擊閃白、治療偏綠、無敵半透明的規則在 `world/tint.gd`。

## 雙胞胎的骨架與動作（MV-SLICE-001b2a）

執行時從資料組出骨架（不產生 `.tscn`）；姿勢是玩家目前狀態的純函式，約 12 fps、不內插。

| 檔案 | 內容 | 怎麼改 |
|---|---|---|
| `rig/{hunahpu,xbalanque}_rig.json` | 關節座標、分件掛哪根骨頭（遊戲像素） | 不手寫：`python3 tools/import_rig.py` 從 p4 的 `prototypes/p4-art-pipeline/rig/*_rig.json` 依 180 px 身高換算（`--check` 只比對） |
| `art/chr/parts/` | 兩兄弟各 16 個分件、武器與球具的側面圖、手上的湯碗 | `tools/import_art.py` 的 `ENTRIES`（分件用 `scale`，和關節資料同一比例） |
| `rig/twin_anims.json` | 23 個動作：每格的時間、各骨頭相對靜止姿勢的角度（度，正＝順時針）、骨盆位移、近側手勢；攻擊與招架的時間是段落時間（出招 0～1、判定 1～2、收招 2～3，執行時照數值表換算） | 直接改數字，重開遊戲或 `--rig-view` 就看得到 |
| `rig/attachments.json` | 武器、球具、湯碗、吹箭掛在哪根骨頭、握點與方向 | 直接改 |

- 程式：`world/rig_view.gd` 組骨架與擺姿勢；`world/twin_animator.gd` 把玩家狀態換成（動作, 時間），只顯示場上那位、面向翻轉、斷臂（`Twin.arm_broken`，Boss 第 2 段起到覺醒前）時隱藏近側手臂並補膚色圓盤收邊，吹射時頭與雙臂轉向瞄準方向（最後一發後舉 0.6 秒，只在自由狀態）；攻擊的判定框方塊在有骨架時不畫。
- 骨架畫在玩家節點後面（程式畫的訊號在上面）；分件攤平在同一層、依資料的 z 排節點順序（z_index 一律 0），每次擺姿勢後同步到骨頭，所以整副和 b1 的立繪一樣跟玩家同層、依樹順序排前後（在先加入的篝火、撿拾物、NPC 之上）。
- 錄驗收影片（1920×1080；Movie Writer 只錄得到視窗大小，所以逐格輸出再合成）：

```bash
godot --path game -- --rig-view --frames /tmp/rig_frames
ffmpeg -framerate 30 -i /tmp/rig_frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 18 assets-test/b2b1_video/b2b1_rigs.mp4
```

  展示順序（`world/rig_showcase.gd` 的 `playlist()`）：雙胞胎每個動作 → 爬行型、飛行型（遊戲大小與放大 2 倍並排）→ Seven Macaw 四種頭依序各播一輪全部動作（黃點＝該頭對應的光點）；彩色一輪、灰階一輪，約 4 分 11 秒。b2a 的影片在 `assets-test/b2a_video/b2a_rigs.mp4`；MV-TUNE-003（翅膀換新素材、拍翅）的影片在 `assets-test/tune003_video/tune003_rigs.mp4`；MV-SLICE-001b2b2（加上 NPC，在飛行型之後、Seven Macaw 之前）的影片在 `assets-test/b2b2_video/b2b2_rigs.mp4`。

## 爬行型、飛行型、Seven Macaw 的骨架與動作（MV-SLICE-001b2b1）

同一套 `world/rig_view.gd`：骨頭表、光點、人形專用部分（手勢、斷臂、吹射覆寫、武器附件）都看 rig json 決定。遊戲高度：爬行型 70、飛行型 60、Seven Macaw 450；基準圖面向左，rig json 有 `"faces": -1`（animator 設 `scale.x＝面向×faces`）。

| 檔案 | 內容 | 怎麼改 |
|---|---|---|
| `tools/rig_src/{crawler,flyer,sevenmacaw}_joints.json` | 人工標的關節、骨頭表、切件範圍 | 手改，再跑 `python3 tools/cut_rig.py crawler flyer sevenmacaw`（分件寫到 `assets-test/chr_b2b1/parts/`，來源像素的 rig 寫到 `tools/rig_src/{角色}_rig.json`） |
| `art/chr/parts/{角色}/` | 分件 | `tools/import_art.py`（`--check` 只比對） |
| `rig/{crawler,flyer,sevenmacaw}_rig.json` | 遊戲像素的關節、分件、光點；`anims`、`humanoid: false`、`faces` | 不手寫：`python3 tools/import_rig.py`（`--check` 只比對） |
| `rig/{crawler,flyer,sevenmacaw}_anims.json` | 動作：每格的時間、骨頭角度、根骨頭位移（鍵 `root`）；12 fps、不內插 | 直接改數字，`--rig-view` 就看得到 |

`cut_rig.py` 的 joints json 欄位（完整說明在檔頭 docstring）：

| 欄位 | 內容 |
|---|---|
| `src`、`joints`、`bones` | 基準圖（相對 `assets-test/`）；關節來源座標；`[骨頭, 父骨頭, 起點關節, 終點關節, 分配半徑, z]` |
| `polys` | 選填：圈進去的像素直接歸某件（作用在骨頭所在的那張圖） |
| `layers` | 選填：某幾根骨頭改從另一張圖切（和身體分開畫的翅膀）：`{名稱: {src, marks, ref_marks, bones}}`，兩點縮放＋平移貼回主圖座標（MV-TUNE-003） |
| `erase` | 選填：主圖在這些多邊形內的像素當背景（修圖痕跡） |
| `overlap` | 選填：`{分件: 多邊形}`，圈內同一張圖的像素也帶進這件、不從原本的分件拿走；墊在會轉開的接縫底下（Seven Macaw 脖子後方、腹部） |
| `far` | 選填：遠側件 `[分件, 骨頭, 複製自, z, [dx, dy]]`＝複製近側件、明度 ×0.72，關節平移 |
| `cap`、`caps` | 關節重疊半徑（預設 34）；`caps` 個別關節的半徑 |
| `snap` | 選填：方框內改成沿墨線切（避免直線切過羽毛） |
| `heads`、`head_marks` | 選填：替換頭的特寫圖與兩個對位點（主圖上同樣兩點）；輸出 `head_{名稱}`，掛 head 骨頭、預設隱藏 |
| `points` | 選填：光點 `{名稱: {bone, at}}`，輸出換成骨頭座標；`rig_view.point(名稱)` 取目前位置 |
| `origin` | 原樣帶進輸出（腳底對齊用） |

- 敵人：`world/enemy_animator.gd` 依敵人狀態（待機、前搖、攻擊、收招、硬直）選動作；判定框與數值不動。
- Seven Macaw 的來源是兩張圖（MV-ASSET-016）：身體 `b2b1_wing/enm_sevenmacaw_body_nowing.png`（主圖）＋近側翅膀 `b2b1_wing/enm_sevenmacaw_wing_near.png`（`layers.wing`，切 `wing_arm`、`wing_fore`、`wing_tip`）；兩張疊成的合成圖匯入成 `art/chr/enm_sevenmacaw_rest.png`，是靜止姿勢的比對基準（`test_macaw_rig`）。原本的單張立繪 `enm_sevenmacaw_reference.png` 保留。
- Seven Macaw：`world/macaw_animator.gd` 依狀態與招式階段選動作（招式時間依數值表換成分段時間 0～3，同雙胞胎的 `attack_time`），依外觀換頭件（`head`、`head_jawhurt`、`head_maize`、`head_blind`），每幀把光源放到頭骨上的光點（下顎、玉牙、眼睛）；受擊框與碰撞攻擊框是站姿量出的 `BODY`。飛鏢碰到他的受擊框時沿剩下的射程找他的光源（地形擋住就停，`dart.gd`）。

## NPC 的骨架與動作（MV-SLICE-001b2b2）

祖母（`xmucane`）、治療者老夫婦（`healer_man`、`healer_woman`）、老鼠（`rat`）、Chimalmat（`chimalmat`）同樣用 `tools/cut_rig.py` 從立繪切件（`tools/rig_src/{角色}_joints.json`，`import_rig.py` 的 `CUT_CHARS`）。遊戲高度同原本的立繪：祖母 165、老伯 170、老婆婆 165、老鼠 40、Chimalmat 340；祖母、老夫婦、老鼠的基準圖面向右（`import_rig.py` 的 `FACES_RIGHT`，rig json `"faces": 1`），Chimalmat 面向左。

| 角色 | 動作（`game/rig/{角色}_anims.json`） | 什麼時候播 |
|---|---|---|
| 祖母 | `idle`、`give`（單次）、`doze` | 按互動鍵開兌換時播一次 `give`，播完回 `idle`（`room.gd`）；抓到老鼠後到天亮前睡著播 `doze`（`room.npc_asleep`，MV-SLICE-001c3b） |
| 老伯、老婆婆 | `idle`、`walk` | 跟著角色而且有在移動時 `walk`、面向移動方向，否則 `idle`（`boss_fight.gd` 的 `_update_couple`） |
| 老鼠 | `idle`、`run`、`climb`、`gnaw`、`talk` | 地面過場（MV-SLICE-001c3b）：交換時開口 `talk`、咬繩時 `climb`、`gnaw`；入夜抓老鼠：有移動 `run`、沒移動（含網子底下）`idle`（`prop.gd`）；鑽地突襲：全程 `run`、面向移動方向（`core/player/rat.gd`） |
| Chimalmat | `idle` | 一直（`scenery_view.gd`） |

- 程式：`world/npc_animator.gd`：`attach(節點, 角色)` 建骨架（腳底對齊原點），`play(動作, 播完接哪個)`、`facing`；動作與面向由呼叫端決定。原本的靜態立繪 `world/portrait.gd` 已移除。
- 立繪只畫了近側手臂的角色（祖母、老夫婦），遠側手臂複製近側降明度、畫在身體後面；腿、老鼠的四隻腳都有畫出來，各自切成一組。接縫用 `polys` 與 `overlap` 處理（見 joints json）。

## Boss 戰的演出（MV-SLICE-001c2a）

Seven Macaw 戰的劇情用引擎內演出（MV-BOSS-001 第 5 節）：nance 樹三段（c2a）、宮殿三段（c2b）、覺醒與結尾（c2c）：

| 演出 | 什麼時候 | 內容 |
|---|---|---|
| 開場（`world/cutscene/opening.gd`） | 第一次越過 nance 入口；重試不播 | 兄弟躲進草叢 → 旁白 → 他飛到低枝吃果子（下顎微亮）→ 展翅、兄弟跳出 → 名號「七金剛鸚鵡／自稱是太陽，也是月亮」→ 飛回樹冠開打 |
| 斷臂（`arm.gd`） | 第 1 段設局成功 | 逆光剪影：他摔落、胡納普撲上去被扯下手臂 → 宮殿（正常顏色）：他把手臂掛在火堆上方的繩子上，和奇瑪瑪特對話 |
| 轉場（`couple.gd`） | 接在斷臂後 | 小路起點：兄弟請兩位老人同行，老人跟到兄弟身後，交還操作 |
| 牙痛開場（`toothache.gd`） | 第一次進宮殿；重試不播 | 他在寶座前捧著下顎哀嚎、奇瑪瑪特在旁 → 轉身展翅 → 第 2 段開打 |
| 換牙（`teeth.gd`） | 第 2 段設局成功 | 他伏低哀求 → 兩位老人走到他頭前伸手、背影擋住他的嘴，換上白玉米牙 → 第 3 段開打 |
| 死亡（`death.gd`） | 第 3 段設局成功 | 伏低、老人摘眼 → 呆望 → 身上光點熄滅、宮殿最後的假光淡出、場景到最暗 → 他倒下，奇瑪瑪特變黑倒下淡出 → 老人撿起珠寶走出畫面 |
| 覺醒（`awaken.gd`） | 接在死亡後（同一次演出） | 胡納普取下繩上的手臂 → 逆光剪影裡希巴拉克扶回肩上 → 白光閃回開墾田地（`flashback.gd`：斧頭、掘棒自己工作，暖褐單色＋暈邊）→ 「讓工具自己動／希巴拉克覺醒」「二段跳／胡納普覺醒」→ 換成希巴拉克、補滿、自動存檔（「已存檔」）、出口 |
| 結尾（`finale.gd`） | 走上出口高台 | 兩兄弟回頭望宮殿 → 「七金剛鸚鵡的驕傲被拿走了。」→ 走出畫面、淡出 → 黑畫面接出口房間的結束畫面（片尾含 AI 生成揭露）→ 回主選單 |

- 只有遊戲模式播演出；原型模式照舊（灰盒開場、`arm`／`couple`／`awaken`／`clear` 文字卡）。
- 跳過：覺醒段宣告 `skip_stop`，在死亡段長按只跳到覺醒開頭，要放開再長按才跳過覺醒。
- 出口（覺醒後）：提示做到才換——先「希巴拉克的飛鏢射中木障，工具會自己去砍碎它」，木障碎了換二段跳提示。
- 通關存檔（SLICE-c-3）：覺醒交還時同篝火休息後存檔（`last_rest = palace_camp`、`awakened`）；讀檔回到宮殿篝火、已覺醒，進宮殿不關閘門、不開打，直接是出口（木障重新立起）。通關後讀檔相同。
- 操作：字幕自動換句（`max(1.5, 0.12 × 字數)` 秒），攻擊鍵提前換（每句至少 0.3 秒）；**按住暫停鍵 1 秒跳過整段**（右下角的圈填滿）；演出中暫停選單不開、HUD 隱藏。
- 機制在 `world/cutscene/cutscene.gd`（執行器）：上下黑邊（畫面高 11%）、字幕在下方黑邊裡、名號、跳過、凍結戰場（場景照常處理）、自己的鏡頭；替身 `actor.gd`（骨架、播動作、假光源、叼東西）；逆光剪影（暖色漸層底＋`scenery_view.set_silhouette`，不用 shader）。每段演出一支腳本：`play(cs)` 依序 await 指令，`end_state(host)` 設定演出後的遊戲狀態——看完與跳過都會呼叫，結果相同（自測比對）。
- 宮殿繩結上掛著胡納普的手臂（`arm_prop.gd`，用他自己近側手臂的分件）：第 2 段起、覺醒前，由進度決定，不另外存檔。
- 死後的宮殿（`scenery_view.set_dead`）：覺醒後地上一直躺著他（`collapse` 最後一格、失明的頭、偏暗、打不到），奇瑪瑪特不在。
- 指令補充（c2b）：`together([...])` 同時做幾個指令、全部做完才往下；`conceal(節點)` 演出期間藏起真正的節點；`tint(節點, 顏色, 秒)`；交還操作時先恢復顯示再呼叫 `end_state`（`end_state` 藏起的東西不會被蓋回來）。
- 新動作：雙胞胎 `crouch`、`walk`、`lunge`、`knocked_down`；Seven Macaw `yank`、`hang`、`bow`、`collapse`；老夫婦 `reach`、`pick`；奇瑪瑪特 `collapse`。
- 錄影：

```bash
godot --path game --fixed-fps 30 -- --cutscene arm --frames /tmp/c2a_arm
ffmpeg -framerate 30 -i /tmp/c2a_arm/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 20 assets-test/c2a_video/c2a_arm.mp4
```

  覺醒與結尾的影片在 `assets-test/c2c_video/`：`c2c_death.mp4`（死亡＋覺醒，約 35 秒）、`c2c_finale.mp4`（結尾＋結束畫面，約 5 秒）。宮殿三段的影片在 `assets-test/c2b_video/`：`c2b_toothache.mp4`（約 7 秒）、`c2b_teeth.mp4`（約 12 秒）、`c2b_death.mp4`（約 19 秒）。nance 樹三段的影片在 `assets-test/c2a_video/`：`c2a_opening.mp4`（約 13 秒）、`c2a_arm.mp4`（斷臂＋轉場，約 32 秒）、`c2a_couple.mp4`（只有轉場，約 14 秒）。

## 地面事件的演出（MV-SLICE-001c3a）

地面房間也用上面的過場系統：`cutscene.gd` 的 `host`（原本叫 `fight`）是舞台——Boss 戰傳自己，地面傳 `world/cutscene/ground_stage.gd`（房間、HUD、事件排程；沒有 Boss）。事件排程 `event_runner.play(段落們)` 在房間底下建過場節點（`PROCESS_MODE_ALWAYS`，房間凍結時照常跑、換房時跟著釋放）。

| 演出 | 什麼時候 | 內容 |
|---|---|---|
| 收工（`field_dusk.gd`） | 田地 6 個清完 | 兄弟倆插好斧頭與掘棒 → 工具自己清掉田左半的 4 叢演出灌木（`decor_bushes`，打不到）→ 拿吹管去打獵、天色入夜 |
| 動物復原（`field_animals.gd`） | 緊接收工；之後進田地時還沒看過（`night_seen`） | 動物跑過、灌木與土塊長回來 → 兄弟倆撲上去只抓到鹿和兔子的尾巴 → 剩下老鼠；兄弟倆退到老鼠左邊 450 px 再交還 |
| 交換（`rat_deal.gd`） | 網子罩住老鼠 | 老鼠開口求饒 → 給玉米、豆子、可可 → 老鼠說出球具在屋頂下 → 跑向祖母家；`rat_caught` |
| 咬繩（`gear_rope.gd`） | 抓到老鼠後進祖母家（沒有 `gear_dropped`） | 祖母睡著 → 老鼠爬上屋梁咬斷繩子 → 球具落地；`gear_dropped`，交還後玩家自己撿 |
| 天亮（`morning.gd`） | 撿起球具 | 淡出 →「第二天早上，兄弟倆出發了。」→ 白天、祖母醒來 → 淡入；`gear_obtained` |

- 夜晚：田地從 `field_cleared` 到 `gear_obtained` 前、祖母家從 `rat_caught` 到 `gear_obtained` 前（`event_runner.apply_night`）。祖母睡著時（`room.npc_asleep`）頭上「Z z z」、互動不開兌換。
- 中途離開：動物復原看過就不重播；球具掉下後沒撿就離開，再回來球具還在、不重播咬繩。
- 素材與動作（MV-SLICE-001c3b）：動物（鹿、兔子、長鼻浣熊）、尾巴、食物是 [MV-ASSET-020](../docs/assets/MV-ASSET-020_素材工單_地面事件.md) 的正式圖（`silhouette.gd` 依 `kind` 畫；動物調成夜色 `ANIMAL_NIGHT`、跑的時候彈跳）；雙胞胎 `plant`（插工具）、`grab`（撲完起身，尾巴握在近側手 `hand_r`）；老鼠 `climb`、`gnaw`、`talk`；祖母 `doze`（睡著時一直播，沒有腿所以是站著打盹）；工具自己揮砍三下、每下掉碎屑（`CPUParticles2D`）；咬繩交還時球具就能撿。
- 錄影：`godot --path game --fixed-fps 30 -- --cutscene field --frames /tmp/c3a_field`（其餘 `deal`、`rope`、`morning`），影片在 `assets-test/c3a_video/`：`field.mp4`（收工＋動物復原，約 39 秒）、`deal.mp4`（約 16 秒）、`rope.mp4`（約 14 秒）、`morning.mp4`（約 6 秒）、串接的 `c3a_all.mp4`、抽格 `c3a_frames.jpg`。 c3b 換裝後的影片在 `assets-test/c3b_video/`：`field.mp4`（收工＋動物復原）、`deal.mp4`、`rope.mp4`、`morning.mp4`、串接 `c3b_all.mp4`、抽格 `c3b_frames.jpg`、新動作抽格 `c3b_poses.jpg`。

## Boss 特效（MV-SLICE-001c1）

Seven Macaw 戰的特效全部是程式繪製：預先產生的放射狀光暈貼圖、加亮混合（`CanvasItemMaterial` ADD）、少量光點與線條，不用 shader、不開美術工單。共用材料在 `world/fx/fx_kit.gd`（`glow_texture(size)`、`add_material()`、光的顏色 `CORE` 暖白／`GOLD` 金）。

只有遊戲模式（Boss 戰有 GameState）掛特效；原型模式不掛、照舊畫灰盒。做法同骨架取代立繪：core 節點加 `fx_drawn`，為 true 時不畫灰盒，外觀由 `world/fx/` 另掛的節點讀 core 的狀態來畫（不改任何玩法數值、時序、判定）。

| 特效 | 腳本 | 掛在哪 | 讀什麼 |
|---|---|---|---|
| 光源（熄滅暗點、微亮呼吸、最亮大光暈＋擴散光環） | `light_fx.gd` | 光源底下（跟著頭骨上的光點） | `light_source.state` |
| 假光閃耀前搖（10 個光點往身上收攏、身上光暈漸強） | `flash_fx.gd` | Boss 底下 | `false_flash` 的前搖進度；聚光中心在畫面上緣以外（停在樹冠）時往下移進畫面 |
| 白茫（從 Boss 的畫面位置擴散，維持 0.9、照原曲線淡出） | `whiteout_fx.gd` | UI 層、`whiteout` 後面 | `whiteout.t`；任何一點都不比原本淡 |
| 反光柱（落點光斑＋虛線；中心白兩側金、往下流動） | `pillar_fx.gd` | 每根光柱底下（`boss_fight` 看 `world.child_entered_tree`） | `pillar.t`；實心寬＝判定 120 px，柔光每邊 6 px |
| 光束（蓄力時地面虛線；出招時眼睛連結線＋光束） | `beam_fx.gd` | Boss 底下 | `beam.area()`（實心＝判定矩形） |
| 宮殿假光（牆上金飾、寶座，分 3 組） | `palace_lights.gd` | `scenery_view` 最後（畫在寶座上面） | `set_darkness(lights_removed, animate)`：段落中拔掉光源 0.8 秒淡出，開打／重試／讀檔直接對應；篝火不受影響 |
| 身上光點（10 個金飾、寶石光點＋全身淡光暈） | `macaw_glints.gd` | Boss 底下（排在 `MacawAnimator` 之後） | 骨架資料的 `glint_1`～`glint_10`（翅膀、軀幹、尾羽，不在頭上） |

- 熄滅：`MacawGlints.extinguish(seconds)` 依離胸口（`torso` 起點）由遠到近逐一熄、光暈淡到 0、身體變暗到 ×0.5，結束發出 `extinguished`。c1 只提供效果，c2 的死亡演出決定何時呼叫。
- 光點位置：`tools/rig_src/sevenmacaw_joints.json` 的 `points`（主圖來源座標，`cut_rig.py` 換成骨頭座標）；檢查圖 `assets-test/c1/check/sevenmacaw_glints.png`。
- 展示與錄影（`world/fx_showcase.gd`，Boss 不跑 AI，狀態由展示畫面直接設；位置同遊戲：假光閃耀時停在樹冠）：

```bash
godot --path game --fixed-fps 30 -- --fx-view --frames /tmp/fx_frames
ffmpeg -framerate 30 -i /tmp/fx_frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 20 assets-test/c1_video/c1_fx.mp4
```

  `--fixed-fps 30` 讓每格固定前進 1/30 秒，特效自己的動畫（呼吸、閃爍、淡出、熄滅）在影片裡也是實際速度。影片約 53 秒（彩色＋灰階），在 `assets-test/c1_video/c1_fx.mp4`。

## 標題畫面與製作說明（MV-SLICE-001d2a）

| 項目 | 做法 |
|---|---|
| 正式標題 | [ui/title_menu.gd](ui/title_menu.gd) 的 `GAME_TITLE`（全專案只此一處；MV-TITLE-001 定案後改這行，再重跑字型工具） |
| 標題背景 | 自己的 SubViewport（`World2D`＋`Camera2D`）裡的 `SceneryView.build_boss()`，夜色；Seven Macaw 替身停在 `Nance.PERCH`、畫成剪影；鏡頭 20 秒左右緩移 ±200 px |
| 主選單 | 新遊戲／繼續／繪本／製作說明／結束遊戲；游標跳過不可選的項目；新遊戲（有存檔）與結束遊戲要再按一次確認；環境音 AMB-01 |
| 製作說明 | 內容 [ui/credits_text.gd](ui/credits_text.gd)（含 AI 揭露）；畫面 [ui/credits.gd](ui/credits.gd)：主選單 `manual`（上下捲、返回關閉），片尾 `auto`（60 px／秒、捲完停 2 秒，攻擊或返回跳過） |
| 片尾 | 結尾卡「垂直切片到此結束，謝謝試玩。」→ 自動捲動的製作說明 → 回主選單 |
| 字型 | `art/fonts/NotoSerifTC_ui.ttf`（思源宋體精簡版，d2b 起含繪本前篇的字，約 424 KB，進版控；OFL 授權在旁邊）。改了 `title_menu.gd`、`credits_text.gd`、`book_text.gd`、`book_style.gd` 的字串就重跑 `python3 tools/font_subset.py`；`test_d2a.test_ui_font_covers_all_text` 會抓缺字 |

錄標題畫面展示影片（約 50 秒）：

```bash
godot --path game --resolution 1920x1080 --write-movie /tmp/d2a_tour.avi -- --title-tour
```

截圖模式可用 `SHOTS_ONLY=<名稱片段>` 只拍部分（例：`SHOTS_ONLY=hud` 拍 HUD 檢查的 7 張、`SHOTS_ONLY=title`、`credits` 或 `book` 都拍主選單這一組：標題、製作說明、繪本 8 頁 `book_front_NN`、新遊戲詢問 `title_book_ask`）。

## 繪本前篇（MV-SLICE-001d2b）

| 項目 | 做法 |
|---|---|
| 入口 | 主選單「繪本」（讀完或離開回主選單）；第一次選新遊戲時選單下方問「要先讀繪本嗎？」（讀繪本／直接開始；翻滾＝直接開始），讀完或離開都直接開始新遊戲。問過一次就寫 `user://book_asked.json`，之後不再問（和存檔分開；刪掉這個檔就會再問） |
| 閱讀器 | [ui/book_reader.gd](ui/book_reader.gd)（翻頁 0.3 秒交叉淡入淡出；右鍵／攻擊鍵／Enter 下一頁、左鍵上一頁、翻滾／暫停離開；最後一頁再往下＝讀完）、[ui/book_page.gd](ui/book_page.gd)、[ui/book_style.gd](ui/book_style.gd)（版面數值，和原型 `prototypes/book-reader/book_style.gd` 的繁中那組相同）；聲音 `ui_page_open`／`ui_page_close`，環境音不變 |
| 文字 | [ui/book_text.gd](ui/book_text.gd) 由 `python3 tools/book_export.py` 從 `docs/book/` 產生（不要手改）；改了文本要重跑它，再重跑 `python3 tools/font_subset.py`。`tools/test_book_export.py` 會抓沒重跑的情形 |
| 插圖 | `art/book/book_front_01～08.webp`：從 `assets-test/book_front/final/` 的 PNG 轉成 WebP 品質 90（Pillow：`Image.open(png).convert("RGB").save(webp, "WEBP", quality=90, method=6)`），匯入設 `compress/mode=1`（Lossy）、`compress/lossy_quality=0.9` |

## 發版（MV-RELEASE-001）

| 步驟 | 指令／做法 |
|---|---|
| 匯出範本 | Godot 4.7.2 官方 `Godot_v4.7.2-stable_export_templates.tpz`（godotengine/godot 的 GitHub Release，約 1.28 GB，對 `SHA512-SUMS.txt` 核對），把 `templates/` 解到 `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` |
| 掃描 | `python3 tools/release.py scan`：進版控的檔不得含本機路徑、家目錄、作者信箱（禁用字串在執行時從本機取得，原始碼不寫） |
| 匯出 | `python3 tools/release.py build 0.1.0` → `build/TwinStarsOfMaize-v0.1.0-windows.zip`、`-macos.zip`、`build/web/`；印出大小與 SHA-256。預設在 [export_presets.cfg](export_presets.cfg)：Windows x86_64 內嵌 pck、macOS universal ad-hoc 簽章、網頁版單執行緒（GitHub Pages 不能設 COOP／COEP 標頭） |
| 快照 | `python3 tools/release.py snapshot v0.1.0 <空資料夾>`：`git archive`＋`release/public/`（公開 README、LICENSE、Issue 範本、截圖）放到根目錄；掃描不乾淨就刪掉輸出。推公開倉庫前再跑 `gitleaks dir <資料夾> --redact` |
| 本機試網頁版 | `cd build/web && python3 -m http.server <埠>` 後用瀏覽器開（直接開 `index.html` 不行） |

匯出相關的專案設定：`textures/vram_compression/import_etc2_astc=true`（macOS universal 要求）、`internationalization/locale/include_text_server_data=true`（匯出版要有 ICU 斷行資料，中文標點才不會排在行首）。`main.gd` 啟動時把介面字型加進預設字型的後備：網頁版沒有系統字型可借，Windows 也不一定有繁中字型，所以介面字型收全部遊戲 `.gd` 的字（`test_release.test_ui_font_covers_game_strings` 抓缺字）。網頁版的「結束遊戲」不可選。

macOS 版沒有公證：玩家第一次打開會被擋下，要到「系統設定 → 隱私權與安全性」按「仍要打開」，或 `xattr -dr com.apple.quarantine 雙子星玉米人.app`。

## 聲音（MV-SLICE-001d1a、d1b）

全域單例 `Audio`（autoload，[core/audio/audio.gd](core/audio/audio.gd)）＋資料表 [core/audio/sound_table.gd](core/audio/sound_table.gd)；音檔在 `art/audio/`（環境音與配樂是 OGG，用 `oggenc -q 6` 從 `assets-test/` 的 WAV 轉；短音效是 WAV）。

| 項目 | 做法 |
|---|---|
| 匯流排 | `Master`（HardLimiter，上限 `MASTER_CEILING_DB`）底下 `Music`、`Amb`、`Sfx`、`Tell`；音量在 `BUS_DB` |
| 前兆優先 | `Music`、`Amb` 的壓縮器以 `Tell` 為 sidechain：前兆一響就被壓低（實測平均 6.7 dB）；同一種前兆 0.15 秒內只播一次 |
| 短音效 | `Audio.play(id)`；`files` 有多個時隨機選、不連續重複 |
| 新增音效 | 在 `SOUNDS` 補一列。`feedback.play(id)` 的 id 在 `SOUNDS` 裡就播正式檔，不在就播 `core/fx/sfx.gd` 的合成佔位 |
| 環境音 | 換房時依房間 `theme`（`THEME_AMBIENCE`）交叉淡化 1.5 秒；同一個 id 不重啟；`GameWorld` 釋放時淡出 |
| 距離層 | 玻璃顫音（群組 `audio_glass`：房間裡活著的假光造物）、危險嗡聲（群組 `audio_danger`：地上荊棘，量到荊棘邊緣）；依 `Audio.listener`（角色）到最近來源的距離調音量 |
| 配樂 | `boss_fight` 進 `FIGHT` 淡入 MUS-B01（每段從頭）、離開淡出；覺醒過場放 MUS-S01 |
| 語彙 | 前兆（一般敵人進前搖、Seven Macaw 前搖訊號出現）、真實（篝火休息）、活物（祖母、老鼠、老夫婦登場）、虛假（碎裂、玻璃層）、危險（荊棘） |
| 前兆播放器 | 前兆用 2 個專用播放器（d1b）；一般音效的 12 個輪流播放器截不到前兆 |
| 依距離衰減 | `Audio.play_at(id, pos)`（`AudioStreamPlayer2D`，2000 px 外聽不到）：敵人的移動、攻擊、反光型光束；`*_move` 同一種 0.1 秒內只放一次 |
| 角色動作 | `Feedback.wire_moves(player)`（房間與 Boss 戰共用）：揮擊、命中依出招當下的武器（`swing_id`／`hit_id`），換人依兄弟（`swap_id`），起跳、落地（離地 ≥ 0.1 秒才算）、翻滾、招架落空 |
| 腳步 | `twin_anims.json` 的 `run`、`walk` 有 `steps`（著地格）；遊戲中由 `twin_animator`、過場由 `actor`（只有雙胞胎）播到就放。地面由 `Audio.floor_at(pos)` 問目前的房間或 Boss 戰（`floor_material_at`）：房間 `floor: "hard"`、站在平台上、宮殿（x 在 `Palace.LEFT～RIGHT`）是硬地 |
| 過場 | `cs.sfx(id)`：被跳過就不放 |
| 檢查 | `test_d1b.test_every_used_id_is_in_table`：程式裡 `feedback.play`、`Audio.play(_at)`、`sfx` 用到的 id 都要在 `SOUNDS`（合成佔位只當備援） |

錄聲音展示影片（約 340 秒；開發時可用 `SOUNDTOUR_ONLY=moves,menus` 只跑部分段落：`ground`、`moves`、`menus`、`pickups`、`forest`、`reflector`、`ground_cutscenes`、`boss`）：

```bash
godot --path game --resolution 1920x1080 --write-movie /tmp/d1a_tour.avi -- --sound-tour
```

## 存檔

一個欄位：`user://slot1.json`（macOS 在 `~/Library/Application Support/Godot/app_userdata/雙子星玉米人/`）。內容是 GameState 加版本欄位；檔案壞掉或版本不符時當成沒有存檔。

## 自測

```bash
godot --headless --path game -- --self-test 2>&1 | grep -E "SELFTEST (FAIL|SUMMARY)|SCRIPT ERROR|Parse Error"
```

開發時只跑部分測試檔：`SELFTEST_ONLY=test_rig godot --headless --path game -- --self-test`（檔名含這段字的才跑；驗收一律全跑）。

通過＝`fail=0`，而且沒有 `SCRIPT ERROR`／`Parse Error`（執行中的 SCRIPT ERROR 會中斷該項測試但仍記為 PASS，要另外看）。測試在 `tests/test_*.gd`，從原型搬來時刪改的項目見 [tests/README.md](tests/README.md)。`test_walkthrough.gd` 會從新遊戲自動走到結尾。

## 驗收步驟（Brian，手把）

1. 從新遊戲玩到出口：流程不卡、提示看得懂；記下花的時間（可能少於 30 分鐘）。
2. 中途關掉遊戲，用「繼續」從最後休息的地方接著玩。
3. 戰鬥與 Boss 的手感和原型一樣（`godot --path prototypes/core -- --boss` 對照）。

## 數值

全部在 `core/tuning/combat_tuning.gd`，照原型結案值；切片新增「經濟」「動物技能」兩個群組。開發版按 F9 存回 `.tres` 並印出數值表。
