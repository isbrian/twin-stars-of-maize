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
