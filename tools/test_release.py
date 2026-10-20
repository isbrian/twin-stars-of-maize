import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("release", HERE / "release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
ROOT = HERE.parent
# 公開倉庫是不帶歷史、也沒有 release/ 的快照；需要它們的測試只在私人倉庫跑（MV-RELEASE-002 最終審查）
only_private = unittest.skipUnless((ROOT / "release" / "public").exists(), "只在私人倉庫跑")


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

    @only_private
    def test_forbidden_patterns_from_env(self):
        pats = release.forbidden_patterns(ROOT)
        self.assertIn(str(Path.home()), pats)
        self.assertFalse(any("noreply" in p for p in pats))

    @only_private
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



@only_private
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

    def test_scan_allows_github_ssh_user(self):
        (self.root / "a.md").write_text("SSH 寫法 `git@github.com:…`\nbob@foo.org\n", encoding="utf-8")
        self.assertEqual([(f[0], f[1]) for f in release.scan(self.root, [])], [("a.md", 2)])

    def test_scan_normalizes_case_and_escapes(self):
        (self.root / "a.json").write_text('{"p": "\\/USERS\\/alice\\/x"}\n%2Fusers%2Fbob%2Fy\n', encoding="utf-8")
        self.assertEqual(len(release.scan(self.root, [])), 2)


class PrivateLinkTest(unittest.TestCase):
    """MV-RELEASE-002：快照把私人倉庫連結改成純文字、掃描抓殘留、巢狀禁用資料夾、匯出產物。"""
    # 網址用拼接，測試檔本身進快照時才不會被改寫或被掃描抓到
    DEV = "https://" + "github.com/isbrian/" + "twin-stars-of-maize" + "-dev"
    OLD = "https://" + "github.com/isbrian/" + "Game-Popol-Vuh" + "-Metroidvania"
    PUB = "https://" + "github.com/isbrian/" + "twin-stars-of-maize"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_scrub_markdown_links(self):
        text = f"合併：[PR #25]({self.OLD}/pull/25)；[#31]({self.DEV.upper()}/pull/31)。"
        self.assertEqual(release.scrub_private_links(text), "合併：PR #25（私人倉庫）；#31（私人倉庫）。")

    def test_scrub_bare_urls(self):
        text = f"clone {self.DEV}.git 或 {self.OLD}/issues/3 看"
        self.assertEqual(release.scrub_private_links(text), "clone （私人倉庫連結） 或 （私人倉庫連結） 看")

    def test_scrub_other_url_forms(self):
        name = "isbrian/" + "twin-stars-of-maize" + "-dev"
        for url in ("https://www.github.com/" + name, "git@github.com:" + name + ".git",
                    "https://raw.githubusercontent.com/" + name + "/main/x.md"):
            self.assertEqual(release.scrub_private_links(f"看 {url} 這裡"), "看 （私人倉庫連結） 這裡", url)

    def test_scrub_keeps_public_repo(self):
        text = f"[公開]({self.PUB}/releases) {self.PUB}"
        self.assertEqual(release.scrub_private_links(text), text)

    def test_scan_flags_private_url_only_in_folder_scan(self):
        (self.root / "a.md").write_text(f"x\n[PR]({self.DEV}/pull/1)\n{self.PUB}\n", encoding="utf-8")
        self.assertEqual(release.scan(self.root, []), [("a.md", 2, "rule:private-repo")])
        self.assertEqual(release.scan(self.root, [], files=["a.md"]), [])

    def test_scan_flags_nested_forbidden_dirs(self):
        for rel in ("docs/x/.claude/a.md", "game/build/b.txt", "ok/c.txt"):
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_text("x", encoding="utf-8")
        found = release.scan(self.root, [])
        self.assertEqual(sorted(found), [("docs/x/.claude", 0, "forbidden dir"), ("game/build", 0, "forbidden dir")])
        (self.root / "ok" / "build").write_text("同名的檔不算", encoding="utf-8")
        self.assertEqual(len(release.scan(self.root, [])), 2)

    @only_private
    def test_snapshot_has_no_private_urls(self):
        out = self.root / "snap"
        self.assertEqual(release.snapshot("HEAD", out), [])
        for f in out.rglob("*"):
            if f.is_file() and b"\0" not in f.read_bytes()[:8192]:
                self.assertIsNone(release.PRIVATE_URL.search(f.read_text(encoding="utf-8", errors="replace")), f)
        readme = (out / "README.md").read_text(encoding="utf-8")
        self.assertEqual(readme, release._git("show", "HEAD:release/public/README.md"))  # 快照取 HEAD，不是工作區
        self.assertNotEqual(readme, release._git("show", "HEAD:README.md"))

    def test_scan_artifacts(self):
        import zipfile
        bad, ok = self.root / "bad", self.root / "ok"
        bad.mkdir(), ok.mkdir()
        with zipfile.ZipFile(bad / "g.zip", "w") as zf:
            zf.writestr("Game.app/bin", b"\0\0/secret/home\0")
        (bad / "game.pck").write_bytes(b"\0x/secret/homey")
        with zipfile.ZipFile(ok / "g.zip", "w") as zf:
            zf.writestr("Game.app/bin", b"\0clean")
        (ok / "game.pck").write_bytes(b"\0clean")
        self.assertEqual(sorted(release.scan_artifacts([bad], ["/secret/home"])),
                         [("bad/g.zip:Game.app/bin", "/secret/home"), ("bad/game.pck", "/secret/home")])
        self.assertEqual(release.scan_artifacts([ok / "g.zip", ok], ["/secret/home"]), [])

    @only_private
    def test_license_scope_consistent(self):
        pub = ROOT / "release" / "public"
        for name in ("LICENSE", "LICENSE-ASSETS.md", "README.md"):
            text = (pub / name).read_text(encoding="utf-8")
            for word in (".tscn", "prototypes", ".import", ".uid", ".py", ".sh"):
                self.assertIn(word, text, f"{name} 沒提到 {word}")
        readme = (pub / "README.md").read_text(encoding="utf-8")
        self.assertNotIn("網頁版沒有「結束遊戲」", readme)
        self.assertIn("v0.1.1", readme)


if __name__ == "__main__":
    unittest.main()
