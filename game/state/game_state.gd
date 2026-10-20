extends Node
# 遊戲狀態（autoload「GameState」；MV-SLICE-001a 規格「架構」）：唯一的狀態來源。
# 房間、事件、UI 只讀寫這裡；存檔就是 to_dict() 寫成 JSON。defeated 只在執行中，不存檔。

const Tuning := preload("res://core/tuning/combat_tuning.gd")
const Weapons := preload("res://core/player/weapons.gd")

const TOOL_TWIN := {Weapons.Weapon.AXE: 0, Weapons.Weapon.STICK: 1}  # SLICE-a6：胡納普斧頭、希巴拉克掘棒

## 存檔欄位與型別（from_dict 用來檢查）
const FIELDS := {
	"cacao": TYPE_INT, "weapons_owned": TYPE_ARRAY, "equip": TYPE_ARRAY, "skills_owned": TYPE_ARRAY,
	"skill_slots": TYPE_ARRAY, "slot2_unlocked": TYPE_BOOL, "soup": TYPE_INT, "skill_res": TYPE_INT,
	"skill_hits": TYPE_INT, "hints_seen": TYPE_DICTIONARY, "flags": TYPE_DICTIONARY,
	"stashes_taken": TYPE_DICTIONARY, "last_rest": TYPE_STRING, "hp": TYPE_INT, "heal_charges": TYPE_INT,
	"awakened": TYPE_BOOL,
}

var tn: Tuning = Tune.data

var cacao := 0
var weapons_owned: Array = []
var equip: Array = [-1, -1]  # 0＝Hunahpu、1＝Xbalanque；-1＝沒有武器
var skills_owned: Array = []
var skill_slots: Array = ["", ""]
var slot2_unlocked := false
var soup := 0
var skill_res := 0
var skill_hits := 0
var hints_seen := {}
var flags := {}
var stashes_taken := {}
var last_rest := "home"
var hp := 0
var heal_charges := 0
var awakened := false
var defeated := {}  # room_id → Array（被打倒的敵人索引）；休息時清空


func reset_new_game() -> void:
	cacao = 0
	weapons_owned = []
	equip = [-1, -1]
	skills_owned = []
	skill_slots = ["", ""]
	slot2_unlocked = false
	soup = 0
	skill_res = tn.skill_max
	skill_hits = 0
	hints_seen = {}
	flags = {}
	stashes_taken = {}
	last_rest = "home"
	hp = tn.max_hp
	heal_charges = tn.heal_charges
	awakened = false
	defeated = {}


func add_cacao(n: int) -> void:
	cacao += n


func can_buy_soup() -> bool:
	return cacao >= tn.soup_price and soup < tn.soup_max


func buy_soup() -> bool:
	if not can_buy_soup():
		return false
	cacao -= tn.soup_price
	soup += 1
	return true


## 治療次數用完後由 player.gd 呼叫（Loadout 設定 soup_source）
func take_soup() -> bool:
	if soup <= 0:
		return false
	soup -= 1
	return true


## 拿到武器：加入持有；有人還沒武器就裝上（先 Hunahpu 再 Xbalanque；SLICE-a6）
func give_weapon(w: int) -> void:
	if not weapons_owned.has(w):
		weapons_owned.append(w)
	if equip.has(w):
		return
	var twin: int = TOOL_TWIN.get(w, -1)
	if twin != -1 and equip[twin] == -1:  # 不管先撿哪一把（從祖母家進田地會先碰到掘棒）
		equip[twin] = w
		return
	for i in 2:
		if equip[i] == -1:
			equip[i] = w
			return


## 裝備頁：w 是對方正在用的就兩人互換（SLICE-a5）；沒持有的不能裝
func equip_weapon(twin: int, w: int) -> void:
	if not weapons_owned.has(w):
		return
	var other := 1 - twin
	if equip[other] == w:
		equip[other] = equip[twin]
	equip[twin] = w


func give_skill(id: String) -> void:
	if skills_owned.has(id):
		return
	skills_owned.append(id)
	for i in 2:
		if skill_slots[i] == "" and (i == 0 or slot2_unlocked):
			skill_slots[i] = id
			return


func use_skill(cost: int) -> bool:
	if skill_res < cost:
		return false
	skill_res -= cost
	return true


## 近戰打中敵人：每 skill_hits_per_charge 次回 1 格（B1-5c）
func on_weapon_hit() -> void:
	if skill_res >= tn.skill_max:
		skill_hits = 0
		return
	skill_hits += 1
	if skill_hits >= tn.skill_hits_per_charge:
		skill_hits = 0
		skill_res = mini(skill_res + 1, tn.skill_max)


## player.hit_landed 的接收端（hit_landed 只由近戰判定發出，吹箭不算）
func on_weapon_hit_from(_target: Node) -> void:
	on_weapon_hit()


func set_flag(name: String) -> void:
	flags[name] = true


func has_flag(name: String) -> bool:
	return flags.get(name, false)


## 篝火與祖母家（SLICE-a10）：回滿、敵人重生、記下地點
## 血量碎片的片數（MV-SLICE-001c4a）：藏點紀錄裡以 frag_ 開頭的（不另加存檔欄位，舊存檔照常讀得到）
func fragments() -> int:
	return stashes_taken.keys().filter(func(k): return String(k).begins_with("frag_") and stashes_taken[k] == true).size()


## 目前的血量上限：每 2 片碎片 +1
func max_hp_now() -> int:
	return tn.max_hp + fragments() / 2


func rest(at: String) -> void:
	hp = max_hp_now()
	heal_charges = tn.heal_charges
	skill_res = tn.skill_max
	skill_hits = 0
	defeated = {}
	last_rest = at


func to_dict() -> Dictionary:
	var d := {}
	for k in FIELDS:
		var v = get(k)
		d[k] = v.duplicate(true) if v is Array or v is Dictionary else v
	return d


## 存檔內容能不能用：欄位齊全、型別對（JSON 讀回的整數是 float，視為合法）、兩兄弟與兩個技能槽各一格、武器值存在
## （last_rest 是不是休息點由 save.gd 對照房間表檢查）
static func valid_state(d: Dictionary) -> bool:
	for k in FIELDS:
		if not d.has(k):
			return false
		var t := typeof(d[k])
		if t != FIELDS[k] and not (FIELDS[k] == TYPE_INT and t == TYPE_FLOAT):
			return false
	if d.equip.size() != 2 or d.skill_slots.size() != 2:
		return false
	for w in d.equip:
		if not (w is int or w is float) or int(w) < -1 or int(w) >= Weapons.Weapon.size():
			return false
	for w in d.weapons_owned:
		if not (w is int or w is float) or int(w) < 0 or int(w) >= Weapons.Weapon.size():
			return false
	for s in d.skill_slots:
		if not s is String:
			return false
	return true


## 內容不能用時回傳 false，且不改任何狀態
func from_dict(d: Dictionary) -> bool:
	if not valid_state(d):
		return false
	for k in FIELDS:
		var v = d[k]
		if FIELDS[k] == TYPE_INT:
			v = int(v)
		elif v is Array:
			v = _ints(v)
		set(k, v.duplicate(true) if v is Array or v is Dictionary else v)
	defeated = {}
	return true


## JSON 讀回的數字陣列是 float；武器值要轉回 int（字串陣列不動）
func _ints(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(int(x) if x is float else x)
	return out
