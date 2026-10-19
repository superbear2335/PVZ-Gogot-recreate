"""汇总每个轨道在时间轴上的可见区间（f>=0 / f=-1）。"""
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


root = load(sys.argv[1] if len(sys.argv) > 1 else "PeaShooter")
for track in root.findall("track"):
    name = track.findtext("name")
    marks = []
    for i, t in enumerate(track.findall("t")):
        f = t.findtext("f")
        if f is not None:
            marks.append((i, int(f)))
    print(f"{name}: {marks}")
