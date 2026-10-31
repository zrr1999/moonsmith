#!/usr/bin/env bash
set -euo pipefail

bin_dir=${1:?usage: install-packslip.sh /absolute/bin-directory}
[[ "$bin_dir" = /* ]]
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL \
  https://github.com/jdx/packslip/releases/download/v1.11.3/install.sh -o "$installer"
printf '%s  %s\n' c8efeebd9e7af0f7951defb0a8a4513adb9a2e595018b87ea957f96e52299243 "$installer" |
  shasum -a 256 --check
PACKSLIP_BIN_DIR="$bin_dir" sh "$installer"
