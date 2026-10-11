#!/usr/bin/env python3
"""Render unit emoji icons to PNG for Godot UnitData.icon.

Preferred (offline): `generate_unit_emoji_icons_local.py` (Pillow + Segoe UI Emoji).
This script: download Twemoji PNGs from CDN (requires network).
"""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "sprites" / "units"
SIZE = 128
TWEMOJI_BASE = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72"

UNITS: dict[str, dict] = {
    "ant": {"hex": "1f41c"},
    "cricket": {"hex": "1f997"},
    "horse": {"hex": "1f434"},
    "pig": {"hex": "1f437"},
    "otter": {"hex": "1f9a6"},
    "duck": {"hex": "1f986"},
    "beaver": {"hex": "1f9ab"},
    "fish": {"hex": "1f41f"},
    "pigeon": {"hex": "1f426"},
    "peacock": {"hex": "1f99a"},
    "spider": {"hex": "1f577"},
    "flamingo": {"hex": "1f9a9"},
    "hedgehog": {"hex": "1f994"},
    "crab": {"hex": "1f980"},
    "blowfish": {"hex": "1f421"},
    "sheep": {"hex": "1f411"},
    "hippo": {"hex": "1f99b"},
    "wolf": {"hex": "1f43a"},
    "bear": {"hex": "1f43b"},
    "leopard": {"hex": "1f406"},
    "mosquito": {"hex": "1f99f"},
    "turkey": {"hex": "1f983"},
    "deer": {"hex": "1f98c"},
    "rooster": {"hex": "1f413"},
    "bus": {"hex": "1f68c"},
    "chick": {"hex": "1f424"},
    "badger": {"hex": "1f9a1"},
    "armadillo": {"hex": "1f6e1"},
    "rhino": {"hex": "1f98f"},
    "crocodile": {"hex": "1f40a"},
    "boar": {"hex": "1f417"},
    "shark": {"hex": "1f988"},
    "gorilla": {"hex": "1f98d"},
    "fly": {"hex": "1fab0"},
    "mammoth": {"hex": "1f9a3"},
    "zombie_fly": {"hex": "1fab0", "tint_rgb": (0.65, 1.0, 0.65)},
    "zombie_cricket": {"hex": "1f997", "tint_rgb": (0.65, 1.0, 0.65)},
    "spider_hatchling": {"hex": "1f577", "font_scale": 0.75},
    "ram": {"hex": "1f411"},
    "handler": {"hex": "1f9ae"},
    "brood_sheep": {"hex": "1f411", "tint_rgb": (1.0, 0.85, 0.75)},
    "scorpion": {"hex": "1f982"},
    "camel": {"hex": "1f42b"},
    "spiker": {"hex": "1f421", "tint_rgb": (1.0, 0.7, 0.5)},
    "wolverine": {"hex": "1f43a", "tint_rgb": (0.85, 0.55, 0.35)},
    "ember_rat": {"hex": "1f400", "tint_rgb": (1.0, 0.45, 0.2)},
    "ash_shaman": {"hex": "1f9d9"},
    "pyre_guard": {"hex": "1f525"},
}


def download_twemoji(unit_id: str, hex_code: str) -> None:
    url = f"{TWEMOJI_BASE}/{hex_code}.png"
    out_path = OUTPUT_DIR / f"{unit_id}.png"
    urllib.request.urlretrieve(url, out_path)
    print(f"  wrote {out_path.name} (twemoji)")


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Output: {OUTPUT_DIR}")
    print("Using Twemoji CDN (run generate_unit_emoji_icons.ps1 on Windows for variants)")
    for unit_id, config in UNITS.items():
        download_twemoji(unit_id, config["hex"])
    print(f"Done: {len(UNITS)} icons (basic; use .ps1 for tint/scale variants)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
