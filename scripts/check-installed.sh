#!/usr/bin/env bash
set -euo pipefail

binary=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
mkdir "$2"
cd "$2"
"$binary" --help

for equivalent in false true; do
  mkdir "$equivalent"
  cd "$equivalent"
  "$binary" run --set seed_start=42 \
    --set "execution.equivalent_variants=$equivalent" \
    --set 'execution.configurations=["native-debug","native-release","wasm-gc-debug","wasm-debug","js-debug"]' \
    --set 'output.directory="runs"' | tee run.log
  tasks=(runs/task-*)
  test "${#tasks[@]}" -eq 1
  task="${tasks[0]}"
  jq -e '.attempted == 1 and .generated_valid == 1 and .baseline_accepted == 1 and
    .comparisons_complete == 1 and .consistent == 1 and .operation_errors == 0' "$task/summary.json"
  case_path=$(jq -er '.outcome | select(.[0] == "Observed") | .[1].case_directory' "$task/samples/0.json")
  case_name=$(basename "$case_path")
  (
    cd "$task"
    find . -type d \( -name _build -o -name .mooncakes \) -prune -o -type f -print0 |
      xargs -0 shasum -a 256
  ) > before.sha256
  mv "$task" relocated
  case_path="relocated/cases/$case_name"
  attempts=("$case_path"/attempts/run-*)
  before=${#attempts[@]}
  material="$case_path"
  appended=1
  if [ "$equivalent" = true ]; then
    groups=("$case_path"/groups/group-*)
    test "${#groups[@]}" -eq 1
    material="${groups[0]}"
    appended=3
  fi
  "$binary" replay "$material" | tee replay.log
  (cd relocated && shasum -a 256 --check ../before.sha256)
  attempts=("$case_path"/attempts/run-*)
  test "${#attempts[@]}" -eq "$((before + appended))"
  if [ "$equivalent" = true ]; then
    groups=("$case_path"/groups/group-*)
    test "${#groups[@]}" -eq 2
  fi
  cd ..
done
