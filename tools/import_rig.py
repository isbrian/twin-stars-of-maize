#!/usr/bin/env python3
"""把 p4 的關節資料換算成遊戲尺寸，寫進 game/rig/（MV-SLICE-001b2a Task 1）。

用法：
  python3 tools/import_rig.py          寫入 game/rig/{角色}_rig.json
  python3 tools/import_rig.py --check  只比對、不寫；有差異時退出碼 1

來源 prototypes/p4-art-pipeline/rig/{角色}_rig.json（只讀）。骨頭表（bones、root_length）、原點（origin）、動作檔（anims）、是否人形（humanoid）也寫進去，
由 world/rig_view.gd 讀取。所有像素座標（reference.size、reference.joints、
分件的 size／pivot／tip）乘上 k = 180 / 身高，並記下 "scale": k；身高與 ground 的定義同 p4 rig.gd。
只保留 chr_ 分件：武器等附件改由 game/rig/attachments.json 掛（它們的座標屬於另一張來源圖）。

b2b1 起另有 tools/cut_rig.py 從基準圖切的角色（CUT_CHARS，來源 tools/rig_src/{角色}_rig.json）：
k = TARGETS（遊戲中的高度，同 b1 立繪 fit_height）÷ 來源的 content_height；所有像素座標（reference.size、reference.joints、
分件的 size／pivot／tip、points 的 at）乘上 k。這些角色不是人形、基準圖面向左（faces −1；FACES_RIGHT 的 NPC 面向右，faces 1）、動作檔 res://rig/{角色}_anims.json。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P4_RIG = ROOT / "prototypes" / "p4-art-pipeline" / "rig"
GAME_RIG = ROOT / "game" / "rig"
CHARS = ("hunahpu", "xbalanque")
RIG_SRC = ROOT / "tools" / "rig_src"
TARGETS = {"crawler": 70, "flyer": 60, "sevenmacaw": 450,  # 遊戲中的高度（同 b1 立繪的 fit_height）
           "xmucane": 165, "healer_man": 170, "healer_woman": 165, "rat": 40, "chimalmat": 340,
           "reflector": 150}  # MV-SLICE-001c4c2
CUT_CHARS = ("crawler", "flyer", "sevenmacaw", "xmucane", "healer_man", "healer_woman", "rat", "chimalmat", "reflector")  # 有 tools/rig_src/{角色}_rig.json 的角色
FACES_RIGHT = ("xmucane", "healer_man", "healer_woman", "rat")  # 基準圖面向右的切件角色（MV-SLICE-001b2b2 NPC）
BODY_HEIGHT = 180.0
PART_COORDS = ("size", "pivot", "tip")
PELVIS_LENGTH = 60.0  # p4 基準圖像素；乘上 scale 就是 root_length（終點空字串的骨頭用）
# [骨頭, 父骨頭, 起點關節, 終點關節]；父骨頭排在前面；終點空字串＝固定朝下（骨盆）。同 p4 rig.gd
TWIN_BONES = [
    ["pelvis", "", "hip", ""],
    ["spine", "pelvis", "hip", "neck"],
    ["head", "spine", "neck", "crown"],
    ["upperarm_l", "spine", "shoulder_l", "elbow_l"],
    ["forearm_l", "upperarm_l", "elbow_l", "wrist_l"],
    ["hand_l", "forearm_l", "wrist_l", "hand_tip_l"],
    ["thigh_l", "pelvis", "hip_l", "knee_l"],
    ["shin_l", "thigh_l", "knee_l", "ankle_l"],
    ["foot_l", "shin_l", "ankle_l", "toe_l"],
    ["loincloth", "pelvis", "waist", "loin_tip"],
    ["thigh_r", "pelvis", "hip_r", "knee_r"],
    ["shin_r", "thigh_r", "knee_r", "ankle_r"],
    ["foot_r", "shin_r", "ankle_r", "toe_r"],
    ["upperarm_r", "spine", "shoulder_r", "elbow_r"],
    ["forearm_r", "upperarm_r", "elbow_r", "wrist_r"],
    ["hand_r", "forearm_r", "wrist_r", "hand_tip_r"],
]


def _p4(char: str) -> dict:
    return json.loads((P4_RIG / f"{char}_rig.json").read_text())


def body_height(joints: dict) -> float:
    """同 p4 rig.gd：ground＝腳踝與腳趾的最低點；身高＝ground.y − crown.y。"""
    ground = max(joints[j][1] for j in ("ankle_r", "toe_r", "ankle_l", "toe_l"))
    return ground - joints["crown"][1]


def rig_scale(char: str) -> float:
    """p4 基準圖像素 → 遊戲像素的比例（import_art 的分件條目也用它）。"""
    return BODY_HEIGHT / body_height(_p4(char)["reference"]["joints"])


def _mul(xy, k: float) -> list:
    return [round(c * k, 4) for c in xy]


def game_rig(char: str) -> dict:
    src = _p4(char)
    k = rig_scale(char)
    ref = src["reference"]
    parts = {}
    for name, p in src["parts"].items():
        if not name.startswith("chr_"):
            continue
        parts[name] = {key: (_mul(v, k) if key in PART_COORDS else v) for key, v in p.items()}
    return {
        "scale": k,
        "root_length": PELVIS_LENGTH * k,
        "humanoid": True,  # 肩膀收邊、手勢、近側手臂分組、吹射覆寫、武器附件只給人形骨架
        "anims": "res://rig/twin_anims.json",
        "origin": {"x_joint": "hip", "sole_parts": ["foot_r", "foot_l"]},  # 原點＝x_joint 的 x、sole_parts 靜止姿勢最低的不透明像素
        "bones": TWIN_BONES,
        "reference": {"size": _mul(ref["size"], k), "joints": {j: _mul(xy, k) for j, xy in ref["joints"].items()}},
        "parts": parts,
    }


def _cut(char: str) -> dict:
    return json.loads((RIG_SRC / f"{char}_rig.json").read_text(encoding="utf-8"))


def cut_scale(char: str) -> float:
    """cut_rig 來源像素 → 遊戲像素的比例（import_art 的分件條目也用它）。"""
    return TARGETS[char] / _cut(char)["reference"]["content_height"]


def cut_game_rig(char: str) -> dict:
    src = _cut(char)
    k = cut_scale(char)
    ref = src["reference"]
    return {
        "scale": k,
        "root_length": src["root_length"] * k,
        "humanoid": False,
        "faces": 1 if char in FACES_RIGHT else -1,  # 基準圖面向：FACES_RIGHT 面向右，其餘面向左（R5）；骨架 scale.x = 面向 × faces
        "anims": f"res://rig/{char}_anims.json",
        "origin": src["origin"],
        "bones": src["bones"],
        "reference": {"size": _mul(ref["size"], k), "joints": {j: _mul(xy, k) for j, xy in ref["joints"].items()}},
        "parts": {n: {key: (_mul(v, k) if key in PART_COORDS else v) for key, v in p.items()} for n, p in src["parts"].items()},
        "points": {n: {**p, "at": _mul(p["at"], k)} for n, p in src.get("points", {}).items()},
    }


def build() -> dict:
    rigs = {c: game_rig(c) for c in CHARS} | {c: cut_game_rig(c) for c in CUT_CHARS}
    return {f"{c}_rig.json": (json.dumps(r, indent=1, ensure_ascii=False) + "\n").encode() for c, r in rigs.items()}


def main(argv) -> int:
    files = build()
    drift = [n for n, data in files.items() if not (GAME_RIG / n).exists() or (GAME_RIG / n).read_bytes() != data]
    if "--check" in argv:
        for n in drift:
            print(f"差異：game/rig/{n}")
        return 1 if drift else 0
    GAME_RIG.mkdir(parents=True, exist_ok=True)
    for n in drift:
        (GAME_RIG / n).write_bytes(files[n])
    print(f"寫入 {len(drift)} 個檔案（共 {len(files)}）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
