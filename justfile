set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install Git hooks
install:
    uvx prek install --prepare-hooks --hook-type pre-commit --hook-type commit-msg

# Initialize or refresh the MoonBit package registry index
deps:
    moon update

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

# Run the prototype (pass demo, replay, or --help as arguments)
run *args="run":
    moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- {{ args }}

# Run tests
test:
    moon test --target native
