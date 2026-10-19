"""快速检查 PVZ .reanim 结构，辅助实现 Godot 动画播放器。"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PAK = Path(r"D:\Develop\workspace\pvz\pak")


def load(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


def main(name: str) -> None:
    root = load(PAK / "reanim" / f"{name}.reanim")
    fps = root.findtext("fps")
    tracks = root.findall("track")
    print(f"{name}: fps={fps} tracks={len(tracks)}")
    for track in tracks:
        track_name = track.findtext("name")
        frames = track.findall("t")
        images = [f.findtext("i") for f in frames if f.findtext("i")]
        fs = sorted({f.findtext("f") for f in frames if f.findtext("f") is not None})
        print(f"  {track_name}: frames={len(frames)} images={images[:3]} f={fs[:8]}")
        if track_name in {"anim_full_idle", "backleaf", "stalk_bottom", "anim_idle"}:
            for t in frames[:3]:
                print("     ", ET.tostring(t, encoding="unicode").strip())


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "PeaShooter")
