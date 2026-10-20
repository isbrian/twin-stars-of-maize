import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("release", HERE / "release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
ROOT = HERE.parent


class ScanTest(unittest.TestCase):
    """MV-RELEASE-001：快照與公開前的禁用內容掃描。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_scan_flags_home_path(self):
        home = str(Path.home())
        (self.root / "a.md").write_text("第一行\n路徑 " + home + "/x\n", encoding="utf-8")
        found = release.scan(self.root, [home])
        self.assertEqual(found, [("a.md", 2, home)])

    def test_scan_flags_author_email(self):
        (self.root / "b.txt").write_text("contact someone@example.com\n", encoding="utf-8")
        self.assertEqual(len(release.scan(self.root, ["someone@example.com"])), 1)

    def test_scan_skips_binary(self):
        (self.root / "c.bin").write_bytes(b"\0\0someone@example.com")
        self.assertEqual(release.scan(self.root, ["someone@example.com"]), [])

    def test_scan_flags_forbidden_dirs(self):
        (self.root / "sources").mkdir()
        (self.root / "sources" / "x.txt").write_text("x", encoding="utf-8")
        (self.root / ".git").mkdir()
        found = release.scan(self.root, [])
        self.assertEqual(sorted(f[0] for f in found), [".git", "sources"])
        self.assertTrue(all(f[2] == "forbidden dir" for f in found))

    def test_forbidden_patterns_from_env(self):
        pats = release.forbidden_patterns(ROOT)
        self.assertIn(str(Path.home()), pats)
        self.assertFalse(any("noreply" in p for p in pats))

    def test_scan_patterns_not_in_source(self):
        src = (HERE / "release.py").read_text(encoding="utf-8") + (HERE / "test_release.py").read_text(encoding="utf-8")
        for p in release.forbidden_patterns(ROOT):
            self.assertNotIn(p, src)


class BuildTest(unittest.TestCase):
    """MV-RELEASE-001 Task 4：產物檔名、匯出預設。"""

    def test_zip_name(self):
        self.assertEqual(release.zip_name("macos", "0.1.0"), "TwinStarsOfMaize-v0.1.0-macos.zip")
        self.assertEqual(release.zip_name("windows", "0.1.0"), "TwinStarsOfMaize-v0.1.0-windows.zip")

    def test_presets_exist(self):
        cfg = (ROOT / "game" / "export_presets.cfg").read_text(encoding="utf-8")
        for name in ('name="Windows Desktop"', 'name="macOS"', 'name="Web"'):
            self.assertIn(name, cfg)
        self.assertIn('variant/thread_support=false', cfg)
        self.assertIn('application/bundle_identifier="net.isbrian.twinstarsofmaize"', cfg)



class SnapshotTest(unittest.TestCase):
    """MV-RELEASE-001 Task 5：公開倉庫快照。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = Path(self.tmp.name) / "snap"

    def tearDown(self):
        self.tmp.cleanup()

    def test_snapshot_puts_public_files_at_root(self):
        found = release.snapshot("HEAD", self.out)
        self.assertEqual(found, [])
        self.assertIn("Twin Stars of Maize", (self.out / "README.md").read_text(encoding="utf-8"))
        self.assertTrue((self.out / "LICENSE").exists())
        self.assertTrue((self.out / ".github" / "ISSUE_TEMPLATE" / "playtest.md").exists())
        self.assertFalse((self.out / "release").exists())

    def test_snapshot_excludes_untracked_dirs(self):
        release.snapshot("HEAD", self.out)
        for d in ("sources", "assets-test", ".superpowers", "build", ".git"):
            self.assertFalse((self.out / d).exists(), d)

    def test_snapshot_refuses_dirty(self):
        found = release.snapshot("HEAD", self.out, patterns=["extends"])
        self.assertTrue(found)
        self.assertFalse(self.out.exists())

    def test_snapshot_refuses_nonempty_out(self):
        self.out.mkdir()
        (self.out / "keep.txt").write_text("x", encoding="utf-8")
        with self.assertRaises(FileExistsError):
            release.snapshot("HEAD", self.out)
        self.assertTrue((self.out / "keep.txt").exists())



class FinalReviewTest(unittest.TestCase):
    """MV-RELEASE-001 最終審查：Godot 授權聲明、掃描的通用規則。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_godot_notices(self):
        text = release.godot_notices()
        self.assertIn("Godot Engine", text)
        self.assertIn("FreeType", text)
        self.assertIn("Permission is hereby granted", text)

    def test_append_to_zip(self):
        import zipfile
        z = self.root / "a.zip"
        with zipfile.ZipFile(z, "w") as zf:
            zf.writestr("Game.app/x", "x")
        release.append_to_zip(z, "THIRD_PARTY_NOTICES.txt", "hello")
        with zipfile.ZipFile(z) as zf:
            self.assertEqual(sorted(zf.namelist()), ["Game.app/x", "THIRD_PARTY_NOTICES.txt"])
            self.assertEqual(zf.read("THIRD_PARTY_NOTICES.txt").decode(), "hello")

    def test_scan_flags_any_users_path(self):
        (self.root / "a.md").write_text("cd /Users/alice/proj\n佔位 /Users/<name>/x\n", encoding="utf-8")
        self.assertEqual([(f[0], f[1]) for f in release.scan(self.root, [])], [("a.md", 1)])

    def test_scan_flags_any_volumes_path(self):
        (self.root / "a.md").write_text("磁碟 /Volumes/OtherDisk/x\n描述 /Volumes/<磁碟名>\n", encoding="utf-8")
        self.assertEqual([(f[0], f[1]) for f in release.scan(self.root, [])], [("a.md", 1)])

    def test_scan_flags_any_email(self):
        (self.root / "a.md").write_text("bob@foo.org\n123+x@users.noreply.github.com\na@example.com\n", encoding="utf-8")
        self.assertEqual([(f[0], f[1]) for f in release.scan(self.root, [])], [("a.md", 1)])

    def test_scan_normalizes_case_and_escapes(self):
        (self.root / "a.json").write_text('{"p": "\\/USERS\\/alice\\/x"}\n%2Fusers%2Fbob%2Fy\n', encoding="utf-8")
        self.assertEqual(len(release.scan(self.root, [])), 2)


if __name__ == "__main__":
    unittest.main()
