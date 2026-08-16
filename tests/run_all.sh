#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

run_suite() {
  local spec="$1"
  local log
  log="$(mktemp)"
  echo "==> $spec"
  if nvim --headless -u NONE -l "$spec" >"$log" 2>&1; then
    grep -oE "[0-9]+ passed, [0-9]+ failed" "$log" | tail -n 1
  else
    cat "$log"
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
}

run_suite tests/run.lua
run_suite tests/convert_spec.lua
run_suite tests/edit_insert_spec.lua
run_suite tests/edit_normal_spec.lua
run_suite tests/edit_visual_operator_spec.lua
run_suite tests/edit_paste_commands_spec.lua
