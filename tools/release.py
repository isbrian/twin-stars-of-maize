"""公開版發版工具（MV-RELEASE-001）。

  python3 tools/release.py scan [資料夾]   掃描禁用內容；沒給資料夾時掃私人倉庫進版控的檔
                                           （有發現就列出並以結束碼 1 結束）
  python3 tools/release.py build <版號>     匯出 Windows、macOS、網頁版到 build/（需要 Godot 4.7.2 匯出範本），
                                           再逐位元組掃描產物（有發現就以結束碼 1 結束）
  python3 tools/release.py snapshot <ref> <輸出資料夾>
                                           公開倉庫的快照：git archive <ref>＋release/public/ 的檔放到根目錄、
                                           私人倉庫連結改純文字；
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
# 快照裡不得出現的資料夾（任何深度）：原典譯本、AI 測試素材、工作區、匯出產物、git 本身（快照不帶歷史）、Claude 工作區
FORBIDDEN_DIRS = ("sources", "assets-test", ".superpowers", "build", ".git", ".claude")
# 私人倉庫（含舊名，GitHub 會轉址）。快照把它們的連結改成純文字（MV-RELEASE-002）；公開倉庫 twin-stars-of-maize 是 -dev 的前綴，不能誤判
PRIVATE_REPOS = ("isbrian/twin-stars-of-maize-dev", "isbrian/Game-Popol-Vuh-Metroidvania")
# 前綴：https／www／SSH（git@github.com:）／raw.githubusercontent.com（MV-RELEASE-002 最終審查）
_PRIVATE = r"(?:https?://)?(?:git@)?(?:www\.)?(?:github\.com[/:]|raw\.githubusercontent\.com/)(?:" + "|".join(re.escape(r) for r in PRIVATE_REPOS) + r")(?![\w-])[^\s)\]>\"'`]*"
PRIVATE_URL = re.compile(_PRIVATE, re.IGNORECASE)
PRIVATE_MD_LINK = re.compile(r"\[([^\]]*)\]\(\s*<?" + _PRIVATE + r">?\s*\)", re.IGNORECASE)
# 通用規則（比對前先轉小寫、還原 \/ 與 %2F）：任何使用者的家目錄、任何外接磁碟路徑、任何信箱。
# `<` 開頭的是文件裡的佔位寫法（例如 /Volumes/<磁碟名>），不算。
RULES = {
    "rule:users": re.compile(r"/users/[^/<\s\"'`)\]]+"),
    "rule:volumes": re.compile(r"/volumes/[^/<\s\"'`)\]]+"),
    "rule:email": re.compile(r"[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}"),
}
EMAIL_OK = ("noreply", "@example.com", "git@github.com")  # GitHub 匿名信箱、範例信箱、GitHub 的 SSH 帳號（不是個人信箱）
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
    rules = RULES
    if files is None:  # 掃資料夾（快照）時才檢查禁用資料夾與私人網址；私人倉庫本來就有它們
        rules = {**RULES, "rule:private-repo": PRIVATE_URL}
        files = []
        for p in sorted(root.rglob("*")):
            parts = p.relative_to(root).parts
            if any(x in FORBIDDEN_DIRS for x in parts[:-1]):
                continue  # 禁用資料夾裡的東西：資料夾本身已回報
            if parts[-1] in FORBIDDEN_DIRS and p.is_dir():
                found.append((p.relative_to(root).as_posix(), 0, "forbidden dir"))
            elif p.is_file():
                files.append(p.relative_to(root).as_posix())
    for rel in files:
        path = root / rel
        data = path.read_bytes()
        if b"\0" in data[:8192]:
            continue
        for n, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
            low = line.lower().replace("\\/", "/").replace("%2f", "/")
            hits = [(rel, n, p) for p in patterns if p.lower() in low]
            if not hits and rel not in RULES_EXEMPT:
                for name, rx in rules.items():
                    m = [x for x in rx.findall(low) if name != "rule:email" or not any(ok in x for ok in EMAIL_OK)]
                    if m:
                        hits.append((rel, n, name))
            found += hits
    return found


def scrub_private_links(text):
    """私人倉庫的 Markdown 連結 → 「文字（私人倉庫）」；其他私人網址 → 「（私人倉庫連結）」。"""
    return PRIVATE_URL.sub("（私人倉庫連結）", PRIVATE_MD_LINK.sub(r"\1（私人倉庫）", text))


def scan_artifacts(paths, patterns):
    """匯出產物逐位元組找精確字串（zip 逐一讀成員）；回傳 [(名稱, pattern)]，名稱相對於各路徑的上一層。"""
    found = []
    for path in map(Path, paths):
        for f in (sorted(path.rglob("*")) if path.is_dir() else [path]):
            if not f.is_file():
                continue
            name = f.relative_to(path.parent).as_posix()
            if f.suffix == ".zip":
                with zipfile.ZipFile(f) as zf:
                    blobs = [(f"{name}:{n}", zf.read(n)) for n in zf.namelist()]
            else:
                blobs = [(name, f.read_bytes())]
            found += [(n, p) for n, data in blobs for p in patterns if p.encode() in data]
    return found


def snapshot(ref, out, patterns=None):
    """git archive ref 解到 out，release/public/ 的內容放到根目錄（覆蓋同名檔）、拿掉 release/、私人連結改純文字；
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
    for f in out.rglob("*"):
        if f.is_file() and b"\0" not in f.read_bytes()[:8192]:
            text = f.read_text(encoding="utf-8", errors="surrogateescape")
            scrubbed = scrub_private_links(text)
            if scrubbed != text:
                f.write_text(scrubbed, encoding="utf-8", errors="surrogateescape")
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
        out = build(argv[2])
        for p in out:
            if p.is_dir():
                size = sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
                print(f"BUILD {p.relative_to(ROOT)}/  {size / 1e6:.1f} MB")
            else:
                print(f"BUILD {p.relative_to(ROOT)}  {p.stat().st_size / 1e6:.1f} MB  sha256 {_sha256(p)}")
        pats = forbidden_patterns(ROOT)
        found = scan_artifacts(out, pats)
        for name, p in found:
            print(f"BUILD 不乾淨 {name}  含禁用字串（第 {pats.index(p) + 1} 項）")
        print(f"BUILD 產物掃描{'乾淨' if not found else f'：{len(found)} 筆'}")
        return 1 if found else 0
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
