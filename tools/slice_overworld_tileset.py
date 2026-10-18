#!/usr/bin/env python3
"""Slice art_source overworld tilesheet into a Godot atlas with path/water bitmasks."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art_source/overworld/overworld_tilesheet_source.jpg"
OUT = ROOT / "assets/sprites/overworld/overworld_tileset.png"
META = ROOT / "assets/sprites/overworld/overworld_tileset_meta.json"

TILE = 64
BASE_COLS = 8
ATLAS_COLS = 16

# Verified by edge sampling of the source sheet (row, col).
PATH_SRC = {
	3: (2, 4),  # N+E
	5: (3, 2),  # N+S
	6: (2, 0),  # E+S
	10: (2, 5),  # E+W
	11: (3, 6),  # N+E+W
	12: (2, 6),  # S+W
	14: (2, 7),  # E+S+W
	15: (2, 3),  # NESW
}

WATER_SRC = {
	5: (4, 1),
	6: (4, 2),
	10: (4, 0),
	12: (4, 5),
	14: (5, 3),
	15: (4, 3),
}


def rot90_mask(mask: int) -> int:
	n = (mask & 1) != 0
	e = (mask & 2) != 0
	s = (mask & 4) != 0
	w = (mask & 8) != 0
	out = 0
	if n:
		out |= 2
	if e:
		out |= 4
	if s:
		out |= 8
	if w:
		out |= 1
	return out


def rotate_image(img: Image.Image, turns_cw: int) -> Image.Image:
	out = img
	for _ in range(turns_cw % 4):
		out = out.transpose(Image.Transpose.ROTATE_270)
	return out


def slice_base(im: Image.Image) -> list[list[Image.Image]]:
	w, h = im.size
	cells: list[list[Image.Image]] = [[None] * BASE_COLS for _ in range(BASE_COLS)]
	for r in range(BASE_COLS):
		for c in range(BASE_COLS):
			x0 = int(round(c * w / BASE_COLS))
			x1 = int(round((c + 1) * w / BASE_COLS))
			y0 = int(round(r * h / BASE_COLS))
			y1 = int(round((r + 1) * h / BASE_COLS))
			cells[r][c] = im.crop((x0, y0, x1, y1)).resize(
				(TILE, TILE), Image.Resampling.LANCZOS
			)
	return cells


def fill_bitmasks(
	cells: list[list[Image.Image]], src_map: dict[int, tuple[int, int]]
) -> dict[int, Image.Image]:
	derived: dict[int, Image.Image] = {}
	for mask, (r, c) in src_map.items():
		derived[mask] = cells[r][c].copy()
	changed = True
	while changed:
		changed = False
		for mask, img in list(derived.items()):
			for turns in range(1, 4):
				new_mask = mask
				for _ in range(turns):
					new_mask = rot90_mask(new_mask)
				if new_mask not in derived:
					derived[new_mask] = rotate_image(img, turns)
					changed = True
	solid = derived.get(15) or next(iter(derived.values()))
	straight_h = derived.get(10, solid)
	straight_v = derived.get(5, solid)
	for mask in range(16):
		if mask in derived:
			continue
		if mask in (1, 4):
			derived[mask] = straight_v.copy()
		elif mask in (2, 8):
			derived[mask] = straight_h.copy()
		else:
			derived[mask] = solid.copy()
	return derived


def main() -> None:
	if not SRC.is_file():
		raise SystemExit(f"missing source tilesheet: {SRC}")
	im = Image.open(SRC).convert("RGBA")
	cells = slice_base(im)
	path_tiles = fill_bitmasks(cells, PATH_SRC)
	water_tiles = fill_bitmasks(cells, WATER_SRC)

	atlas = Image.new("RGBA", (ATLAS_COLS * TILE, (BASE_COLS + 2) * TILE), (0, 0, 0, 0))
	for r in range(BASE_COLS):
		for c in range(BASE_COLS):
			atlas.paste(cells[r][c], (c * TILE, r * TILE))
	for mask in range(16):
		atlas.paste(path_tiles[mask], (mask * TILE, BASE_COLS * TILE))
		atlas.paste(water_tiles[mask], (mask * TILE, (BASE_COLS + 1) * TILE))

	OUT.parent.mkdir(parents=True, exist_ok=True)
	atlas.save(OUT)

	meta = {
		"tile_size": TILE,
		"atlas_cols": ATLAS_COLS,
		"atlas_rows": BASE_COLS + 2,
		"grass_cells": [
			[c, r]
			for r in range(2)
			for c in range(8)
			if not (r == 1 and c >= 6)
		],
		"path_mask_row": 8,
		"water_mask_row": 9,
		"props": {
			"tree": [0, 6],
			"bush": [1, 6],
			"bush_yellow": [2, 6],
			"bush_small": [3, 6],
			"rocks_big": [4, 6],
			"rocks_pair": [5, 6],
			"rock": [6, 6],
			"grass_tuft": [7, 6],
			"stump": [0, 7],
			"log": [1, 7],
			"chest": [2, 7],
			"campfire": [3, 7],
			"tent": [4, 7],
			"bush_low": [5, 7],
			"bush_white": [6, 7],
			"grass_tuft2": [7, 7],
		},
	}
	META.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
	print(f"wrote {OUT} ({atlas.size[0]}x{atlas.size[1]})")
	print(f"wrote {META}")


if __name__ == "__main__":
	main()
