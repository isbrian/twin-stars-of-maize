extends RefCounted
# 聲音資料表（MV-SLICE-001d1a）：id → 檔案、匯流排、音量、是否循環；房間 theme → 環境音；混音常數。
# d1b 新音效只要在 SOUNDS 補一列，feedback.play() 的同名 id 就會從合成佔位換成正式檔。
# 混音初始值照規格書，試聽後在這裡調。

const BUS_DB := {"Music": -8.0, "Amb": -12.0, "Sfx": -3.0, "Tell": 0.0}
## 前兆壓低配樂與環境音的 sidechain 壓縮器：實測（不可招架前兆每 0.6 秒一個）Amb 平均被壓低 6.7 dB（目標 6～8 dB）
const DUCK_THRESHOLD_DB := -20.0
const DUCK_RATIO := 2.5
const MASTER_CEILING_DB := -3.0  # Master 的 HardLimiter 上限（樣本峰值）；實測取樣點之間還會再高約 1.2～1.7 dB，這樣輸出才 ≤ -1 dBTP（AUDIO_SPEC 第 8 節）
const LAYER_MAX_DB := -14.0  # 距離層最大音量（相對 Amb）
const TELL_THROTTLE := 0.15  # 同一種前兆的最短間隔（秒）
const AMB_FADE := 1.5
const MUSIC_IN := 1.0
const MUSIC_OUT := 1.5

## 房間 theme → 環境音；Boss 段落沒有 theme（""）
const THEME_AMBIENCE := {"home": &"amb_02", "field": &"amb_02", "yard": &"amb_03", "forest": &"amb_01", "": &"amb_01"}

const Weapons := preload("res://core/player/weapons.gd")


## 揮擊、命中依出招當下的武器（斧頭；掘棒與球具下劈用掘棒）（MV-SLICE-001d1b）
static func swing_id(weapon: int) -> StringName:
	return &"wpn_axe_swing" if weapon == Weapons.Weapon.AXE else &"wpn_stick_swing"


static func hit_id(weapon: int) -> StringName:
	return &"wpn_axe_hit" if weapon == Weapons.Weapon.AXE else &"wpn_stick_hit"


## 換人：被切到的兄弟的樂器短音（0 胡納普、1 希巴拉克；SLICE-d-7）
static func swap_id(twin_index: int) -> StringName:
	return &"cmb_swap_hunahpu" if twin_index == 0 else &"cmb_swap_xbalanque"


