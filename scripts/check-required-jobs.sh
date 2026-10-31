#!/usr/bin/env bash
# GitHub accepts success, skipped, and neutral for a required check. A job
# that only uses `needs` is skipped when a dependency fails, and that skip
# satisfies the ruleset. This command fails unless each upstream result is one
# the selected workflow allows.
set -euo pipefail

require() {
  local label="$1"
  local allowed="$2"
  local actual="$3"
  local choice
  local -a choices=()
  IFS=',' read -r -a choices <<< "$allowed"
  for choice in "${choices[@]}"; do
    if [[ "$actual" == "$choice" ]]; then
      return 0
    fi
  done
  printf '%s must be %s (got %s).\n' "$label" "$allowed" "${actual:-missing}" >&2
  return 1
}

case "${1:-}" in
  tests)
    require "Product tests" success "${PRODUCT_RESULT:-}"
    require "Historical compiler regressions" success "${HISTORICAL_RESULT:-}"
    ;;
  static)
    require "Repository checks" success "${REPOSITORY_RESULT:-}"
    if [[ "${EVENT_NAME:-}" == merge_group ]]; then
      require CodeQL success,skipped "${CODEQL_RESULT:-}"
    else
      require CodeQL success "${CODEQL_RESULT:-}"
    fi
    ;;
  *)
    printf 'usage: %s tests|static\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac

printf 'Required jobs passed.\n'
