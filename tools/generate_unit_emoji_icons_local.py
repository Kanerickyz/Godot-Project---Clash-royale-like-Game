#!/usr/bin/env python3
"""Render unit emoji icons offline using Windows Segoe UI Emoji (Pillow)."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "sprites" / "units"
SIZE = 128
FONT_SIZE = 80

FONT_CANDIDATES = [
    Path(r"C:\Windows\Fonts\seguiemj.ttf"),
    Path(r"C:\Windows\Fonts\NotoColorEmoji.ttf"),
]

UNITS: dict[str, dict] = {
    "ant": {"cp": 0x1F41C},
    "cricket": {"cp": 0x1F997},
    "horse": {"cp": 0x1F434},
    "pig": {"cp": 0x1F437},
    "otter": {"cp": 0x1F9A6},
    "duck": {"cp": 0x1F986},
    "beaver": {"cp": 0x1F9AB},
    "fish": {"cp": 0x1F41F},
    "pigeon": {"cp": 0x1F426},
    "peacock": {"cp": 0x1F99A},
    "spider": {"cp": 0x1F577},
    "flamingo": {"cp": 0x1F9A9},
    "hedgehog": {"cp": 0x1F994},
    "crab": {"cp": 0x1F980},
    "blowfish": {"cp": 0x1F421},
    "sheep": {"cp": 0x1F411},
    "hippo": {"cp": 0x1F99B},
    "wolf": {"cp": 0x1F43A},
    "bear": {"cp": 0x1F43B},
    "leopard": {"cp": 0x1F406},
    "mosquito": {"cp": 0x1F99F},
    "turkey": {"cp": 0x1F983},
    "deer": {"cp": 0x1F98C},
    "rooster": {"cp": 0x1F413},
    "bus": {"cp": 0x1F68C},
    "chick": {"cp": 0x1F424},
    "badger": {"cp": 0x1F9A1},
    "armadillo": {"cp": 0x1F6E1},
    "rhino": {"cp": 0x1F98F},
    "crocodile": {"cp": 0x1F40A},
    "boar": {"cp": 0x1F417},
    "shark": {"cp": 0x1F988},
    "gorilla": {"cp": 0x1F98D},
    "fly": {"cp": 0x1FAB0},
    "mammoth": {"cp": 0x1F9A3},
    "zombie_fly": {"cp": 0x1FAB0, "tint": (140, 255, 140, 255)},
    "zombie_cricket": {"cp": 0x1F997, "tint": (140, 255, 140, 255)},
    "spider_hatchling": {"cp": 0x1F577, "scale": 0.72},
    "ram": {"cp": 0x1F411, "scale": 0.85},
    "handler": {"cp": 0x1F9AE},
    "brood_sheep": {"cp": 0x1F411, "tint": (255, 220, 190, 255)},
    "scorpion": {"cp": 0x1F982},
    "camel": {"cp": 0x1F42B},
    "spiker": {"cp": 0x1F421, "tint": (255, 180, 128, 255)},
    "wolverine": {"cp": 0x1F43A, "tint": (220, 140, 90, 255)},
    "ember_rat": {"cp": 0x1F400, "tint": (255, 115, 50, 255)},
    "ash_shaman": {"cp": 0x1F9D9},
    "pyre_guard": {"cp": 0x1F525},
}


def load_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if path.is_file():
            return ImageFont.truetype(str(path), FONT_SIZE)
    return ImageFont.load_default()


def render_icon(unit_id: str, config: dict, font: ImageFont.FreeTypeFont) -> None:
    scale = float(config.get("scale", 1.0))
    text = chr(config["cp"])
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw_size = int(max(tw, th) * scale)
    x = (SIZE - draw_size) // 2
    y = (SIZE - draw_size) // 2
    fill = config.get("tint", (0, 0, 0, 255))
    try:
        draw.text((SIZE // 2, SIZE // 2), text, font=font, anchor="mm", embedded_color=True)
    except TypeError:
        draw.text((SIZE // 2, SIZE // 2), text, font=font, anchor="mm", fill=fill[:3])
    if "tint" in config:
        tint = config["tint"]
        pixels = img.load()
        for py in range(SIZE):
            for px in range(SIZE):
                r, g, b, a = pixels[px, py]
                if a == 0:
                    continue
                pixels[px, py] = (
                    min(255, int(r * tint[0] / 255)),
                    min(255, int(g * tint[1] / 255)),
                    min(255, int(b * tint[2] / 255)),
                    a,
                )
    out_path = OUTPUT_DIR / f"{unit_id}.png"
    img.save(out_path, "PNG")
    print(f"  wrote {out_path.name}")


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    font = load_font()
    print(f"Output: {OUTPUT_DIR}")
    print(f"Font: {font}")
    for unit_id, config in UNITS.items():
        render_icon(unit_id, config, font)
    print(f"Done: {len(UNITS)} icons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
