"""tools/cut_rig.py 的測試（MV-SLICE-001b2b1 Task 2）。用合成圖，不碰 assets-test/ 與 tools/rig_src/。

執行：python3 -m unittest tools/test_cut_rig.py
"""
import importlib.util
import json
import math
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("cut_rig", ROOT / "tools" / "cut_rig.py")
cut_rig = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cut_rig)

CHAR = "t"
BODY = (10, 20, 90, 100)   # x0, y0, x1, y1（右、下不含）：左方塊「身體」
LEG = (100, 20, 130, 100)  # 右邊細長方塊「腿」，和身體隔 10 px


def make_image(path):
    a = np.zeros((120, 200, 3), np.uint8)
    a[:] = (255, 0, 255)
    for (x0, y0, x1, y1), color in ((BODY, (200, 40, 40)), (LEG, (40, 40, 200))):
        a[y0:y1, x0:x1] = color
    Image.fromarray(a).save(path)


def make_spec(**extra):
    spec = {
        "src": "ref.png",
        "joints": {"root": [15, 60], "hinge": [95, 60], "foot": [115, 60]},
        "bones": [["body", "", "root", "hinge", 45, 0], ["leg", "body", "hinge", "foot", 45, 1]],
        "cap": 20,
        "origin": {"x_joint": "root", "sole_parts": ["leg"]},
    }
    spec.update(extra)
    return spec


