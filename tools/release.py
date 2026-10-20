"""公開版發版工具（MV-RELEASE-001）。

  python3 tools/release.py scan [資料夾]   掃描禁用內容；沒給資料夾時掃私人倉庫進版控的檔
                                           （有發現就列出並以結束碼 1 結束）
  python3 tools/release.py build <版號>     匯出 Windows、macOS、網頁版到 build/（需要 Godot 4.7.2 匯出範本）
  python3 tools/release.py snapshot <ref> <輸出資料夾>
                                           公開倉庫的快照：git archive <ref>＋release/public/ 的檔放到根目錄；
                                           掃描不乾淨就刪掉輸出、結束碼 1

禁用內容在執行時從本機環境取得（家目錄、倉庫所在磁碟的掛載路徑、git 作者信箱），
原始碼與文件都不寫具體字串，所以工具不會掃到自己。
"""
import hashlib
import shutil
import io
import re
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# 快照裡不得出現的資料夾：原典譯本、AI 測試素材、工作區、匯出產物、git 本身（快照不帶歷史）
FORBIDDEN_DIRS = ("sources", "assets-test", ".superpowers", "build", ".git")
# 通用規則（比對前先轉小寫、還原 \/ 與 %2F）：任何使用者的家目錄、任何外接磁碟路徑、任何信箱。
# `<` 開頭的是文件裡的佔位寫法（例如 /Volumes/<磁碟名>），不算。
RULES = {
    "rule:users": re.compile(r"/users/[^/<\s\"'`)\]]+"),
    "rule:volumes": re.compile(r"/volumes/[^/<\s\"'`)\]]+"),
    "rule:email": re.compile(r"[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}"),
}
EMAIL_OK = ("noreply", "@example.com")  # GitHub 匿名信箱、範例信箱
# 掃描器自己的規則與測試用假資料（alice、bob@foo.org…）只豁免通用規則；精確比對照樣檢查（test_scan_patterns_not_in_source）
RULES_EXEMPT = ("tools/release.py", "tools/test_release.py")
BUILD = ROOT / "build"
# 匯出預設名稱 → (平台代號, 匯出路徑)；名稱與 game/export_presets.cfg 一致
PRESETS = {
    "Windows Desktop": ("windows", BUILD / "windows" / "TwinStarsOfMaize.exe"),
    "macOS": ("macos", BUILD / "macos" / "TwinStarsOfMaize.zip"),
    "Web": ("web", BUILD / "web" / "index.html"),
}


def _git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout


def forbidden_patterns(repo):
    """家目錄、倉庫所在磁碟的掛載路徑（在 /Volumes 下時）、git 作者信箱（不含 GitHub noreply）。"""
    pats = [str(Path.home())]
    parts = Path(repo).resolve().parts
    if len(parts) >= 3 and parts[1] == "Volumes":
        pats.append("/" + "/".join(parts[1:3]))
    mails = set(_git("log", "--all", "--format=%ae", cwd=repo).split())
    mails.add(_git("config", "user.email", cwd=repo).strip())
    pats += sorted(m for m in mails if m and "noreply" not in m)
    return pats


def scan(root, patterns, files=None):
    """回傳 [(相對路徑, 行號, pattern)]；二進位檔（前 8 KB 含 \\0）跳過；禁用資料夾回傳 (資料夾, 0, "forbidden dir")。"""
    root = Path(root)
    found = []
    if files is None:  # 掃資料夾（快照）時才檢查禁用資料夾；掃私人倉庫的進版控檔時它們本來就在旁邊
        found = [(d, 0, "forbidden dir") for d in FORBIDDEN_DIRS if (root / d).exists()]
        files = sorted(p.relative_to(root).as_posix() for p in root.rglob("*")
                       if p.is_file() and p.relative_to(root).parts[0] not in FORBIDDEN_DIRS)
    for rel in files:
        path = root / rel
        data = path.read_bytes()
        if b"\0" in data[:8192]:
            continue
        for n, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
            low = line.lower().replace("\\/", "/").replace("%2f", "/")
            hits = [(rel, n, p) for p in patterns if p.lower() in low]
            if not hits and rel not in RULES_EXEMPT:
                for name, rx in RULES.items():
                    m = [x for x in rx.findall(low) if name != "rule:email" or not any(ok in x for ok in EMAIL_OK)]
                    if m:
                        hits.append((rel, n, name))
            found += hits
    return found


