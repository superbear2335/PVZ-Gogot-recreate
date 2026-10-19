"""浠?pak 鐨?.reanim + 閮ㄤ欢 PNG 棰勬覆鏌?PVZ 鍔ㄧ敾绮剧伒琛ㄤ笌鍥炬爣銆?
杈撳嚭锛?  assets/pvz/plants/<id>_<anim>.png / .json
  assets/pvz/zombies/<id>_<anim>.png / .json
  assets/pvz/sun/sun.png / .json
  assets/pvz/mower/mower.png / .json
  assets/pvz/icons/<plant>.png
  assets/pvz/ui/*.png|jpg
  assets/pvz/projectiles/*.png

鍧愭爣绯伙細鐢诲竷 240x280锛屽師鐐?(120,140)锛寉 鍚戜笅锛涚敓鎴愭椂璁板綍 ground锛堣剼搴?搴曢儴鍍忕礌锛夛紝
Godot 绔敤 offset=(-120,-ground) 鎶婅剼搴曞榻愬疄浣撳師鐐广€?"""
from __future__ import annotations

import json
import math
import shutil
from dataclasses import dataclass
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw

PAK = Path(r"D:\Develop\workspace\pvz\pak")
OUT = Path(r"D:\Develop\workspace\pvz\assets\pvz")
REANIM = PAK / "reanim"

W, H = 360, 360
ORIGIN = (190, 190)
IMAGE_CACHE: dict[str, Image.Image] = {}
STEM_MAP: dict[str, Path] = {}


def _build_stem_map() -> None:
    for p in REANIM.glob("*.png"):
        STEM_MAP[p.stem.lower().replace("_", "")] = p


def load_reanim(name: str) -> ET.Element:
    text = (REANIM / f"{name}.reanim").read_text(encoding="utf-8", errors="replace")
    if not text.lstrip().startswith("<root>"):
        text = "<root>" + text + "</root>"
    return ET.fromstring(text)


def image_for(img_id: str) -> Image.Image | None:
    if img_id in IMAGE_CACHE:
        return IMAGE_CACHE[img_id]
    stem = img_id.replace("IMAGE_REANIM_", "", 1)
    path = STEM_MAP.get(stem.lower().replace("_", ""))
    if path is None:
        return None
    im = Image.open(path).convert("RGBA")
    IMAGE_CACHE[img_id] = im
    return im


@dataclass
class TrackState:
    x: float = 0.0
    y: float = 0.0
    sx: float = 1.0
    sy: float = 1.0
    kx: float = 0.0
    ky: float = 0.0
    a: float = 1.0
    f: int = 0
    image: str | None = None


def track_state_at(track: ET.Element, frame: int) -> TrackState:
    st = TrackState()
    for i, t in enumerate(track.findall("t")):
        for key in ("x", "y", "sx", "sy", "kx", "ky", "a"):
            val = t.findtext(key)
            if val not in (None, ""):
                setattr(st, key, float(val))
        f = t.findtext("f")
        if f not in (None, ""):
            st.f = int(f)
        img = t.findtext("i")
        if img:
            st.image = img
        if i == frame:
            break
    return st


def draw_track(
    canvas: Image.Image,
    st: TrackState,
    offset: tuple[float, float] = (0.0, 0.0),
    origin: tuple[float, float] = ORIGIN,
) -> None:
    if st.f < 0 or not st.image:
        return
    img = image_for(st.image)
    if img is None:
        return
    w, h = img.size
    sx, sy = st.sx, st.sy
    kx, ky = math.radians(st.kx), math.radians(st.ky)
    m00, m01 = sx * math.cos(ky), -sy * math.sin(kx)
    m10, m11 = sx * math.sin(ky), sy * math.cos(kx)
    det = m00 * m11 - m01 * m10
    if abs(det) < 1e-6:
        return
    inv = (m11 / det, -m01 / det, -m10 / det, m00 / det)
    cx = origin[0] + st.x + offset[0]
    cy = origin[1] + st.y + offset[1]
    tx = inv[0] * (-cx) + inv[1] * (-cy)
    ty = inv[2] * (-cx) + inv[3] * (-cy)
    part = img.transform(
        canvas.size,
        Image.Transform.AFFINE,
        (inv[0], inv[1], tx, inv[2], inv[3], ty),
        resample=Image.Resampling.BICUBIC,
    )
    if st.a < 1.0:
        alpha = part.getchannel("A").point(lambda v: int(v * max(0.0, st.a)))
        part.putalpha(alpha)
    canvas.alpha_composite(part)


