"""生成植物/僵尸预览拼图，快速检查各动画渲染效果。"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location("clean", r"D:\Develop\workspace\pvz\tools\preview_reanim_clean.py")
clean = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clean)

OUT = Path(r"D:\Develop\workspace\pvz\docs\reanim_preview")
items = [
    ("PeaShooter", 90),
    ("SunFlower", 10),
    ("Wallnut", 5),
    ("PotatoMine", 25),
    ("CherryBomb", 5),
    ("Chomper", 12),
    ("PuffShroom", 10),
    ("PeaShooterSingle", 90),
]
cell = (240, 280)
sheet = Image.new("RGBA", (cell[0] * 4, cell[1] * 2), (40, 60, 40, 255))
draw = ImageDraw.Draw(sheet)
for idx, (name, frame) in enumerate(items):
    tmp = OUT / f"_tmp_{name}.png"
    clean.render(name, frame, tmp)
    im = Image.open(tmp).convert("RGBA")
    x = (idx % 4) * cell[0]
    y = (idx // 4) * cell[1]
    sheet.alpha_composite(im, (x, y))
    draw.text((x + 6, y + 4), f"{name}:{frame}", fill=(255, 255, 255, 255))
    tmp.unlink()
p = OUT / "plants_contact.png"
sheet.save(p)
print(p)
