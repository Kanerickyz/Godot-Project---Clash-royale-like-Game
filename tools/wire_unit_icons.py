#!/usr/bin/env python3
"""Add icon Texture2D references to UnitData .tres files."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNITS_DIR = ROOT / "resources" / "units"
ICONS_DIR = ROOT / "assets" / "sprites" / "units"
ICON_BASE = "res://assets/sprites/units"


def wire_icon(tres_path: Path) -> bool:
    text = tres_path.read_text(encoding="utf-8")
    if "icon = ExtResource" in text:
        return False

    match = re.search(r'^id = "([^"]+)"', text, re.MULTILINE)
    unit_id = match.group(1) if match else tres_path.stem
    if unit_id == "enemy_placeholder":
        return False
    if not (ICONS_DIR / f"{unit_id}.png").is_file():
        print(f"skip {tres_path.name}: missing {unit_id}.png")
        return False

    icon_path = f"{ICON_BASE}/{unit_id}.png"
    text = re.sub(
        r"load_steps=(\d+)",
        lambda m: f"load_steps={int(m.group(1)) + 1}",
        text,
        count=1,
    )
    insert_line = f'[ext_resource type="Texture2D" path="{icon_path}" id="icon_tex"]\n'
    if "[sub_resource" in text:
        text = text.replace("\n[sub_resource", "\n" + insert_line + "[sub_resource", 1)
    else:
        text = text.replace("\n[resource]", "\n" + insert_line + "[resource]", 1)

    if "ability = ExtResource" in text:
        text = re.sub(
            r"(ability = ExtResource\([^\n]+\))\n",
            r'\1\nicon = ExtResource("icon_tex")\n',
            text,
            count=1,
        )
    else:
        text = re.sub(
            r"(stats = SubResource\([^\n]+\))\n",
            r'\1\nicon = ExtResource("icon_tex")\n',
            text,
            count=1,
        )

    tres_path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    wired = 0
    for tres in sorted(UNITS_DIR.rglob("*.tres")):
        if wire_icon(tres):
            print(f"wired {tres.relative_to(ROOT)}")
            wired += 1
    print(f"Done: {wired} files updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
