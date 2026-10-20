extends RefCounted
# Boss 招式的基底（MV-PROTO-003 PROTO3-7）：每招一個小腳本，Boss 主體每幀呼叫 tick()。
# 不 preload seven_macaw.gd（避免循環 preload）；需要 Boss 常數時讀 boss.SIZE；身體大小讀 boss.body_rect／faced_body()（有骨架時是骨架的身體＋腳）。

const Light := preload("res://core/boss/light_source.gd")

enum Sig { NONE, PARRY, UNPARRY }  # 前搖訊號：無／白色圓形／暗紫鋸齒

var boss
var step := 0
var t := 0.0  # 目前階段經過的秒數（子類別在 tick 開頭累加）
var telegraphing := false
var attacking := false
var signal_kind := Sig.NONE
var body_interruptible := true  # 前搖中能否被射身體打斷


func begin() -> void:
	pass


## 回傳 true＝招式結束
func tick(_delta: float) -> bool:
	return true


func interruptible() -> bool:
	return telegraphing and body_interruptible


## 微亮被射中；回傳 true＝招式就此結束
func on_glow_hit() -> bool:
	return false


func on_parried() -> void:
	end_strike()


func cancel() -> void:
	end_strike()
	telegraphing = false
	boss.light.set_state(Light.State.OFF)


## 招式音效（MV-SLICE-001d1a）
func sfx(id: StringName) -> void:
	Audio.play(id)


func go(s: int) -> void:
	step = s
	t = 0.0


## 前搖結束、判定開始
func strike() -> void:
	telegraphing = false
	attacking = true
	boss.hitbox.start()


func end_strike() -> void:
	boss.hitbox.stop()
	attacking = false


## 招式自己的額外繪圖（畫在 Boss 身上）
func draw(_ci: CanvasItem) -> void:
	pass
