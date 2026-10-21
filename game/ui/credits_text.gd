extends RefCounted
# 製作說明的內容（MV-SLICE-001d2a）：主選單與片尾共用。每列 [樣式, 文字]，樣式 title／heading／body／gap。
# 第一列的標題由畫面填入 TitleMenu.GAME_TITLE（這裡不 preload title_menu，避免互相引用）。
# AI 揭露照 docs/legal/AI素材條款與揭露.md 規則 1：美術、音訊、程式都寫（SLICE-d2a-4）。
# 改了這裡的字要重跑 tools/font_subset.py（自測會抓缺字）。

const LINES := [
	["title", ""],
	["gap", ""],
	["heading", "製作"],
	["body", "Brian"],
	["gap", ""],
	["heading", "故事依據"],
	["body", "《Popol Vuh》Allen J. Christenson 英譯本"],
	["body", "Dennis Tedlock 英譯本（交叉參照）"],
	["gap", ""],
	["heading", "改編說明"],
	["body", "本作是根據原典的改編，不是原典的忠實重述。"],
	["body", "例如：老鼠以交換食物說出球具的下落（原典是被抓後燒了尾巴）；"],
	["body", "老鼠咬繩時祖母正在睡覺（原典是用蚊子支開祖母）；"],
	["body", "七金剛鸚鵡牙痛發狂、不分對象亂打（原典是他痛到主動求治）。"],
	["gap", ""],
	["heading", "AI 使用說明"],
	["body", "美術（角色、場景、物件、插圖）與音訊（音效、環境音、配樂）"],
	["body", "由 AI 生成（OpenAI ChatGPT／Codex），每一項都經作者審核後採用。"],
	["body", "程式由作者與 AI 協作完成。"],
	["gap", ""],
	["heading", "引擎"],
	["body", "Godot Engine 4（MIT 授權）"],
	["gap", ""],
	["heading", "字型"],
	["body", "Noto Serif TC、Noto Serif（SIL Open Font License 1.1）"],
	["gap", ""],
	["gap", ""],
	["heading", "謝謝遊玩"],
]