def render_frame(
    reanim_name: str,
    frame: int,
    hide: set[str] | None = None,
    overlay: tuple[str, int] | None = None,
    overlay_offsets: tuple[float, float] = (0.0, 0.0),
    canvas_size: tuple[int, int] = (W, H),
    origin: tuple[float, float] = ORIGIN,
) -> Image.Image:
    hide = hide or set()
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    root = load_reanim(reanim_name)
    # 鏃楀笢灞傚厛鐢诲湪韬綋鍚庨潰
    if overlay:
        ov_root = load_reanim(overlay[0])
        for tr in ov_root.findall("track"):
            draw_track(canvas, track_state_at(tr, overlay[1]), overlay_offsets, origin)
    for tr in root.findall("track"):
        tn = tr.findtext("name") or ""
        if tn in hide:
            continue
        draw_track(canvas, track_state_at(tr, frame), (0.0, 0.0), origin)
    return canvas


def union_bbox(images: list[Image.Image]) -> tuple[int, int, int, int]:
    box = None
    for im in images:
        b = im.getbbox()
        if b is None:
            continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box or (0, 0, 1, 1)


def save_sheet(
    images: list[Image.Image],
    out_base: Path,
    fps: float,
    ground: int,
    origin_x: float = ORIGIN[0],
) -> None:
    out_base.parent.mkdir(parents=True, exist_ok=True)
    fw, fh = images[0].size
    sheet = Image.new("RGBA", (fw * len(images), fh), (0, 0, 0, 0))
    for i, im in enumerate(images):
        sheet.alpha_composite(im, (i * fw, 0))
    sheet.save(out_base.with_suffix(".png"))
    meta = {
        "frame_w": fw,
        "frame_h": fh,
        "frames": len(images),
        "fps": fps,
        "ground": ground,
        "origin_x": origin_x,
    }
    out_base.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")


def make_anim(
    reanim_name: str,
    anim: str,
    start: int,
    end: int,
    stride: int,
    fps: float,
    out_base: Path,
    hide: set[str] | None = None,
    overlay: tuple[str, int] | None = None,
    overlay_offsets: tuple[float, float] = (0.0, 0.0),
    canvas_size: tuple[int, int] | None = None,
    origin: tuple[float, float] | None = None,
) -> tuple[int, tuple[int, int, int, int]]:
    frames = list(range(start, end + 1, stride))
    csize = canvas_size or (W, H)
    org = origin or ORIGIN
    images = [render_frame(reanim_name, f, hide, overlay, overlay_offsets, csize, org) for f in frames]
    box = union_bbox(images)
    save_sheet(images, out_base, fps / stride, box[3], org[0])
    print(f"  {out_base.name}: {len(images)} 甯?fps={fps / stride:.1f} bbox={box}")
    return len(images), box


