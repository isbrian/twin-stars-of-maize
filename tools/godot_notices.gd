extends SceneTree
# 印出 Godot 引擎與內含第三方函式庫的授權聲明（MV-RELEASE-001 最終審查：散布發行版要附上）。
# 用法：godot --headless --path game --script <本檔絕對路徑>；tools/release.py 擷取 BEGIN～END 之間的文字。


func _init() -> void:
	var out := PackedStringArray(["=== NOTICES BEGIN ===", "Godot Engine (https://godotengine.org)", "", Engine.get_license_text(), ""])
	out.append("Third-party components included in Godot Engine:")
	for c in Engine.get_copyright_info():
		out.append("")
		out.append("- %s" % c.name)
		for part in c.parts:
			for line in part.copyright:
				out.append("  Copyright: %s" % line)
			out.append("  License: %s" % part.license)
	out.append("")
	out.append("Licenses:")
	var lic := Engine.get_license_info()
	for name in lic:
		out.append("")
		out.append("----- %s -----" % name)
		out.append(lic[name])
	out.append("=== NOTICES END ===")
	print("\n".join(out))
	quit()
