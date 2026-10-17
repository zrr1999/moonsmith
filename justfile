set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Initialize the MoonBit registry and install Git hooks
install:
    moon update
    uvx prek install --prepare-hooks

# Format sources
format:
    just --fmt --unstable
    moon fmt

# Run the repository gate
check:
    uvx prek run --all-files

# Build all workspace modules and the native executable
build:
    moon build --target native --deny-warn

# Run behavior tests
test:
    moon test --target native
