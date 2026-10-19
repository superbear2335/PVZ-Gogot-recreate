"""列出 pak/images 中的关键贴图与尺寸。"""
from pathlib import Path
from PIL import Image

img_dir = Path(r"D:\Develop\workspace\pvz\pak\images")
for name in ["background1.jpg", "background2.jpg", "background3.jpg", "background4.jpg", "background5.jpg", "background6.jpg", "SeedPacket_Larger.png", "SeedPacket.png", "SunBank.png", "ProjectilePea.png", "ProjectileSnowPea.png", "LawnMower.png"]:
    p = img_dir / name
    if p.exists():
        im = Image.open(p)
        print(f"{name}: {im.size} {im.mode}")

print("\n--- 含 background/lawn 的图片 ---")
for p in sorted(img_dir.glob("*")):
    low = p.name.lower()
    if any(k in low for k in ["background", "lawn", "house", "front"]) and p.suffix.lower() in {".png", ".jpg"}:
        try:
            im = Image.open(p)
            print(f"{p.name}: {im.size}")
        except Exception:
            pass
