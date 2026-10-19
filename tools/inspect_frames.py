"""打印选定 reanim 轨道每帧的 f/x/y/scale，帮助还原动画语义。"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PAK = Path(r"D:\Develop\workspace\pvz\pak")


def load(name: str):
    text = (PAK / "reanim" / f"{name}.reanim").read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


def main(name: str, wanted: list[str]) -> None:
    root = load(name)
    print("fps", root.findtext("fps"))
    for track in root.findall("track"):
        tn = track.findtext("name")
        if tn not in wanted:
            continue
        print(f"\n== {tn} ==")
        for idx, t in enumerate(track.findall("t")):
            if idx > 30:
                break
            f = t.findtext("f")
            x = t.findtext("x")
            y = t.findtext("y")
            i = t.findtext("i")
            kx = t.findtext("kx")
            ky = t.findtext("ky")
            sx = t.findtext("sx")
            sy = t.findtext("sy")
            a = t.findtext("a")
            print(f"{idx:3d} f={f!s:>3} x={x!s:>7} y={y!s:>7} sx={sx!s:>5} sy={sy!s:>5} kx={kx!s:>5} ky={ky!s:>5} a={a!s:>4} i={i}")


if __name__ == "__main__":
    nm = sys.argv[1] if len(sys.argv) > 1 else "PeaShooter"
    main(nm, sys.argv[2:] or ["anim_full_idle", "anim_idle", "idle_mouth", "anim_face", "stalk_bottom", "backleaf"])
