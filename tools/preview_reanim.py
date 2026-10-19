"""尝试用 PIL 还原 PVZ reanim，输出预览图用于校准坐标/变换语义。"""
from __future__ import annotations

import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

PAK = Path(r"D:\Develop\workspace\pvz\pak")
OUT = Path(r"D:\Develop\workspace\pvz\docs\reanim_preview")


def load(name: str):
    text = (PAK / "reanim" / f"{name}.reanim").read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


def num(t, key, default):
    v = t.findtext(key)
    return float(v) if v not in (None, "") else default


def image_for(img_id: str) -> Image.Image | None:
    stem = img_id.replace("IMAGE_REANIM_", "", 1)
    # 逐级尝试：完整名、去下划线、大小写不敏感
    for p in (PAK / "reanim").glob("*.png"):
        if p.stem.lower().replace("_", "") == stem.lower().replace("_", ""):
            return Image.open(p).convert("RGBA")
    return None


def render(name: str, frame: int, out_path: Path, scale: float = 1.0) -> None:
    root = load(name)
    canvas = Image.new("RGBA", (240, 240), (30, 30, 30, 255))
    origin = (120, 170)
    for track in root.findall("track"):
        t_elems = track.findall("t")
        # 累积状态，逐帧推进到 frame
        st = {
            "x": 0.0,
            "y": 0.0,
            "sx": 1.0,
            "sy": 1.0,
            "kx": 0.0,
            "ky": 0.0,
            "a": 1.0,
            "f": 0,
            "i": None,
        }
        for i, t in enumerate(t_elems):
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
        # PVZ 用中心锚点、sx/sy 缩放、kx/ky 剪切
        w, h = img.size
        sx, sy = st["sx"] * scale, st["sy"] * scale
        kx, ky = math.radians(st["kx"]), math.radians(st["ky"])
        # 2x2: [sx*cos(ky), -sy*sin(kx); sx*sin(ky), sy*cos(kx)]
        m00, m01 = sx * math.cos(ky), -sy * math.sin(kx)
        m10, m11 = sx * math.sin(ky), sy * math.cos(kx)
        # PIL 需要目标->源的逆矩阵，以中心为锚点
        det = m00 * m11 - m01 * m10
        if abs(det) < 1e-6:
            continue
        inv = (m11 / det, -m01 / det, -m10 / det, m00 / det)
        # 目标坐标减去平移后，逆变换到原图坐标（原图原点在图像中心）
        cx, cy = origin[0] + st["x"] * scale, origin[1] - st["y"] * scale
        tx = inv[0] * (-cx) + inv[1] * (-cy) + w / 2
        ty = inv[2] * (-cx) + inv[3] * (-cy) + h / 2
        part = img.transform(
            canvas.size,
            Image.Transform.AFFINE,
            (inv[0], inv[1], tx, inv[2], inv[3], ty),
            resample=Image.Resampling.BICUBIC,
        )
        if st["a"] < 1.0:
            alpha = part.getchannel("A").point(lambda v: int(v * st["a"]))
            part.putalpha(alpha)
        canvas.alpha_composite(part)
    canvas.save(out_path)


if __name__ == "__main__":
    name = sys.argv[1]
    frames = [int(x) for x in sys.argv[2:]] or [10]
    OUT.mkdir(parents=True, exist_ok=True)
    for f in frames:
        p = OUT / f"{name}_{f:03d}.png"
        render(name, f, p)
        print(p)