def snapshot(ref, out, patterns=None):
    """git archive ref 解到 out，release/public/ 的內容放到根目錄（覆蓋同名檔）、拿掉 release/；
    掃描有發現就刪掉 out 並回傳發現清單，乾淨回傳 []。out 必須不存在或是空的。"""
    out = Path(out)
    if out.exists() and any(out.iterdir()):
        raise FileExistsError(f"{out} 不是空的")
    data = subprocess.run(["git", "archive", "--format=tar", ref], cwd=ROOT, capture_output=True, check=True).stdout
    out.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as tf:
        tf.extractall(out)  # 來源是本倉庫自己的 git archive
    public = out / "release" / "public"
    if public.exists():
        shutil.copytree(public, out, dirs_exist_ok=True)
    shutil.rmtree(out / "release", ignore_errors=True)
    found = scan(out, forbidden_patterns(ROOT) if patterns is None else patterns)
    if found:
        shutil.rmtree(out)
    return found


def godot_notices():
    """Godot 引擎與第三方函式庫的授權聲明（tools/godot_notices.gd 印出的 BEGIN～END 之間）。"""
    r = subprocess.run(["godot", "--headless", "--path", str(ROOT / "game"), "--script", str(ROOT / "tools" / "godot_notices.gd")],
                       capture_output=True, text=True, check=True)
    return r.stdout.split("=== NOTICES BEGIN ===\n", 1)[1].split("\n=== NOTICES END ===", 1)[0] + "\n"


def append_to_zip(zip_path, name, text):
    with zipfile.ZipFile(zip_path, "a", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(name, text)


NOTICES = "THIRD_PARTY_NOTICES.txt"


def zip_name(platform, version):
    return f"TwinStarsOfMaize-v{version}-{platform}.zip"


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(version):
    """依序匯出三個預設；Windows 資料夾打成 zip、macOS 的 zip 改名、網頁版留資料夾。回傳產物路徑。"""
    out = []
    notices = godot_notices()
    for preset, (plat, path) in PRESETS.items():
        shutil.rmtree(path.parent, ignore_errors=True)
        path.parent.mkdir(parents=True)
        subprocess.run(["godot", "--headless", "--path", str(ROOT / "game"), "--export-release", preset, str(path)], check=True)
        if not path.exists():
            raise RuntimeError(f"{preset} 沒有產出 {path}")
        if plat != "macos":
            (path.parent / NOTICES).write_text(notices, encoding="utf-8")
        if plat == "windows":
            z = BUILD / zip_name(plat, version)
            with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
                for f in sorted(path.parent.iterdir()):
                    zf.write(f, f"TwinStarsOfMaize/{f.name}")
            out.append(z)
        elif plat == "macos":
            z = BUILD / zip_name(plat, version)
            path.replace(z)
            append_to_zip(z, NOTICES, notices)
            out.append(z)
        else:
            out.append(path.parent)
    return out


def main(argv):
    if len(argv) >= 3 and argv[1] == "build":
        for p in build(argv[2]):
            if p.is_dir():
                size = sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
                print(f"BUILD {p.relative_to(ROOT)}/  {size / 1e6:.1f} MB")
            else:
                print(f"BUILD {p.relative_to(ROOT)}  {p.stat().st_size / 1e6:.1f} MB  sha256 {_sha256(p)}")
        return 0
    if len(argv) >= 4 and argv[1] == "snapshot":
        found = snapshot(argv[2], Path(argv[3]))
        for rel, n, p in found:
            print(f"SNAPSHOT 不乾淨 {rel}:{n}")
        if not found:
            files = [f for f in Path(argv[3]).rglob("*") if f.is_file()]
            print(f"SNAPSHOT 乾淨：{len(files)} 個檔、{sum(f.stat().st_size for f in files) / 1e6:.1f} MB → {argv[3]}")
        return 1 if found else 0
    if len(argv) < 2 or argv[1] != "scan":
        print(__doc__)
        return 2
    if len(argv) > 2:
        root, files = Path(argv[2]), None
    else:
        root, files = ROOT, _git("ls-files", "-z").split("\0")[:-1]
    found = scan(root, forbidden_patterns(ROOT), files)
    pats = forbidden_patterns(ROOT)
    for rel, n, p in found:
        what = "禁用資料夾" if p == "forbidden dir" else (f"通用規則 {p}" if p.startswith("rule:") else f"含禁用字串（第 {pats.index(p) + 1} 項）")
        print(f"SCAN {rel}:{n}  {what}")
    print(f"SCAN {'乾淨' if not found else f'{len(found)} 筆'}")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
