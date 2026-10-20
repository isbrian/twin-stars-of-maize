"""tools/import_art.py 的測試（MV-SLICE-001b1 Task 2）。會實際寫入 game/art/（產出本來就進版控）。

執行：python3 -m unittest tools/test_import_art.py
"""
import hashlib
import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "game" / "art"
SCRIPT = ROOT / "tools" / "import_art.py"

SPEC = importlib.util.spec_from_file_location("import_art", SCRIPT)
import_art = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(import_art)


def run(*args):
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=ROOT, capture_output=True, text=True)


def digest():
    out = {}
    for p in sorted(ART.rglob("*")):
        if p.is_file():
            out[str(p.relative_to(ART))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def content_box(path):
    a = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(a > import_art.ALPHA_MIN)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


class ImportArtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        r = run()
        assert r.returncode == 0, r.stderr

    def test_import_is_deterministic(self):
        first = digest()
        self.assertEqual(run().returncode, 0)
        self.assertEqual(first, digest())
        self.assertIn("MANIFEST.md", first)

    def test_check_mode_detects_drift(self):
        self.assertEqual(run("--check").returncode, 0)
        victim = ART / import_art.ENTRIES[0]["dst"]
        original = victim.read_bytes()
        try:
            victim.write_bytes(original + b"x")
            self.assertEqual(run("--check").returncode, 1)
        finally:
            victim.write_bytes(original)
        self.assertEqual(run("--check").returncode, 0)

    def test_total_size_under_budget(self):
        total = sum(p.stat().st_size for p in ART.rglob("*") if p.is_file())
        self.assertLessEqual(total, 50 * 1024 * 1024)

    def test_upscale_at_most_2x(self):
        for e, scale in import_art.scales().items():
            self.assertLessEqual(scale, 2.0, e)

    def test_fit_height_matches(self):
        for e in import_art.ENTRIES:
            if "fit_height" in e:
                x0, y0, x1, y1 = content_box(ART / e["dst"])
                self.assertAlmostEqual(y1 - y0, e["fit_height"], delta=1, msg=e["dst"])

    def test_keyed_images_have_no_magenta(self):
        for e in import_art.ENTRIES:
            if e.get("key"):
                a = np.asarray(Image.open(ART / e["dst"]).convert("RGBA")).astype(int)
                hot = (a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200) & (a[..., 3] > 0)
                self.assertEqual(int(hot.sum()), 0, e["dst"])

    def test_mirrored_outputs_tile_seamlessly(self):
        mirrored = [e for e in import_art.ENTRIES if e.get("mirror")]
        self.assertGreaterEqual(len(mirrored), 4)
        for e in mirrored:
            a = np.asarray(Image.open(ART / e["dst"]).convert("RGBA")).astype(int)
            if e["mirror"] == "h":
                diff = np.abs(a[:, 0] - a[:, -1]).max()
            else:
                diff = np.abs(a[0] - a[-1]).max()
            self.assertEqual(int(diff), 0, e["dst"])

    def test_foreground_center_transparent(self):
        a = np.asarray(Image.open(ART / "bg" / "bg_forest_fore_01.png").convert("RGBA"))[..., 3]
        h, w = a.shape
        center = a[h // 6: h - h // 6, w // 6: w - w // 6]
        self.assertEqual(int(center.max()), 0)


if __name__ == "__main__":
    unittest.main()


class KeyInteriorTest(unittest.TestCase):
    """去背不可以把物件內部變成半透明（Brian 試玩 b1，2026-10-11：木障像梯子、宮殿入口變橄欖綠）。

    key_magenta 會把落在「洋紅→輪廓墨色」連線附近的顏色當成邊緣的混色、做反混合；
    大面積的深褐色剛好落在那條線附近，整片變半透明又被扣掉洋紅（偏綠）。"""

    def test_keyed_interiors_stay_opaque(self):
        for e in import_art.ENTRIES:
            if not e.get("key"):
                continue
            a = import_art._load(e)[..., 3]
            fg = a > import_art.ALPHA_MIN
            inner = fg.copy()
            for dy, dx in ((-3, 0), (3, 0), (0, -3), (0, 3)):
                inner &= np.roll(np.roll(fg, dy, 0), dx, 1)
            semi = (a < 230) & inner
            share = semi.sum() / max(inner.sum(), 1)
            with self.subTest(dst=e["dst"]):
                self.assertLess(share, 0.05, f"{e['dst']} 內部 {share:.1%} 是半透明")


P4_RIG = ROOT / "prototypes" / "p4-art-pipeline" / "rig"
GAME_RIG = ROOT / "game" / "rig"
TWINS = ("hunahpu", "xbalanque")


def body_height(joints):
    """同 p4 rig.gd：ground＝腳踝與腳趾的最低點；身高＝ground.y − crown.y。"""
    ground = max(joints[j][1] for j in ("ankle_r", "toe_r", "ankle_l", "toe_l"))
    return ground - joints["crown"][1]


class RigImportTest(unittest.TestCase):
    """雙胞胎的分件、關節資料與側面附件（MV-SLICE-001b2a Task 1）。"""

    def test_rig_json_game_scale(self):
        import json
        for c in TWINS:
            with self.subTest(char=c):
                path = GAME_RIG / f"{c}_rig.json"
                self.assertTrue(path.exists(), path)
                game = json.loads(path.read_text())
                p4 = json.loads((P4_RIG / f"{c}_rig.json").read_text())
                self.assertAlmostEqual(body_height(game["reference"]["joints"]), 180, delta=1)
                self.assertAlmostEqual(game["scale"], 180 / body_height(p4["reference"]["joints"]), delta=1e-6)

    def test_rig_parts_exist(self):
        import json
        for c in TWINS:
            game = json.loads((GAME_RIG / f"{c}_rig.json").read_text())
            parts = [n for n in game["parts"] if n.startswith("chr_")]
            self.assertEqual(len(parts), 16, c)
            for n in parts:
                with self.subTest(part=n):
                    png = ART / "chr" / "parts" / c / (n[len(f"chr_{c}_"):] + ".png")
                    self.assertTrue(png.exists(), png)
                    w, h = Image.open(png).size
                    sw, sh = game["parts"][n]["size"]
                    self.assertAlmostEqual(w, sw, delta=1)
                    self.assertAlmostEqual(h, sh, delta=1)

    def test_weapon_side_images(self):
        # 長邊（內容外框）的目標：武器、球具、手上的湯碗
        targets = {"wpn_axe": 90, "wpn_digging_stick": 130, "wpn_blowgun": 110,
                   "wpn_ballgear_yoke": 60, "wpn_ballgear_armguard": 40, "prop_soup_bowl": 32}
        for n, target in targets.items():
            with self.subTest(item=n):
                png = ART / "chr" / "parts" / f"{n}.png"
                self.assertTrue(png.exists(), png)
                x0, y0, x1, y1 = content_box(png)
                self.assertAlmostEqual(max(x1 - x0, y1 - y0), target, delta=2)


class NpcRigImportTest(unittest.TestCase):
    """NPC 的骨架（MV-SLICE-001b2b2）：面向右的角色 faces 1、遊戲高度同立繪；既有切件角色照舊面向左。"""

    NPCS = ("xmucane", "healer_man", "healer_woman", "rat", "chimalmat")

    def test_npc_rig_faces_and_height(self):
        import json
        import import_rig
        self.assertEqual(import_rig.FACES_RIGHT, ("xmucane", "healer_man", "healer_woman", "rat"))
        for c in [c for c in import_rig.CUT_CHARS if c in self.NPCS]:
            with self.subTest(char=c):
                game = json.loads((ROOT / "game" / "rig" / f"{c}_rig.json").read_text())
                self.assertEqual(game["faces"], 1 if c in import_rig.FACES_RIGHT else -1)
                src = json.loads((ROOT / "tools" / "rig_src" / f"{c}_rig.json").read_text())
                self.assertAlmostEqual(game["scale"] * src["reference"]["content_height"], import_rig.TARGETS[c], delta=1)
        self.assertIn("xmucane", import_rig.CUT_CHARS)
        for c in ("crawler", "flyer", "sevenmacaw"):
            self.assertEqual(json.loads((ROOT / "game" / "rig" / f"{c}_rig.json").read_text())["faces"], -1, c)
