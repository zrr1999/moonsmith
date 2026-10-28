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
