"""打印每个 reanim 的总帧数与命名动画区间。"""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

PAK = Path(r"D:\Develop\workspace\pvz\pak")


def load(name: str):
    text = (PAK / "reanim" / f"{name}.reanim").read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


for name in sys.argv[1:]:
    root = load(name)
    tracks = root.findall("track")
    length = max((len(t.findall("t")) for t in tracks), default=0)
    clips = []
    for tr in tracks:
        tn = tr.findtext("name") or ""
        if not tn.startswith("anim_"):
            continue
        marks = []
        for i, t in enumerate(tr.findall("t")):
            f = t.findtext("f")
            if f not in (None, ""):
                marks.append((i, int(f)))
        if marks:
            clips.append((tn, marks[:4]))
    print(f"{name}: fps={root.findtext('fps')} tracks={len(tracks)} frames={length}")
    for c in clips[:12]:
        print("   ", c)
