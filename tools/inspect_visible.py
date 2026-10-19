"""列出指定帧下每个轨道的可见状态、图片与位置，用于裁剪配件轨道。"""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

PAK = Path(r"D:\Develop\workspace\pvz\pak")


def load(name: str):
    text = (PAK / "reanim" / f"{name}.reanim").read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


name = sys.argv[1]
frame = int(sys.argv[2]) if len(sys.argv) > 2 else 60
root = load(name)
for idx, tr in enumerate(root.findall("track")):
    tn = tr.findtext("name") or f"<track{idx}>"
    st = {"f": 0, "i": None, "x": 0, "y": 0}
    for i, t in enumerate(tr.findall("t")):
        for k in ("f", "x", "y"):
            v = t.findtext(k)
            if v not in (None, ""):
                st[k] = int(v) if k == "f" else float(v)
        img = t.findtext("i")
        if img:
            st["i"] = img
        if i == frame:
            break
    if st["i"]:
        print(f"{idx:2d} {tn:32s} f={st['f']:3d} x={st['x']:7.1f} y={st['y']:7.1f} {st['i'].replace('IMAGE_REANIM_', '')}")
