set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install Git hooks
install:
    uvx prek install --prepare-hooks

# Format sources
format:
    just --fmt --unstable
    moon fmt

# Run the repository gate
check:
    uvx prek run --all-files

# Run tests
test:
    moon test --target native
