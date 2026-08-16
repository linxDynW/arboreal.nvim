#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

nvim --headless -u NONE -l tests/run.lua

for spec in \
  tests/convert_spec.lua \
  tests/edit_insert_spec.lua \
  tests/edit_normal_spec.lua \
  tests/edit_visual_operator_spec.lua \
  tests/edit_paste_commands_spec.lua; do
  echo "==> $spec"
  nvim --headless -u NONE -l "$spec"
done