def make_icon(frame_img: Image.Image, out_path: Path, size: int = 54) -> None:
    box = frame_img.getbbox()
    if box is None:
        return
    crop = frame_img.crop(box)
    scale = min(size / crop.width, size / crop.height)
    crop = crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.alpha_composite(crop, ((size - crop.width) // 2, size - crop.height))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(out_path)


ZOMBIE_HIDE = {
    "Zombie_flaghand",
    "Zombie_innerarm_screendoor",
    "Zombie_innerarm_screendoor_hand",
    "Zombie_outerarm_screendoor",
    "anim_screendoor",
    "Zombie_duckytube",
    "anim_cone",
    "anim_bucket",
}


def main() -> None:
    _build_stem_map()
    for sub in ("plants", "zombies", "sun", "mower", "icons", "ui", "projectiles"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)

    print("plants:")
    plants = [
        ("peashooter", "PeaShooter", "idle", 79, 103, 1, 12.0, None),
        ("sunflower", "SunFlower", "idle", 4, 28, 1, 12.0, None),
        ("wallnut", "Wallnut", "idle", 0, 16, 1, 12.0, None),
        ("potatomine", "PotatoMine", "idle", 0, 19, 1, 12.0, None),
        ("potatomine", "PotatoMine", "armed", 20, 30, 1, 12.0, None),
        ("cherrybomb", "CherryBomb", "idle", 0, 13, 1, 30.0, None),
        ("cherrybomb", "CherryBomb", "explode", 14, 26, 1, 30.0, None),
        ("chomper", "Chomper", "idle", 0, 24, 1, 12.0, None),
        ("chomper", "Chomper", "bite", 25, 49, 1, 12.0, None),
        ("chomper", "Chomper", "chew", 50, 65, 1, 12.0, None),
        ("snowpea", "SnowPea", "idle", 79, 103, 1, 12.0, None),
        ("repeater", "PeaShooterSingle", "idle", 79, 103, 1, 12.0, None),
        ("puffshroom", "PuffShroom", "idle", 4, 20, 1, 12.0, None),
    ]
    for pid, reanim, anim, a, b, stride, fps, hide in plants:
        make_anim(reanim, anim, a, b, stride, fps, OUT / "plants" / f"{pid}_{anim}", hide)
    # 鍥炬爣锛氬彇鍚勬鐗?idle 棣栧抚
    for pid, reanim, anim, a, b, stride, fps, hide in plants:
        frame = render_frame(reanim, a, hide)
        make_icon(frame, OUT / "icons" / f"{pid}.png")

    print("zombies:")
    zombies = [
        ("normal", "Zombie", "walk", 44, 89, 2, 12.0, ZOMBIE_HIDE, None),
        ("normal", "Zombie", "eat", 138, 177, 2, 12.0, ZOMBIE_HIDE, None),
        ("cone", "Zombie", "walk", 44, 89, 2, 12.0, ZOMBIE_HIDE - {"anim_cone"}, None),
        ("cone", "Zombie", "eat", 138, 177, 2, 12.0, ZOMBIE_HIDE - {"anim_cone"}, None),
        ("bucket", "Zombie", "walk", 44, 89, 2, 12.0, ZOMBIE_HIDE - {"anim_bucket"}, None),
        ("bucket", "Zombie", "eat", 138, 177, 2, 12.0, ZOMBIE_HIDE - {"anim_bucket"}, None),
        ("flag", "Zombie", "walk", 44, 89, 2, 12.0, ZOMBIE_HIDE, ("Zombie_flagpole", 0)),
        ("flag", "Zombie", "eat", 138, 177, 2, 12.0, ZOMBIE_HIDE, ("Zombie_flagpole", 0)),
        ("ducky", "Zombie", "walk", 44, 89, 2, 12.0, ZOMBIE_HIDE - {"Zombie_duckytube"}, None),
        ("ducky", "Zombie", "eat", 138, 177, 2, 12.0, ZOMBIE_HIDE - {"Zombie_duckytube"}, None),
        ("pole", "Zombie_polevaulter", "walk", 93, 137, 2, 12.0, set(), None),
        ("pole", "Zombie_polevaulter", "jump", 50, 92, 2, 12.0, set(), None),
        ("pole", "Zombie_polevaulter", "eat", 165, 192, 2, 12.0, set(), None),
        ("football", "Zombie_football", "walk", 21, 50, 2, 12.0, set(), None),
        ("football", "Zombie_football", "eat", 51, 86, 2, 12.0, set(), None),
    ]
    for zid, reanim, anim, a, b, stride, fps, hide, overlay in zombies:
        if zid == "pole" and anim == "jump":
            make_anim(reanim, anim, a, b, stride, fps, OUT / "zombies" / f"{zid}_{anim}", hide, overlay,
                (0.0, 0.0), (640, 360), (320, 190))
        else:
            make_anim(reanim, anim, a, b, stride, fps, OUT / "zombies" / f"{zid}_{anim}", hide, overlay)

    print("sun/mower:")
    make_anim("Sun", "sun", 0, 12, 1, 12.0, OUT / "sun" / "sun")
    make_anim("LawnMower", "idle", 0, 16, 1, 20.0, OUT / "mower" / "mower")

    # 静态贴图
    for src, dst in [
        (PAK / "images" / "ProjectilePea.png", OUT / "projectiles" / "pea.png"),
        (PAK / "images" / "ProjectileSnowPea.png", OUT / "projectiles" / "snow_pea.png"),
        (PAK / "images" / "background1.jpg", OUT / "ui" / "background1.jpg"),
        (PAK / "images" / "PvZ_Logo_.png", OUT / "ui" / "logo.png"),
        (PAK / "images" / "SeedPacket_Larger.png", OUT / "ui" / "seed_packet.png"),
        (PAK / "images" / "SunBank.png", OUT / "ui" / "sun_bank.png"),
    ]:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        print(f"  copied {dst.name}")


if __name__ == "__main__":
    main()

