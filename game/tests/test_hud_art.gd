extends "res://tests/base_test.gd"
# MV-SLICE-001b1 Task 7：HUD 換成素材（版面同 a）。

func test_hud_textures_load() -> void:
	var hud = Hud.new()
	var t: Dictionary = hud.pip_textures()
	for k in ["health_full", "health_empty", "heal_full", "heal_empty", "res_frame", "res_fill", "skill_frame", "rat", "cacao", "soup"]:
		check(t.get(k) is Texture2D, "HUD 素材 %s 載入" % k)
	hud.free()


func test_weapon_icon_mapping() -> void:
	var seen := {}
	for w in [Weapons.Weapon.AXE, Weapons.Weapon.STICK, Weapons.Weapon.BALLGEAR]:
		var tex: Texture2D = Hud.weapon_icon(w)
		check(tex != null and not seen.has(tex), "%s 有自己的圖示" % Weapons.NAMES[w])
		seen[tex] = true
	check(Hud.weapon_icon(-1) == null, "沒有武器時沒有圖示")


# ---- MV-SLICE-001d2c：HUD 調整（H1～H3） ----

func test_hud_readability_constants() -> void:
	check(Hud.FONT_SIZE >= 33, "HUD 字級放大約 1.3 倍（%d）" % Hud.FONT_SIZE)
	var on: Color = Hud.name_color(true)
	var off: Color = Hud.name_color(false)
	check(off.a >= 0.7, "沒上場的兄弟看得清楚（不透明度 %.2f）" % off.a)
	check(off != on and off.get_luminance() * off.a < on.get_luminance() * on.a, "仍比場上的人暗")
	check(Hud.EMPTY_TINT.get_luminance() <= 0.6, "空格調暗（亮度 %.2f）" % Hud.EMPTY_TINT.get_luminance())
	check(Hud.OUTLINE > 0, "文字有描邊")


func test_hud_objective_below_skill_frame() -> void:
	var frame_h: float = Hud.TEXTURES.skill_frame.get_height()
	check(Hud.OBJECTIVE_Y - Hud.FONT_SIZE > Hud.SKILL_Y + frame_h, "目標文字不壓到技能框")


func test_hud_pip_tint_and_longest_objective() -> void:
	check(Hud.pip_tint(true) == Color.WHITE and Hud.pip_tint(false) == Hud.EMPTY_TINT, "有的格原色、空格調暗")
	var src := FileAccess.get_file_as_string("res://ui/hud.gd")
	check(src.count("pip_tint(i < h.hp)") == 1 and src.count("pip_tint(i < h.heal_charges)") == 1, "血格與治療次數都用 pip_tint 畫")
	check(src.count("name_color(i == player.twin_index)") == 1, "名字用 name_color 畫")
	var longest := "目標：清理田地——灌木用斧頭（胡納普）、土塊用掘棒（希巴拉克）"
	var w: float = ThemeDB.fallback_font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.FONT_SIZE).x
	check(40.0 + w < 1920.0, "最長的目標文字放得下（寬 %.0f px）" % w)
	print("HUD longest objective width %.0f" % w)