class Case(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        make_image(self.dir / "ref.png")

    def tearDown(self):
        self.tmp.cleanup()

    def run_cut(self, spec, sub="a"):
        rig_dir = self.dir / sub / "rig"
        rig_dir.mkdir(parents=True)
        (rig_dir / f"{CHAR}_joints.json").write_text(json.dumps(spec))
        out = self.dir / sub / "parts"
        return cut_rig.cut(CHAR, self.dir, out, rig_dir=rig_dir), out, rig_dir

    def part_pixels(self, rig, out, short):
        """分件的不透明像素，換回來源圖座標。"""
        meta = rig["parts"][f"chr_{CHAR}_{short}"]
        img = np.asarray(Image.open(out / f"chr_{CHAR}_{short}.png"))
        self.assertEqual(list(img.shape[1::-1]), meta["size"])
        joints = rig["reference"]["joints"]
        bone = next(b for b in rig["bones"] if b[0] == meta["bone"])
        ox = round(joints[bone[2]][0] - meta["pivot"][0])
        oy = round(joints[bone[2]][1] - meta["pivot"][1])
        ys, xs = np.nonzero(img[..., 3] > 0)
        return {(int(x) + ox, int(y) + oy) for x, y in zip(xs, ys)}, img

    def test_pixels_go_to_nearest_bone(self):
        rig, out, _ = self.run_cut(make_spec(cap=0))
        body, _ = self.part_pixels(rig, out, "body")
        leg, _ = self.part_pixels(rig, out, "leg")
        want = lambda r: {(x, y) for x in range(r[0], r[2]) for y in range(r[1], r[3])}
        self.assertEqual(body, want(BODY))
        self.assertEqual(leg, want(LEG))

    def test_poly_overrides_distance(self):
        poly = [[70, 20], [90, 20], [90, 100], [70, 100]]
        rig, out, _ = self.run_cut(make_spec(cap=0, polys={"leg": poly}))
        body, _ = self.part_pixels(rig, out, "body")
        leg, _ = self.part_pixels(rig, out, "leg")
        self.assertIn((80, 60), leg)
        self.assertNotIn((80, 60), body)
        self.assertIn((120, 60), leg)
        self.assertIn((20, 60), body)

    def test_snap_keeps_whole_ink_regions(self):
        # 身體中間畫一條墨線（x 50～51），分成左右兩塊；poly 在 x=40 直切過左塊
        img = np.asarray(Image.open(self.dir / "ref.png")).copy()
        img[20:100, 50:52] = (20, 15, 10)
        Image.fromarray(img).save(self.dir / "ref.png")
        poly = [[40, 20], [90, 20], [90, 100], [40, 100]]
        rig, out, _ = self.run_cut(make_spec(cap=0, polys={"leg": poly}, snap=[[0, 0, 200, 120]]))
        body, _ = self.part_pixels(rig, out, "body")
        leg, _ = self.part_pixels(rig, out, "leg")
        # 用 assertTrue（集合很大，assertIn 失敗會印出整個集合）
        self.assertTrue((45, 60) in body and (45, 60) not in leg)  # 左塊多數歸身體 → 整塊歸身體
        self.assertTrue((60, 60) in leg and (60, 60) not in body)  # 右塊整塊歸腿
        self.assertTrue((50, 60) in body and (51, 60) in leg)      # 墨線兩邊的分件都帶

    def test_joint_cap_overlaps(self):
        rig, out, _ = self.run_cut(make_spec(cap=20))
        body, _ = self.part_pixels(rig, out, "body")
        leg, _ = self.part_pixels(rig, out, "leg")
        self.assertIn((105, 60), body)   # 腿的像素在關節圓內，身體也帶一份
        self.assertIn((85, 60), leg)     # 身體的像素在關節圓內，腿也帶一份
        self.assertNotIn((120, 60), body)  # 圓外不帶
        self.assertNotIn((20, 60), leg)

    def test_joint_cap_per_joint(self):
        # caps 覆寫單一關節的重疊半徑：hinge 用 30，比預設 20 多帶一圈
        rig, out, _ = self.run_cut(make_spec(cap=20, caps={"hinge": 30}))
        body, _ = self.part_pixels(rig, out, "body")
        leg, _ = self.part_pixels(rig, out, "leg")
        self.assertIn((120, 60), body)
        self.assertIn((70, 60), leg)
        self.assertNotIn((20, 60), leg)

    def test_overlap_adds_without_taking(self):
        # overlap：圈內像素也帶進身體（墊在腿底下），腿照樣保有；圈外不帶
        poly = [[100, 20], [115, 20], [115, 100], [100, 100]]
        rig, out, _ = self.run_cut(make_spec(cap=0, overlap={"body": poly}))
        body, _ = self.part_pixels(rig, out, "body")
        leg, _ = self.part_pixels(rig, out, "leg")
        self.assertTrue((105, 60) in body and (105, 60) in leg)
        self.assertFalse((120, 60) in body)

    def test_overlap_unknown_part_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "overlap"):
            self.run_cut(make_spec(overlap={"wing": [[0, 0], [1, 0], [1, 1]]}))

    def test_far_copy_darkened_and_offset(self):
        spec = make_spec(far=[["leg_far", "leg_far", "leg", -2, [-30, 5]]])
        spec["bones"].append(["leg_far", "body", "hinge_far", "foot_far", 45, -2])
        rig, out, _ = self.run_cut(spec)
        near = np.asarray(Image.open(out / f"chr_{CHAR}_leg.png"))
        far = np.asarray(Image.open(out / f"chr_{CHAR}_leg_far.png"))
        self.assertEqual(near.shape, far.shape)
        self.assertTrue((near[..., 3] == far[..., 3]).all())
        self.assertTrue((far[..., :3] == (near[..., :3] * cut_rig.FAR_DARKEN).astype(np.uint8)).all())
        pn, pf = rig["parts"][f"chr_{CHAR}_leg"], rig["parts"][f"chr_{CHAR}_leg_far"]
        self.assertEqual((pn["pivot"], pn["tip"], pn["size"]), (pf["pivot"], pf["tip"], pf["size"]))
        self.assertEqual((pf["bone"], pf["z"]), ("leg_far", -2))
        j = rig["reference"]["joints"]
        self.assertEqual(j["hinge_far"], [65.0, 65.0])
        self.assertEqual(j["foot_far"], [85.0, 65.0])
        # 遠側骨頭沒有自己的像素：身體只搶到身體、腿，不多出第三份
        self.assertEqual(sorted(rig["parts"]), [f"chr_{CHAR}_{n}" for n in ("body", "leg", "leg_far")])

    def test_points_in_bone_space(self):
        spec = make_spec(points={"eye": {"bone": "leg", "at": [118.0, 40.0]},
                                 "tail": {"bone": "body", "at": [12.0, 90.0]}})
        rig, _, _ = self.run_cut(spec)
        for name, p in spec["points"].items():
            bone = next(b for b in rig["bones"] if b[0] == p["bone"])
            a = np.array(rig["reference"]["joints"][bone[2]])
            b = np.array(rig["reference"]["joints"][bone[3]])
            ang = math.atan2(b[1] - a[1], b[0] - a[0])
            lx, ly = rig["points"][name]["at"]
            back = a + np.array([lx * math.cos(ang) - ly * math.sin(ang), lx * math.sin(ang) + ly * math.cos(ang)])
            self.assertLessEqual(np.abs(back - np.array(p["at"])).max(), 0.5, name)
            self.assertEqual(rig["points"][name]["bone"], p["bone"])

    def test_points_rotated_bone(self):
        # 骨頭不是朝右：x 軸沿 from→to
        spec = make_spec(joints={"root": [15, 60], "hinge": [95, 60], "foot": [115, 100]},
                         points={"p": {"bone": "leg", "at": [115.0, 100.0]}})
        rig, _, _ = self.run_cut(spec)
        lx, ly = rig["points"]["p"]["at"]
        self.assertAlmostEqual(lx, math.hypot(20, 40), delta=0.1)
        self.assertAlmostEqual(ly, 0.0, delta=0.1)

    def test_content_height(self):
        rig, _, _ = self.run_cut(make_spec())
        self.assertEqual(rig["reference"]["content_height"], 80)
        self.assertEqual(rig["reference"]["size"], [200, 120])

    def test_faint_specks_ignored(self):
        # 去背後的淡雜點（真實基準圖整張都有，Alpha 1～32）不算內容、也不進分件（同 import_art 的 ALPHA_MIN）
        a = np.asarray(Image.open(self.dir / "ref.png")).copy()
        a[115, 195] = (237, 36, 236)  # Alpha≈21：爬行型基準圖右下角真的有這種點
        a[2, 2] = (250, 10, 250)      # Alpha≈5
        Image.fromarray(a).save(self.dir / "ref.png")
        rig, out, _ = self.run_cut(make_spec(cap=0))
        self.assertEqual(rig["reference"]["content_height"], 80)
        leg, _ = self.part_pixels(rig, out, "leg")
        self.assertEqual(leg, {(x, y) for x in range(LEG[0], LEG[2]) for y in range(LEG[1], LEG[3])})

    def test_rig_shape_and_files(self):
        rig, out, rig_dir = self.run_cut(make_spec())
        self.assertEqual(rig["bones"], [["body", "", "root", "hinge"], ["leg", "body", "hinge", "foot"]])
        self.assertEqual(rig["root_length"], 0.0)
        self.assertEqual(rig["origin"], {"x_joint": "root", "sole_parts": ["leg"]})
        self.assertEqual(set(rig["parts"]["chr_t_body"]), {"size", "bone", "pivot", "tip", "z"})
        self.assertEqual(rig["parts"]["chr_t_leg"]["z"], 1)
        self.assertEqual(rig["reference"]["joints"]["hinge"], [95.0, 60.0])
        self.assertTrue((out / "chr_t_reference.png").exists())
        self.assertEqual(json.loads((rig_dir / f"{CHAR}_rig.json").read_text()), rig)

    def test_missing_joint_is_an_error(self):
        spec = make_spec()
        del spec["joints"]["foot"]
        with self.assertRaises(ValueError):
            self.run_cut(spec)

    def test_isolated_specks_ignored(self):
        # 單獨一點、Alpha 剛好超過門檻的雜點（Seven Macaw 基準圖左下角 (0, 1023) 有一點 34）：不算內容、不進分件
        a = np.asarray(Image.open(self.dir / "ref.png")).copy()
        a[118, 1] = (90, 250, 30)  # 離洋紅夠遠 → Alpha 不小，但四周都是背景
        Image.fromarray(a).save(self.dir / "ref.png")
        rig, out, _ = self.run_cut(make_spec(cap=0))
        self.assertEqual(rig["reference"]["content_height"], 80)
        body, _ = self.part_pixels(rig, out, "body")
        self.assertNotIn((1, 118), body)

    def test_far_with_missing_copied_joint_is_an_error(self):
        spec = make_spec(far=[["leg_far", "leg_far", "leg", -2, [-30, 5]]])
        spec["bones"].append(["leg_far", "body", "hinge_far", "foot_far", 45, -2])
        del spec["joints"]["foot"]
        with self.assertRaises(ValueError):
            self.run_cut(spec)

    def test_points_unknown_bone_is_an_error(self):
        spec = make_spec(points={"eye": {"bone": "wing", "at": [118.0, 40.0]}})
        with self.assertRaises(ValueError):
            self.run_cut(spec)

    def test_head_variant_aligned_and_masked(self):
        # 主圖：身體＋「頭」（右邊的方塊，x 100～130、y 20～100）。受傷頭特寫＝同一個頭放大 2 倍、平移，
        # 下面多畫一段「脖子」（應被完整頭的範圍裁掉），頭中央有一塊 2×2（特寫裡 4×4）的記號
        spec = make_spec(cap=20, head_marks=[[100, 20], [130, 100]],
                         heads={"hurt": {"src": "hurt.png", "marks": [[50, 40], [110, 200]]}})
        spec["bones"][1][0] = "head"
        spec["origin"]["sole_parts"] = ["head"]
        v = np.zeros((300, 200, 3), np.uint8)
        v[:] = (255, 0, 255)
        v[40:260, 50:110] = (40, 200, 40)    # 頭（y 40～200）＋多出來的脖子（y 200～260）
        v[116:120, 76:80] = (250, 250, 250)  # 記號：主圖座標 x 113～115、y 58～60
        Image.fromarray(v).save(self.dir / "hurt.png")
        rig, out, _ = self.run_cut(spec)
        meta = rig["parts"][f"chr_{CHAR}_head_hurt"]
        head = rig["parts"][f"chr_{CHAR}_head"]
        self.assertEqual((meta["bone"], meta["z"], meta["visible"]), ("head", head["z"], False))
        self.assertNotIn("visible", head)
        px, img = self.part_pixels(rig, out, "head_hurt")
        xs = [p[0] for p in px]
        ys = [p[1] for p in px]
        # 對位：頭的左、上、右緣（兩個特徵點）誤差 ≤ 1 px
        self.assertLessEqual(abs(min(xs) - 100), 1)
        self.assertLessEqual(abs(min(ys) - 20), 1)
        self.assertLessEqual(abs(max(xs) + 1 - 130), 1)
        white = np.argwhere((img[..., 0] > 200) & (img[..., 1] > 200) & (img[..., 3] > 200))
        ox = round(meta["pivot"][0] - head["pivot"][0])
        oy = round(meta["pivot"][1] - head["pivot"][1])
        hx = rig["reference"]["joints"]["hinge"][0] - head["pivot"][0]
        hy = rig["reference"]["joints"]["hinge"][1] - head["pivot"][1]
        cy, cx = white.mean(axis=0)
        self.assertLessEqual(abs(cx - ox + hx - 114), 1)
        self.assertLessEqual(abs(cy - oy + hy - 59), 1)
        # 裁切：不超出完整頭件的不透明範圍往外長 6 px（多出來的脖子被裁掉）
        full, _ = self.part_pixels(rig, out, "head")
        fx = [p[0] for p in full]
        fy = [p[1] for p in full]
        self.assertGreaterEqual(min(xs), min(fx) - 6)
        self.assertLessEqual(max(xs), max(fx) + 6)
        self.assertGreaterEqual(min(ys), min(fy) - 6)
        self.assertLessEqual(max(ys), max(fy) + 6)
        self.assertLessEqual(max(ys), 100 + 6)
        grown = {(x + dx, y + dy) for x, y in full for dx in range(-6, 7) for dy in range(-6, 7) if dx * dx + dy * dy <= 36}
        self.assertTrue(px <= grown)

    # 圖層（MV-TUNE-003）：「腿」改從另一張圖切。圖層圖＝同一條腿畫成綠色、放大 1.5 倍並平移
    # （圖層座標 L＝1.5×主圖座標 + (−120, 10)），腿中央 (115, 40) 有一塊白色記號；主圖的腿照舊是藍色
    GREEN, BLUE, YELLOW = (40, 200, 40), (40, 40, 200), (250, 220, 0)

    def layer_spec(self, ref_marks=((100, 20), (130, 100))):
        v = np.zeros((200, 200, 3), np.uint8)
        v[:] = (255, 0, 255)
        v[40:160, 30:75] = self.GREEN                # 主圖 x 100～130、y 20～100
        v[69:72, 51:54] = (250, 250, 250)            # 記號：主圖約 (115, 40)
        Image.fromarray(v).save(self.dir / "layer.png")
        return make_spec(layers={"lyr": {"src": "layer.png", "marks": [[30, 40], [75, 160]],
                                         "ref_marks": [list(p) for p in ref_marks], "bones": ["leg"]}})

    def colour_count(self, img, rgb):
        a = np.asarray(img)
        return int(((np.abs(a[..., :3].astype(int) - rgb) < 30).all(axis=-1) & (a[..., 3] > 200)).sum())

    def test_layer_aligned_by_marks(self):
        rig, out, _ = self.run_cut(self.layer_spec())
        px, img = self.part_pixels(rig, out, "leg")
        xs = [p[0] for p in px]
        ys = [p[1] for p in px]
        self.assertLessEqual(abs(min(xs) - 100), 1)
        self.assertLessEqual(abs(min(ys) - 20), 1)
        self.assertLessEqual(abs(max(xs) + 1 - 130), 1)
        self.assertLessEqual(abs(max(ys) + 1 - 100), 1)
        meta = rig["parts"][f"chr_{CHAR}_leg"]
        hinge = rig["reference"]["joints"]["hinge"]
        white = np.argwhere((img[..., 0] > 200) & (img[..., 1] > 200) & (img[..., 2] > 200) & (img[..., 3] > 200))
        cy, cx = white.mean(axis=0)
        self.assertLessEqual(abs(cx + hinge[0] - meta["pivot"][0] - 115), 1)
        self.assertLessEqual(abs(cy + hinge[1] - meta["pivot"][1] - 40), 1)

    def test_layer_bones_take_only_layer_pixels(self):
        rig, out, _ = self.run_cut(self.layer_spec())
        leg = Image.open(out / f"chr_{CHAR}_leg.png")
        body = Image.open(out / f"chr_{CHAR}_body.png")
        self.assertGreater(self.colour_count(leg, self.GREEN), 1000)
        self.assertEqual(self.colour_count(leg, self.BLUE), 0)
        self.assertEqual(self.colour_count(body, self.GREEN), 0)
        # 合成圖：腿的位置是圖層的綠色，不是主圖的藍色
        ref = np.asarray(Image.open(out / f"chr_{CHAR}_reference.png"))
        self.assertEqual(self.colour_count(Image.fromarray(ref[30:90, 105:125]), self.BLUE), 0)
        self.assertGreater(self.colour_count(Image.fromarray(ref[30:90, 105:125]), self.GREEN), 1000)

    def test_erase_makes_background(self):
        a = np.asarray(Image.open(self.dir / "ref.png")).copy()
        a[30:50, 20:40] = self.YELLOW
        Image.fromarray(a).save(self.dir / "ref.png")
        spec = make_spec(erase=[[[18, 28], [42, 28], [42, 52], [18, 52]]])
        rig, out, _ = self.run_cut(spec)
        for name in [*rig["parts"], f"chr_{CHAR}_reference"]:
            self.assertEqual(self.colour_count(Image.open(out / f"{name}.png"), self.YELLOW), 0, name)

    def test_layer_polys_apply_in_layer(self):
        # 圖層裡有兩根骨頭（腿、腳趾）時，polys 照樣決定圖層像素的歸屬（翅膀各節沿羽毛分界）
        spec = self.layer_spec()
        spec["joints"]["toe"] = [128, 60]
        spec["bones"].append(["toe", "leg", "foot", "toe", 45, 2])
        spec["layers"]["lyr"]["bones"] = ["leg", "toe"]
        spec["polys"] = {"toe": [[99, 19], [131, 19], [131, 40], [99, 40]]}  # 腿的上緣一條歸腳趾
        rig, out, _ = self.run_cut(spec)
        toe, _ = self.part_pixels(rig, out, "toe")
        leg, _ = self.part_pixels(rig, out, "leg")
        self.assertTrue((105, 25) in toe, "腿上緣的像素應歸腳趾")
        self.assertFalse((105, 25) in leg, "腿上緣的像素不應留在腿")

    def test_layer_without_pixels_is_an_error(self):
        spec = self.layer_spec(ref_marks=((1000, 1000), (1030, 1080)))
        with self.assertRaisesRegex(ValueError, "圖層 lyr"):
            self.run_cut(spec)

    def test_layer_deterministic(self):
        spec = self.layer_spec()
        _, out1, rd1 = self.run_cut(spec, "a")
        _, out2, rd2 = self.run_cut(spec, "b")
        names = sorted(p.name for p in out1.iterdir())
        for n in names:
            self.assertEqual((out1 / n).read_bytes(), (out2 / n).read_bytes(), n)
        self.assertEqual((rd1 / f"{CHAR}_rig.json").read_bytes(), (rd2 / f"{CHAR}_rig.json").read_bytes())

    def test_deterministic(self):
        spec = make_spec(far=[["leg_far", "leg_far", "leg", -2, [-30, 5]]],
                         points={"eye": {"bone": "leg", "at": [118.0, 40.0]}})
        spec["bones"].append(["leg_far", "body", "hinge_far", "foot_far", 45, -2])
        _, out1, rd1 = self.run_cut(spec, "a")
        _, out2, rd2 = self.run_cut(spec, "b")
        names = sorted(p.name for p in out1.iterdir())
        self.assertEqual(names, sorted(p.name for p in out2.iterdir()))
        for n in names:
            self.assertEqual((out1 / n).read_bytes(), (out2 / n).read_bytes(), n)
        self.assertEqual((rd1 / f"{CHAR}_rig.json").read_bytes(), (rd2 / f"{CHAR}_rig.json").read_bytes())


if __name__ == "__main__":
    unittest.main()
