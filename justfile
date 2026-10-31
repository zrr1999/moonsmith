set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Initialize the MoonBit registry and install Git hooks
install:
    moon update
    uvx --isolated prek install --prepare-hooks

# Format sources
format:
    just --fmt --unstable
    moon fmt

# Run the repository gate
check:
    uvx --isolated prek run --all-files

# Build all workspace modules and the native executable
build:
    moon build --target native --deny-warn

# Run behavior tests
test:
    moon test --target native

# Build the historical compiler checks with the development toolchain
build-historical:
    mkdir -p .artifacts/historical-bin
    moon build modules/cli/src/examples/historical --target native --deny-warn --output-json > .artifacts/historical-build.jsonl
    cp "$(jq -er 'select(."$message_type" == "artifact" and .package == "zrr1999/moonsmith/examples/historical") | .path' .artifacts/historical-build.jsonl)" .artifacts/historical-bin/historical
    moon install ./modules/cli/src/cmd/moonsmith --bin .artifacts/historical-bin

# Reject the development compiler before any historical case is generated
test-historical-guard:
    #!/usr/bin/env bash
    set -euo pipefail
    if .artifacts/historical-bin/historical > .artifacts/historical-rejection.log 2> .artifacts/historical-rejection.err; then
      cat .artifacts/historical-rejection.log
      exit 1
    fi
    grep -F 'historical validation requires MoonBit 0.10.14+7d59c7ec9 on PATH' .artifacts/historical-rejection.err

# Run the prebuilt checks with MoonBit 0.10.14+7d59c7ec9 on PATH
test-historical:
    #!/usr/bin/env bash
    set -euo pipefail
    .artifacts/historical-bin/historical
    cli_exit=0
    .artifacts/historical-bin/moonsmith run --set seed_start=1272 \
      --set reduction.candidate_limit=0 \
      --set 'output.directory="runs/historical-cli"' || cli_exit=$?
    test "$cli_exit" -eq 3

# Measure workspace tests with the development compiler.
# MOONSMITH_SUT_BIN, when set, is the compiler under test seen by those tests.
coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    dev="${MOONSMITH_DEV_MOON:-moon}"
    if [ -n "${MOONSMITH_SUT_BIN:-}" ]; then
      export PATH="${MOONSMITH_SUT_BIN}:$PATH"
    fi
    mkdir -p .artifacts/quality
    "$dev" coverage clean
    "$dev" test --target native --enable-coverage
    "$dev" run modules/cli/src/examples/reduction --target native --enable-coverage --deny-warn | tee _build/moonbit_coverage_demo.txt
    "$dev" coverage report -f cobertura -o .artifacts/quality/coverage.xml
    "$dev" coverage report -f summary > .artifacts/quality/coverage-summary.txt

# Measure generation and reduction on fixed seeds using the native benchmark runner
benchmark:
    mkdir -p .artifacts/quality
    moon bench modules/moonbit/src --target native --release --deny-warn 2>&1 | tee .artifacts/quality/benchmarks.log
