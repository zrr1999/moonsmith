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
    moon build modules/cli/src/examples/historical --target native --enable-coverage --deny-warn --output-json > .artifacts/historical-build.jsonl
    cp "$(jq -er 'select(."$message_type" == "artifact" and .package == "zrr1999/moonsmith/examples/historical") | .path' .artifacts/historical-build.jsonl)" .artifacts/historical-bin/historical
    moon install ./modules/cli/src/cmd/moonsmith --bin .artifacts/historical-bin

# Run the prebuilt checks with MoonBit 0.10.14+7d59c7ec9 on PATH
test-historical:
    #!/usr/bin/env bash
    set -euo pipefail
    .artifacts/historical-bin/historical | tee .artifacts/historical-coverage.log
    cli_exit=0
    .artifacts/historical-bin/moonsmith run --set seed_start=1272 \
      --set reduction.candidate_limit=0 \
      --set 'output.directory="runs/historical-cli"' || cli_exit=$?
    test "$cli_exit" -eq 3

# Report historical coverage with the development toolchain after the old compiler run
coverage-historical:
    mkdir -p .artifacts/quality
    moon coverage report -t .artifacts/historical-coverage.log -f cobertura -o .artifacts/quality/historical-coverage.xml

# Measure all workspace tests with the pinned MoonBit coverage reporter
coverage:
    mkdir -p .artifacts/quality
    moon coverage clean
    moon test --target native --enable-coverage
    moon coverage report -f cobertura -o .artifacts/quality/coverage.xml
    moon coverage report -f summary > .artifacts/quality/coverage-summary.txt

# Measure generation and reduction on fixed seeds using the native benchmark runner
benchmark:
    mkdir -p .artifacts/quality
    moon bench modules/moonbit/src --target native --release --deny-warn 2>&1 | tee .artifacts/quality/benchmarks.log
