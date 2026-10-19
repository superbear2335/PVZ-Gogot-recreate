"""渲染单个 reanim 帧，支持隐藏配件轨道，用于校准最终生成器。"""
from __future__ import annotations

import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

PAK = Path(r"D:\Develop\workspace\pvz\pak")
OUT = Path(r"D:\Develop\workspace\pvz\docs\reanim_preview")
HIDE = {
    "Zombie_flaghand",
    "Zombie_innerarm_screendoor",
    "Zombie_innerarm_screendoor_hand",
    "Zombie_outerarm_screendoor",
    "anim_screendoor",
    "Zombie_duckytube",
    "anim_cone",
    "anim_bucket",
}


def load(name: str):
    text = (PAK / "reanim" / f"{name}.reanim").read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


def image_for(img_id: str) -> Image.Image | None:
    stem = img_id.replace("IMAGE_REANIM_", "", 1)
    for p in (PAK / "reanim").glob("*.png"):
        if p.stem.lower().replace("_", "") == stem.lower().replace("_", ""):
            return Image.open(p).convert("RGBA")
    return None


def render(name: str, frame: int, out_path: Path) -> None:
    root = load(name)
    W, H = 240, 280
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    origin = (120, 140)
    for tr in root.findall("track"):
        tn = tr.findtext("name") or ""
        if tn in HIDE:
            continue
        st = {"x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "kx": 0.0, "ky": 0.0, "a": 1.0, "f": 0, "i": None}
        for i, t in enumerate(tr.findall("t")):
            for key in ("x", "y", "sx", "sy", "kx", "ky", "a"):
                v = t.findtext(key)
                if v not in (None, ""):
                    st[key] = float(v)
            f = t.findtext("f")
            if f not in (None, ""):
                st["f"] = int(f)
            img = t.findtext("i")
            if img:
                st["i"] = img
            if i == frame:
                break
        if st["f"] < 0 or not st["i"]:
            continue
        img = image_for(st["i"])
        if img is None:
            continue
        w, h = img.size
        sx, sy = st["sx"], st["sy"]
        kx, ky = math.radians(st["kx"]), math.radians(st["ky"])
        m00, m01 = sx * math.cos(ky), -sy * math.sin(kx)
        m10, m11 = sx * math.sin(ky), sy * math.cos(kx)
        det = m00 * m11 - m01 * m10
        if abs(det) < 1e-6:
            continue
        inv = (m11 / det, -m01 / det, -m10 / det, m00 / det)
        cx, cy = origin[0] + st["x"], origin[1] + st["y"]
        tx = inv[0] * (-cx) + inv[1] * (-cy)
        ty = inv[2] * (-cx) + inv[3] * (-cy)
        part = img.transform(canvas.size, Image.Transform.AFFINE, (inv[0], inv[1], tx, inv[2], inv[3], ty), resample=Image.Resampling.BICUBIC)
        if st["a"] < 1.0:
            alpha = part.getchannel("A").point(lambda v: int(v * st["a"]))
            part.putalpha(alpha)
        canvas.alpha_composite(part)
    canvas.save(out_path)
    print(out_path)


if __name__ == "__main__":
    name = sys.argv[1]
    args = sys.argv[2:]
    if "--cone" in args:
        HIDE.discard("anim_cone")
    if "--bucket" in args:
        HIDE.discard("anim_bucket")
    tag = "cone" if "--cone" in args else ("bucket" if "--bucket" in args else "clean")
    frames = [int(x) for x in args if not x.startswith("--")] or [60]
    for f in frames:
        render(name, f, OUT / f"{name}_{tag}_{f:03d}.png")
