#!/usr/bin/env bash
# Aggregate Godot SceneTree runners for local / CI verification.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$ROOT"

# Fresh clones need import cache before textured resources resolve.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

runners=(
  "res://scripts/core/project_load_smoke_test_runner.gd"
)

failed=0
for script in "${runners[@]}"; do
  echo "==> $script"
  if ! "$GODOT_BIN" --headless --path . --script "$script"; then
    echo "FAIL $script"
    failed=1
  else
    echo "OK   $script"
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "verify runners: FAILED"
  exit 1
fi
echo "verify runners: OK"
