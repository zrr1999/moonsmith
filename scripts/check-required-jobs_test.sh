#!/usr/bin/env bash
set -euo pipefail

script=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-required-jobs.sh

assert() {
  local expected="$1"
  shift
  local status=0
  local output
  if output=$("$@" 2>&1); then
    status=0
  else
    status=$?
  fi
  if [[ "$status" -ne "$expected" ]]; then
    printf 'expected exit %s, got %s: %s\n%s\n' "$expected" "$status" "$*" "$output" >&2
    exit 1
  fi
}

assert 0 env PRODUCT_RESULT=success HISTORICAL_RESULT=success "$script" tests
assert 1 env PRODUCT_RESULT=failure HISTORICAL_RESULT=success "$script" tests
assert 1 env PRODUCT_RESULT=success HISTORICAL_RESULT=failure "$script" tests
assert 1 env PRODUCT_RESULT=skipped HISTORICAL_RESULT=success "$script" tests
assert 1 env PRODUCT_RESULT=success HISTORICAL_RESULT=skipped "$script" tests
assert 1 env PRODUCT_RESULT=cancelled HISTORICAL_RESULT=success "$script" tests
assert 1 env PRODUCT_RESULT=success HISTORICAL_RESULT=cancelled "$script" tests
assert 1 env PRODUCT_RESULT=neutral HISTORICAL_RESULT=success "$script" tests
assert 1 env PRODUCT_RESULT=success HISTORICAL_RESULT=neutral "$script" tests
assert 1 env PRODUCT_RESULT=success "$script" tests
assert 1 env HISTORICAL_RESULT=success "$script" tests

assert 0 env REPOSITORY_RESULT=success CODEQL_RESULT=success EVENT_NAME=pull_request "$script" static
assert 0 env REPOSITORY_RESULT=success CODEQL_RESULT=success EVENT_NAME=push "$script" static
assert 0 env REPOSITORY_RESULT=success CODEQL_RESULT=success "$script" static
assert 1 env REPOSITORY_RESULT=failure CODEQL_RESULT=success EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=skipped CODEQL_RESULT=success EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=cancelled CODEQL_RESULT=success EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=neutral CODEQL_RESULT=success EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=failure EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=skipped EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=skipped EVENT_NAME=push "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=skipped "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=cancelled EVENT_NAME=pull_request "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=neutral EVENT_NAME=pull_request "$script" static
assert 0 env REPOSITORY_RESULT=success CODEQL_RESULT=skipped EVENT_NAME=merge_group "$script" static
assert 0 env REPOSITORY_RESULT=success CODEQL_RESULT=success EVENT_NAME=merge_group "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=failure EVENT_NAME=merge_group "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=cancelled EVENT_NAME=merge_group "$script" static
assert 1 env REPOSITORY_RESULT=success CODEQL_RESULT=neutral EVENT_NAME=merge_group "$script" static
assert 1 env REPOSITORY_RESULT=failure CODEQL_RESULT=skipped EVENT_NAME=merge_group "$script" static

assert 2 "$script"
assert 2 "$script" other
