extends RefCounted
# 破綻條純邏輯（MV-PROTO-003 規格書第 1 節、BOSS-5）。上限由呼叫端傳入（每幀讀 tn）。

var value := 0


## 已滿時不累積、回傳 false；這次加到上限回傳 true（值不超過上限）
func add(amount: int, cap: int) -> bool:
	if is_full(cap):
		return false
	value = mini(value + amount, cap)
	return is_full(cap)


func is_full(cap: int) -> bool:
	return value >= cap


## 硬直結束仍未設局：退回一半
func miss(reset_to: int) -> void:
	value = reset_to


func clear() -> void:
	value = 0
