extends Node
# 全域參數（autoload「Tune」）。從編輯器 F5 執行時，在「遠端」場景樹選 /root/Tune，
# 檢查器裡展開 data 即可邊玩邊改；程式每幀讀取、不快取（PROTO1-1）。

const Tuning := preload("res://tuning/combat_tuning.gd")
const PATH := "res://tuning/combat_tuning.tres"

@export var data: Tuning = load(PATH)


## F9：存回參數檔；t、path 省略時把 data 存到 PATH（測試用其他路徑）
func save(t: Tuning = null, path: String = PATH) -> Error:
	if t == null:
		t = data
	return ResourceSaver.save(t, path)


## 有效值的 Markdown 數值表（貼進原型驗證計畫，驗收 5）；t 省略時用 data
func table(t: Tuning = null) -> String:
	if t == null:
		t = data
	var lines := PackedStringArray(["| 分組 | 參數 | 值 |", "|---|---|---|"])
	var group := ""
	for p in t.get_property_list():
		if p.usage & PROPERTY_USAGE_GROUP:
			group = p.name
		elif p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			lines.append("| %s | %s | %s |" % [group, p.name, str(t.get(p.name))])
	return "\n".join(lines)
