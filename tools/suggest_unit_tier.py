#!/usr/bin/env python3
"""Suggest UnitData tier from base stats + ability weights. Does NOT modify .tres files."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNITS_DIR = ROOT / "resources" / "units"
ABILITIES_DIR = ROOT / "resources" / "abilities"

# score / TIER_DIVISOR -> suggested tier (clamped 1..6)
TIER_DIVISOR = 4.0

ACTION_WEIGHTS: dict[int, float] = {
    0: 1.0,   # MODIFY_STAT
    1: 1.5,   # HEAL
    2: 3.0,   # SPAWN_UNIT
    3: +2.0,  # DEAL_DAMAGE (base; scaled below)
    4: 2.5,   # SET_HP_FROM_ALLY_PERCENT
    5: 1.0,   # GRANT_GOLD
    6: 1.5,   # PERMANENT_DECK_STAT
    7: 1.0,   # STOCK_FREE_BUFF
    8: 1.0,   # SHOP_CHARACTER_BONUS_HP
    9: 5.0,   # APPLY_CELL_EFFECT
    10: 4.0,  # FRIENDS_HURT_AOE
}

TRIGGER_WEIGHTS: dict[str, float] = {
    "OnCombatStart": 0.5,
    "OnFriendSummoned": 1.0,
    "OnSummoned": 1.5,
    "OnFriendDeath": 1.0,
    "OnRoundStart": 0.5,
    "OnDamageTaken": 1.0,
    "OnDeath": 1.5,
    "OnBuy": 0.5,
    "OnSell": 0.5,
    "OnLevelUp": 0.5,
}

TARGET_WEIGHTS: dict[int, float] = {
    3: 1.0,   # ALL_UNITS (AOE)
    9: 1.5,   # ALL_ALLIES
    12: 1.0,  # CELLS_AROUND_EVENT
    13: 1.0,  # RANDOM_CELLS
}


@dataclass
class UnitRow:
    unit_id: str
    path: str
    attack: int
    max_hp: int
    tier: int
    ability_id: str
    base_score: float
    ability_score: float
    total_score: float
    suggested_tier: int


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _field_int(text: str, name: str, default: int = 0) -> int:
    m = re.search(rf"^{name} = (\d+)", text, re.MULTILINE)
    return int(m.group(1)) if m else default


def _field_str(text: str, name: str, default: str = "") -> str:
    m = re.search(rf'^{name} = "([^"]*)"', text, re.MULTILINE)
    return m.group(1) if m else default


def _resolve_ability_path(unit_text: str) -> Path | None:
    m = re.search(
        r'path="res://resources/abilities/([^"]+\.tres)"',
        unit_text,
    )
    if not m:
        return None
    path = ABILITIES_DIR / m.group(1)
    return path if path.is_file() else None


def _score_ability(ability_path: Path) -> tuple[str, float]:
    text = _read_text(ability_path)
    ability_id = _field_str(text, "id", ability_path.stem)
    score = 0.0

    triggers = re.findall(r'trigger = &"([^"]+)"', text)
    for trigger in triggers:
        score += TRIGGER_WEIGHTS.get(trigger, 0.5)

    target_selectors = [int(x) for x in re.findall(r"target_selector = (\d+)", text)]
    for selector in target_selectors:
        score += TARGET_WEIGHTS.get(selector, 0.0)

    action_blocks = re.findall(
        r"\[sub_resource type=\"Resource\" id=\"[^\"]+\"\]\nscript = ExtResource\(\"3_act\"\)(.*?)(?=\n\[|\Z)",
        text,
        re.DOTALL,
    )
    if not action_blocks:
        action_blocks = re.findall(
            r"script = ExtResource\(\"3_act\"\)(.*?)(?=\n\[sub_resource|\n\[resource\])",
            text,
            re.DOTALL,
        )

    for block in action_blocks:
        action_type = _field_int(block, "action_type", 0)
        weight = ACTION_WEIGHTS.get(action_type, 1.0)
        value = _field_int(block, "value", 0)
        spawn_count = max(1, _field_int(block, "spawn_count", 1))
        threshold = _field_int(block, "threshold", 0)

        if action_type == 2:  # SPAWN
            score += weight * spawn_count
        elif action_type == 3:  # DEAL_DAMAGE
            score += weight + value * 0.5
        elif action_type == 10:  # FRIENDS_HURT_AOE
            score += weight + threshold * 0.25
        elif action_type == 0:  # MODIFY_STAT
            score += weight + abs(value) * 0.35
        else:
            score += weight + abs(value) * 0.2

    return ability_id, score


def _scan_unit(path: Path) -> UnitRow | None:
    if path.parent.name == "tokens":
        return None
    text = _read_text(path)
    unit_id = _field_str(text, "id", path.stem)
    attack = _field_int(text, "attack")
    max_hp = _field_int(text, "max_hp")
    tier = _field_int(text, "tier", 1)
    base_score = float(attack + max_hp)

    ability_path = _resolve_ability_path(text)
    ability_id = ""
    ability_score = 0.0
    if ability_path:
        ability_id, ability_score = _score_ability(ability_path)

    total = base_score + ability_score
    suggested = max(1, min(6, round(total / TIER_DIVISOR)))
    return UnitRow(
        unit_id=unit_id,
        path=str(path.relative_to(ROOT)).replace("\\", "/"),
        attack=attack,
        max_hp=max_hp,
        tier=tier,
        ability_id=ability_id,
        base_score=base_score,
        ability_score=ability_score,
        total_score=total,
        suggested_tier=suggested,
    )


def _print_markdown(rows: list[UnitRow]) -> None:
    print("# Unit Tier Suggestions\n")
    print(f"Formula: `(attack + max_hp) + ability_score`, tier = round(score / {TIER_DIVISOR}), clamp 1..6")
    print("**This script does not write `.tres` files.** Confirm manually before changing tier/cost.\n")
    print("| id | 当前 tier | 建议 tier | 分差 | 攻/血 | ability_id | score |")
    print("|----|-----------|-----------|------|-------|------------|-------|")
    for row in sorted(rows, key=lambda r: (r.suggested_tier, r.unit_id)):
        delta = row.suggested_tier - row.tier
        delta_s = f"{delta:+d}" if delta else "0"
        print(
            f"| `{row.unit_id}` | {row.tier} | {row.suggested_tier} | {delta_s} | "
            f"{row.attack}/{row.max_hp} | `{row.ability_id}` | {row.total_score:.1f} |"
        )


def main() -> int:
    rows: list[UnitRow] = []
    for tres in sorted(UNITS_DIR.rglob("*.tres")):
        row = _scan_unit(tres)
        if row:
            rows.append(row)
    _print_markdown(rows)
    mismatches = [r for r in rows if r.tier != r.suggested_tier]
    print(f"\nTotal shop/playable units scanned: {len(rows)}")
    print(f"Tier mismatches (current != suggested): {len(mismatches)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
