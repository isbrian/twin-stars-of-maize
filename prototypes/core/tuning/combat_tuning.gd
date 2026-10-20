extends Resource
# MV-PROTO-001 的全部數值（規格書第 7 節）；MV-PROTO-002 新增換人、二段跳、掘棒、球具、工具、練習對象（規格書第 10 節）；
# MV-PROTO-003 新增 Boss（規格書第 7 節、實作計畫 D15）。
# 初始值寫在這裡；F9 把調整後的值存進 combat_tuning.tres（Godot 只寫入與預設不同的值）。
# 遊戲一律從 .tres 載入（Tune.data）；數值表以 F9 印出的有效值為準。

@export_group("移動")
@export var run_speed := 900.0
@export var accel_time := 0.05
@export var decel_time := 0.04

@export_group("跳躍")
@export var jump_height := 400.0
@export var jump_apex_time := 0.4
@export var jump_cut_multiplier := 0.4
@export var fall_gravity_multiplier := 0.6  # Brian 自評 2026-10-06：1.5、1.2、0.8 下落都太快，下劈彈跳跟不上
@export var max_fall_speed := 2200.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.1
@export var action_buffer := 0.1  # 翻滾、攻擊的輸入緩衝

@export_group("翻滾")
@export var roll_distance := 360.0
@export var roll_time := 0.3
@export var roll_iframe_start := 0.03
@export var roll_iframe_end := 0.25
@export var roll_cooldown := 0.35

@export_group("斧頭")
@export var axe_startup := 0.06
@export var axe_active := 0.08
@export var axe_recovery := 0.18
@export var axe_damage := 4
@export var axe_side_box := Vector2(140, 120)
@export var axe_up_box := Vector2(120, 150)
@export var axe_down_box := Vector2(120, 150)
@export var pogo_velocity := 1700.0
@export var down_slash_gravity_multiplier := 1.5  # 下劈中「下落時」的重力倍率＝原本的下落速度；按下的瞬間速度也換算成這個倍率
@export var side_hit_recoil := 220.0
@export var side_hit_recoil_time := 0.08

@export_group("掘棒")
@export var stick_startup := 0.10
@export var stick_active := 0.08
@export var stick_recovery := 0.22
@export var stick_damage := 4
@export var stick_side_box := Vector2(210, 60)
@export var stick_up_box := Vector2(60, 210)
@export var stick_down_box := Vector2(60, 210)

@export_group("球具")
@export var parry_window := 0.2
@export var parry_recovery := 0.35
@export var parry_stagger := 1.2
@export var ballgear_down_box := Vector2(120, 150)

@export_group("吹箭")
@export var dart_damage := 1
@export var dart_interval := 0.35
@export var dart_speed := 2400.0
@export var dart_range := 1400.0
@export var dart_stagger_time := 0.6
@export var dart_interrupt_cooldown := 3.0
@export var aim_deadzone := 0.3

@export_group("血量與治療")
@export var max_hp := 5
@export var hurt_stun_time := 0.25
@export var hurt_invuln_time := 1.0
@export var hurt_knockback := Vector2(500, -500)
@export var heal_charges := 2
@export var heal_amount := 2
@export var heal_time := 1.0

@export_group("回饋")
@export var hitstop_time := 0.05
@export var shake_strength := 8.0
@export var shake_time := 0.12

@export_group("敵人共用")
@export var enemy_rest := 0.2
@export var enemy_flash_time := 0.08

@export_group("爬行型")
@export var crawler_hp := 12
@export var crawler_damage := 1
@export var crawler_detect_range := 450.0
@export var crawler_patrol_speed := 150.0
@export var crawler_patrol_range := 200.0
@export var crawler_telegraph := 0.6
@export var crawler_lunge_speed := 1100.0
@export var crawler_lunge_time := 0.35
@export var crawler_recover := 0.8

@export_group("飛行型")
@export var flyer_hp := 8
@export var flyer_damage := 1
@export var flyer_detect_range := 700.0
@export var flyer_leash_range := 1000.0  # 玩家離出生點超過這個距離就不追
@export var flyer_hover_offset := Vector2(250, -350)
@export var flyer_hover_speed := 300.0
@export var flyer_telegraph := 0.7
@export var flyer_dive_speed := 1400.0
@export var flyer_dive_max := 900.0
@export var flyer_recover := 0.8

@export_group("換人")
@export var swap_cooldown := 0.3

@export_group("二段跳")
@export var double_jump_ratio := 0.75  # 第二跳高度＝jump_height × 這個比例

@export_group("工具")
@export var tool_speed := 900.0
@export var tool_chops := 3
@export var tool_chop_time := 0.6

@export_group("練習對象")
@export var dummy_interval := 2.0  # 前搖開始的間隔

@export_group("Boss")
@export var gauge_max := 100
@export var gauge_melee := 8
@export var gauge_parry := 15
@export var gauge_dart_interrupt := 10
@export var gauge_glow_hit := 12
@export var boss_stagger_time := 4.0
@export var gauge_miss_reset := 50
@export var boss_interrupt_stagger := 0.6
@export var whiteout_in := 0.3
@export var whiteout_hold := 1.4
@export var whiteout_out := 0.3
@export var boss_move_gap := 0.4  # 招式之間的空檔（計畫 D5）
@export var boss_fly_speed := 1100.0
@export var boss_walk_speed := 700.0
@export var boss_chase_max := 1.5  # 亂揮翅膀前走向玩家最多幾秒
@export var intro_eat_time := 3.0
@export var throw_telegraph := 0.6
@export var fruit_speed := 1000.0
@export var eat_time := 2.5
@export var dive_telegraph := 0.7
@export var dive_speed := 1600.0
@export var dive_rest := 1.2
@export var flash_telegraph := 1.0
@export var summon_telegraph := 0.6
@export var flail_telegraph := 0.5
@export var flail_active := 0.6
@export var flail_box := Vector2(380, 220)
@export var wail_time := 2.5
@export var charge_telegraph := 0.8
@export var charge_speed := 1800.0
@export var pillar_warn := 0.8
@export var pillar_active := 0.4
@export var pillar_count := 3
@export var pounce_telegraph := 0.6
@export var pounce_speed := 1400.0
@export var pounce_max := 900.0
@export var pounce_rest := 1.2
@export var beam_charge := 1.2
@export var beam_active := 0.5
@export var beam_band := Vector2(20, 100)  # 光束離地高度（下緣、上緣）
@export var beam_wobble := 1.0
@export var phase1_cycle: Array[String] = ["summon", "throw_fruit", "eat_fruit", "throw_fruit", "eat_fruit", "false_flash", "dive"]  # 假光閃耀後緊接俯衝：白茫時看不到前搖（Brian 手把試打 2026-10-06）
@export var phase2_cycle: Array[String] = ["flail", "wail", "throne_charge", "wail"]
@export var phase3_cycle: Array[String] = ["summon", "stagger_pounce", "beam", "stagger_pounce", "beam"]
@export var summon_cap_p1 := 1  # 每種
@export var summon_cap_p3 := 2
@export var card_min_time := 1.2  # 文字卡至少顯示幾秒才接受攻擊鍵（狂按攻擊時不會一閃而過）

@export_group("場地")
@export var pit_damage := 1


## 由跳躍高度與上升時間推出重力（px/s²）
func gravity() -> float:
	return 2.0 * jump_height / (jump_apex_time * jump_apex_time)


## 起跳速度（px/s，正值；使用時取負號向上）
func jump_velocity() -> float:
	return 2.0 * jump_height / jump_apex_time


func roll_speed() -> float:
	return roll_distance / roll_time
