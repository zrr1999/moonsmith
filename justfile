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
    grep -F 'historical validation requires MoonBit 0.10.14+7d59c7ec9' .artifacts/historical-rejection.err

# Run the prebuilt checks with MoonBit 0.10.14+7d59c7ec9 on PATH
test-historical:
    #!/usr/bin/env bash
    set -euo pipefail
    .artifacts/historical-bin/historical "${COMPILER_HOME:-}"
    cli_exit=0
    .artifacts/historical-bin/moonsmith run --set seed_start=1272 \
      --set reduction.candidate_limit=0 \
      --set 'output.directory="runs/historical-cli"' || cli_exit=$?
    test "$cli_exit" -eq 3

# Run the built MoonSmith against the moonc currently on PATH.
test-compiler:
    #!/usr/bin/env bash
    set -euo pipefail
    home="${COMPILER_HOME:?compiler directory is required}"
    output="${COMPILER_OUTPUT:-runs/compiler}"
    "$home/bin/moon" version --all
    result=0
    .artifacts/historical-bin/moonsmith run --set seed_start=1272 --set sample_count=1 \
      --set "execution.toolchains=[\"$home\"]" \
      --set 'execution.configurations=["native-debug","native-release","wasm-gc-debug","wasm-debug","js-debug"]' \
      --set "output.directory=\"$output\"" || result=$?
    test "$result" -eq 0 || test "$result" -eq 2 || test "$result" -eq 3
    summary=("$output"/task-*/summary.json)
    test "${#summary[@]}" -eq 1
    jq -e '.attempted == 1 and .operation_errors == 0' "${summary[0]}"

# Measure all workspace tests with the pinned MoonBit coverage reporter
coverage:
    mkdir -p .artifacts/quality
    moon coverage clean
    moon test --target native --enable-coverage
    moon run modules/cli/src/examples/reduction --target native --enable-coverage --deny-warn | tee _build/moonbit_coverage_demo.txt
    moon coverage report -f cobertura -o .artifacts/quality/coverage.xml
    moon coverage report -f summary > .artifacts/quality/coverage-summary.txt

# Measure generation and reduction on fixed seeds using the native benchmark runner
benchmark:
    mkdir -p .artifacts/quality
    moon bench modules/moonbit/src --target native --release --deny-warn 2>&1 | tee .artifacts/quality/benchmarks.log
