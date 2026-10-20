# 自測

```bash
godot --headless --path game -- --self-test 2>&1 | grep -E "SELFTEST (FAIL|SUMMARY)|SCRIPT ERROR|Parse Error"
```

通過＝`fail=0`，而且沒有 `SCRIPT ERROR`／`Parse Error`（執行期錯誤只印 SCRIPT ERROR、該項仍記為 PASS）。

- `runner.gd`：依檔名載入 `test_*.gd`，每個檔案的 `test_` 方法依名稱排序執行。
- `base_test.gd`：共用的常數與輔助函式（從 `prototypes/core/tests/self_test.gd` 拆出）。
- 測試檔依系統分：`test_combat`（參數檔、血量、判定框、回饋）、`test_player`（移動、攻擊、受擊、吹箭、換人、武器、招架、二段跳、工具）、`test_enemies`（假光造物）、`test_boss`（Seven Macaw 與 Boss 戰流程）、`test_ui`（HUD、文字卡）；之後各 Task 新增自己的測試檔。

## 從原型搬來時刪除的測試（MV-SLICE-001a Task 1）

原型 171 項，搬來 148 項。刪除的 23 項只測原型專屬、正式專案不搬的東西：

| 測試 | 刪除原因 |
|---|---|
| `test_room_layout`、`test_room_pit_respawns_at_edge`、`test_room_reset_restores_everything`、`test_room_death_resets_room`、`test_room_full_jump_near_crawlers`、`test_room_flyer_leaves_pit_segment_alone`、`test_room_camera_snaps_after_reset_and_pit`、`test_room_enemy_falling_into_pit_dies`、`test_room_reset_clears_darts` | 練習房（`level/test_room.gd`）不搬 |
| `test_pogo_chain_of_three_crosses_pit`、`test_pogo_cannot_skip_first_crystal`、`test_pogo_cannot_skip_middle_crystal`、`test_pogo_cannot_skip_last_crystal` | 練習房裡的彈跳鏈；下劈彈跳本身仍由 `test_down_slash_on_crystal_bounces` 等測試涵蓋 |
| `test_explore_ledge1_needs_double_jump`、`test_explore_pit2_needs_xbalanque`、`test_explore_ledge3_needs_both`、`test_room_pit2_respawns_at_edge`、`test_room_reset_recalls_tool`、`test_room_has_dummy_and_barriers` | MV-PROTO-002 的探索區（練習房的一部分）不搬；二段跳與工具的規則仍由 `test_player` 涵蓋 |
| `test_dummy_attacks_periodically_and_never_dies`、`test_dummy_can_be_parried`、`test_dummy_restarts_cycle_after_parry_stagger` | 招架練習對象不搬；招架規則仍由 `test_parry_*` 涵蓋 |
| `test_start_menu_items_and_toggle` | 原型的開頭選單不搬；正式主選單在 Task 12 |
| `test_menu_back_needs_second_press_in_boss`（Task 11 刪除） | Boss 段落的「2 秒內按兩次 Esc 回選單」改成正式的暫停選單 |

## 搬來時改過的測試

| 測試 | 改動 |
|---|---|
| `test_input_scheme_a_registered` | `menu_back` 改名 `pause`；新增 `skill_1`、`skill_2`、`interact` |
| `test_launch_args_parse` | 改成正式專案的參數（`--room`；移除展示模式與測試代號） |
| `test_parry_success_staggers_crawler`、`test_parry_late_is_whiff`、`test_parry_whiff_recorded_when_left_by_swap_or_weapon_key`、`test_throw_fruit_parried_shatters` | 原本只讀招架紀錄的「第 1 分鐘」；整套自測跑超過 1 分鐘後就會失敗（原型在 develop 上也已經失敗）。改用 `parry_totals()` 加總所有分鐘 |