const SOUNDS := {
	&"boss_sm_beam_charge": {"files": ["res://art/audio/sfx_boss_sm_beam_charge_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_beam_fire": {"files": ["res://art/audio/sfx_boss_sm_beam_fire_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_crack": {"files": ["res://art/audio/sfx_boss_sm_crack_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_dive": {"files": ["res://art/audio/sfx_boss_sm_dive_01.wav", "res://art/audio/sfx_boss_sm_dive_02.wav", "res://art/audio/sfx_boss_sm_dive_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_eat": {"files": ["res://art/audio/sfx_boss_sm_eat_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_flail": {"files": ["res://art/audio/sfx_boss_sm_flail_01.wav", "res://art/audio/sfx_boss_sm_flail_02.wav", "res://art/audio/sfx_boss_sm_flail_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_flap": {"files": ["res://art/audio/sfx_boss_sm_flap_01.wav", "res://art/audio/sfx_boss_sm_flap_02.wav", "res://art/audio/sfx_boss_sm_flap_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_flash": {"files": ["res://art/audio/sfx_boss_sm_flash_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_fruit_break": {"files": ["res://art/audio/sfx_boss_sm_fruit_break_01.wav", "res://art/audio/sfx_boss_sm_fruit_break_02.wav", "res://art/audio/sfx_boss_sm_fruit_break_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_gather": {"files": ["res://art/audio/sfx_boss_sm_gather_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_kneel": {"files": ["res://art/audio/sfx_boss_sm_kneel_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_light_fade": {"files": ["res://art/audio/sfx_boss_sm_light_fade_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_light_pull": {"files": ["res://art/audio/sfx_boss_sm_light_pull_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_pillar_strike": {"files": ["res://art/audio/sfx_boss_sm_pillar_strike_01.wav", "res://art/audio/sfx_boss_sm_pillar_strike_02.wav", "res://art/audio/sfx_boss_sm_pillar_strike_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_pillar_warn": {"files": ["res://art/audio/sfx_boss_sm_pillar_warn_01.wav", "res://art/audio/sfx_boss_sm_pillar_warn_02.wav", "res://art/audio/sfx_boss_sm_pillar_warn_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_pounce": {"files": ["res://art/audio/sfx_boss_sm_pounce_01.wav", "res://art/audio/sfx_boss_sm_pounce_02.wav", "res://art/audio/sfx_boss_sm_pounce_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_throne_hit": {"files": ["res://art/audio/sfx_boss_sm_throne_hit_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_throw": {"files": ["res://art/audio/sfx_boss_sm_throw_01.wav", "res://art/audio/sfx_boss_sm_throw_02.wav", "res://art/audio/sfx_boss_sm_throw_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"boss_sm_wail": {"files": ["res://art/audio/sfx_boss_sm_wail_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"evt_cover": {"files": ["res://art/audio/sfx_evt_cover_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"voc_alive": {"files": ["res://art/audio/sfx_voc_alive_01.wav", "res://art/audio/sfx_voc_alive_02.wav", "res://art/audio/sfx_voc_alive_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"voc_glass": {"files": ["res://art/audio/sfx_voc_glass_01.wav", "res://art/audio/sfx_voc_glass_02.wav", "res://art/audio/sfx_voc_glass_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"voc_real": {"files": ["res://art/audio/sfx_voc_real_01.wav", "res://art/audio/sfx_voc_real_02.wav", "res://art/audio/sfx_voc_real_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"tell_heavy": {"files": ["res://art/audio/sfx_voc_tell_heavy_01.wav", "res://art/audio/sfx_voc_tell_heavy_02.wav", "res://art/audio/sfx_voc_tell_heavy_03.wav"], "bus": "Tell", "db": 0.0, "loop": false},
	&"tell_parry": {"files": ["res://art/audio/sfx_voc_tell_parry_01.wav", "res://art/audio/sfx_voc_tell_parry_02.wav", "res://art/audio/sfx_voc_tell_parry_03.wav"], "bus": "Tell", "db": 0.0, "loop": false},
	&"shatter": {"files": ["res://art/audio/sfx_voc_glass_01.wav", "res://art/audio/sfx_voc_glass_02.wav", "res://art/audio/sfx_voc_glass_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"amb_01": {"files": ["res://art/audio/amb_01.ogg"], "bus": "Amb", "db": 0.0, "loop": true},
	&"amb_02": {"files": ["res://art/audio/amb_02.ogg"], "bus": "Amb", "db": 0.0, "loop": true},
	&"amb_03": {"files": ["res://art/audio/amb_03.ogg"], "bus": "Amb", "db": 0.0, "loop": true},
	&"amb_01_glass": {"files": ["res://art/audio/amb_01_glass.ogg"], "bus": "Amb", "db": 0.0, "loop": true},
	&"voc_danger_loop": {"files": ["res://art/audio/voc_danger_loop.ogg"], "bus": "Amb", "db": 0.0, "loop": true},
	&"mus_b01": {"files": ["res://art/audio/mus_b01.ogg"], "bus": "Music", "db": 0.0, "loop": true},
	&"mus_s01": {"files": ["res://art/audio/mus_s01.ogg"], "bus": "Music", "db": 0.0, "loop": false},
	# MV-SLICE-001d1b：MV-ASSET-021 的 61 種
	&"abl_rat_burrow": {"files": ["res://art/audio/sfx_abl_rat_burrow_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"abl_rat_emerge": {"files": ["res://art/audio/sfx_abl_rat_emerge_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"abl_tool_chop": {"files": ["res://art/audio/sfx_abl_tool_chop_01.wav", "res://art/audio/sfx_abl_tool_chop_02.wav", "res://art/audio/sfx_abl_tool_chop_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"abl_tool_dig": {"files": ["res://art/audio/sfx_abl_tool_dig_01.wav", "res://art/audio/sfx_abl_tool_dig_02.wav", "res://art/audio/sfx_abl_tool_dig_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cmb_heal": {"files": ["res://art/audio/sfx_cmb_heal_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cmb_hurt": {"files": ["res://art/audio/sfx_cmb_hurt_01.wav", "res://art/audio/sfx_cmb_hurt_02.wav", "res://art/audio/sfx_cmb_hurt_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cmb_swap_hunahpu": {"files": ["res://art/audio/sfx_cmb_swap_hunahpu_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cmb_swap_xbalanque": {"files": ["res://art/audio/sfx_cmb_swap_xbalanque_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_animals_run": {"files": ["res://art/audio/sfx_cs_animals_run_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_arm_restore": {"files": ["res://art/audio/sfx_cs_arm_restore_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_bush_regrow": {"files": ["res://art/audio/sfx_cs_bush_regrow_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_food_place": {"files": ["res://art/audio/sfx_cs_food_place_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_gem_pluck": {"files": ["res://art/audio/sfx_cs_gem_pluck_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_grass_crouch": {"files": ["res://art/audio/sfx_cs_grass_crouch_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_jewels_gather": {"files": ["res://art/audio/sfx_cs_jewels_gather_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_lunge": {"files": ["res://art/audio/sfx_cs_lunge_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_macaw_fall": {"files": ["res://art/audio/sfx_cs_macaw_fall_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_net_drop": {"files": ["res://art/audio/sfx_cs_net_drop_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_rat_climb": {"files": ["res://art/audio/sfx_cs_rat_climb_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_rat_gnaw": {"files": ["res://art/audio/sfx_cs_rat_gnaw_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_rope_snap": {"files": ["res://art/audio/sfx_cs_rope_snap_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_sit_fall": {"files": ["res://art/audio/sfx_cs_sit_fall_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_teeth_swap": {"files": ["res://art/audio/sfx_cs_teeth_swap_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"cs_wing_wrench": {"files": ["res://art/audio/sfx_cs_wing_wrench_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"enm_crawler_attack": {"files": ["res://art/audio/sfx_enm_crawler_attack_01.wav", "res://art/audio/sfx_enm_crawler_attack_02.wav", "res://art/audio/sfx_enm_crawler_attack_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"enm_crawler_move": {"files": ["res://art/audio/sfx_enm_crawler_move_01.wav", "res://art/audio/sfx_enm_crawler_move_02.wav", "res://art/audio/sfx_enm_crawler_move_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"enm_flyer_attack": {"files": ["res://art/audio/sfx_enm_flyer_attack_01.wav", "res://art/audio/sfx_enm_flyer_attack_02.wav", "res://art/audio/sfx_enm_flyer_attack_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"enm_flyer_move": {"files": ["res://art/audio/sfx_enm_flyer_move_01.wav", "res://art/audio/sfx_enm_flyer_move_02.wav", "res://art/audio/sfx_enm_flyer_move_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"enm_reflector_block": {"files": ["res://art/audio/sfx_enm_reflector_block_01.wav", "res://art/audio/sfx_enm_reflector_block_02.wav", "res://art/audio/sfx_enm_reflector_block_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"enm_reflector_move": {"files": ["res://art/audio/sfx_enm_reflector_move_01.wav", "res://art/audio/sfx_enm_reflector_move_02.wav", "res://art/audio/sfx_enm_reflector_move_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"lvl_barrier_break": {"files": ["res://art/audio/sfx_lvl_barrier_break_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"lvl_barrier_thud": {"files": ["res://art/audio/sfx_lvl_barrier_thud_01.wav", "res://art/audio/sfx_lvl_barrier_thud_02.wav", "res://art/audio/sfx_lvl_barrier_thud_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"lvl_pogo_crystal": {"files": ["res://art/audio/sfx_lvl_pogo_crystal_01.wav", "res://art/audio/sfx_lvl_pogo_crystal_02.wav", "res://art/audio/sfx_lvl_pogo_crystal_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"lvl_thorn_hurt": {"files": ["res://art/audio/sfx_lvl_thorn_hurt_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_double_jump": {"files": ["res://art/audio/sfx_mov_double_jump_01.wav", "res://art/audio/sfx_mov_double_jump_02.wav", "res://art/audio/sfx_mov_double_jump_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_jump": {"files": ["res://art/audio/sfx_mov_jump_01.wav", "res://art/audio/sfx_mov_jump_02.wav", "res://art/audio/sfx_mov_jump_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_land": {"files": ["res://art/audio/sfx_mov_land_01.wav", "res://art/audio/sfx_mov_land_02.wav", "res://art/audio/sfx_mov_land_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_roll": {"files": ["res://art/audio/sfx_mov_roll_01.wav", "res://art/audio/sfx_mov_roll_02.wav", "res://art/audio/sfx_mov_roll_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_step_dirt_hunahpu": {"files": ["res://art/audio/sfx_mov_step_dirt_hunahpu_01.wav", "res://art/audio/sfx_mov_step_dirt_hunahpu_02.wav", "res://art/audio/sfx_mov_step_dirt_hunahpu_03.wav", "res://art/audio/sfx_mov_step_dirt_hunahpu_04.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_step_dirt_xbalanque": {"files": ["res://art/audio/sfx_mov_step_dirt_xbalanque_01.wav", "res://art/audio/sfx_mov_step_dirt_xbalanque_02.wav", "res://art/audio/sfx_mov_step_dirt_xbalanque_03.wav", "res://art/audio/sfx_mov_step_dirt_xbalanque_04.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_step_hard_hunahpu": {"files": ["res://art/audio/sfx_mov_step_hard_hunahpu_01.wav", "res://art/audio/sfx_mov_step_hard_hunahpu_02.wav", "res://art/audio/sfx_mov_step_hard_hunahpu_03.wav", "res://art/audio/sfx_mov_step_hard_hunahpu_04.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"mov_step_hard_xbalanque": {"files": ["res://art/audio/sfx_mov_step_hard_xbalanque_01.wav", "res://art/audio/sfx_mov_step_hard_xbalanque_02.wav", "res://art/audio/sfx_mov_step_hard_xbalanque_03.wav", "res://art/audio/sfx_mov_step_hard_xbalanque_04.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"npc_exchange": {"files": ["res://art/audio/sfx_npc_exchange_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"pick_cacao": {"files": ["res://art/audio/sfx_pick_cacao_01.wav", "res://art/audio/sfx_pick_cacao_02.wav", "res://art/audio/sfx_pick_cacao_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"pick_fragment": {"files": ["res://art/audio/sfx_pick_fragment_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"pick_item": {"files": ["res://art/audio/sfx_pick_item_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"ui_back": {"files": ["res://art/audio/sfx_ui_back_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"ui_confirm": {"files": ["res://art/audio/sfx_ui_confirm_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"ui_move": {"files": ["res://art/audio/sfx_ui_move_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"ui_page_close": {"files": ["res://art/audio/sfx_ui_page_close_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"ui_page_open": {"files": ["res://art/audio/sfx_ui_page_open_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"ui_skill_switch": {"files": ["res://art/audio/sfx_ui_skill_switch_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_axe_hit": {"files": ["res://art/audio/sfx_wpn_axe_hit_01.wav", "res://art/audio/sfx_wpn_axe_hit_02.wav", "res://art/audio/sfx_wpn_axe_hit_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_axe_swing": {"files": ["res://art/audio/sfx_wpn_axe_swing_01.wav", "res://art/audio/sfx_wpn_axe_swing_02.wav", "res://art/audio/sfx_wpn_axe_swing_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_dart_fire": {"files": ["res://art/audio/sfx_wpn_dart_fire_01.wav", "res://art/audio/sfx_wpn_dart_fire_02.wav", "res://art/audio/sfx_wpn_dart_fire_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_dart_hit": {"files": ["res://art/audio/sfx_wpn_dart_hit_01.wav", "res://art/audio/sfx_wpn_dart_hit_02.wav", "res://art/audio/sfx_wpn_dart_hit_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_dart_weak": {"files": ["res://art/audio/sfx_wpn_dart_weak_01.wav", "res://art/audio/sfx_wpn_dart_weak_02.wav", "res://art/audio/sfx_wpn_dart_weak_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_parry_miss": {"files": ["res://art/audio/sfx_wpn_parry_miss_01.wav", "res://art/audio/sfx_wpn_parry_miss_02.wav", "res://art/audio/sfx_wpn_parry_miss_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_parry_ok": {"files": ["res://art/audio/sfx_wpn_parry_ok_01.wav", "res://art/audio/sfx_wpn_parry_ok_02.wav", "res://art/audio/sfx_wpn_parry_ok_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_stick_hit": {"files": ["res://art/audio/sfx_wpn_stick_hit_01.wav", "res://art/audio/sfx_wpn_stick_hit_02.wav", "res://art/audio/sfx_wpn_stick_hit_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"wpn_stick_swing": {"files": ["res://art/audio/sfx_wpn_stick_swing_01.wav", "res://art/audio/sfx_wpn_stick_swing_02.wav", "res://art/audio/sfx_wpn_stick_swing_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	# MV-SLICE-001d1b：取代合成佔位的別名（feedback.play 原本的 id）
	&"double_jump": {"files": ["res://art/audio/sfx_mov_double_jump_01.wav", "res://art/audio/sfx_mov_double_jump_02.wav", "res://art/audio/sfx_mov_double_jump_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"dart": {"files": ["res://art/audio/sfx_wpn_dart_fire_01.wav", "res://art/audio/sfx_wpn_dart_fire_02.wav", "res://art/audio/sfx_wpn_dart_fire_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"hurt": {"files": ["res://art/audio/sfx_cmb_hurt_01.wav", "res://art/audio/sfx_cmb_hurt_02.wav", "res://art/audio/sfx_cmb_hurt_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"heal": {"files": ["res://art/audio/sfx_cmb_heal_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"pogo": {"files": ["res://art/audio/sfx_lvl_pogo_crystal_01.wav", "res://art/audio/sfx_lvl_pogo_crystal_02.wav", "res://art/audio/sfx_lvl_pogo_crystal_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"barrier_break": {"files": ["res://art/audio/sfx_lvl_barrier_break_01.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"parry": {"files": ["res://art/audio/sfx_wpn_parry_ok_01.wav", "res://art/audio/sfx_wpn_parry_ok_02.wav", "res://art/audio/sfx_wpn_parry_ok_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"chop": {"files": ["res://art/audio/sfx_abl_tool_chop_01.wav", "res://art/audio/sfx_abl_tool_chop_02.wav", "res://art/audio/sfx_abl_tool_chop_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"interrupt": {"files": ["res://art/audio/sfx_wpn_dart_weak_01.wav", "res://art/audio/sfx_wpn_dart_weak_02.wav", "res://art/audio/sfx_wpn_dart_weak_03.wav"], "bus": "Sfx", "db": 0.0, "loop": false},
	&"tool_out": {"files": ["res://art/audio/sfx_wpn_stick_swing_01.wav", "res://art/audio/sfx_wpn_stick_swing_02.wav", "res://art/audio/sfx_wpn_stick_swing_03.wav"], "bus": "Sfx", "db": -4.0, "loop": false},
	# 反光型光束沿用 Seven Macaw 的光束聲、小 6 dB（A21-3）
	&"enm_reflector_beam_charge": {"files": ["res://art/audio/sfx_boss_sm_beam_charge_01.wav"], "bus": "Sfx", "db": -6.0, "loop": false},
	&"enm_reflector_beam_fire": {"files": ["res://art/audio/sfx_boss_sm_beam_fire_01.wav"], "bus": "Sfx", "db": -6.0, "loop": false},
}
