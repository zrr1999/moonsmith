set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install Git hooks
install:
    uvx prek install --prepare-hooks

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

# Check proposal dependencies and index (pass --fix to update the index)
proposal *args="":
    uvx \
        --from 'zendev-proposal @ git+https://github.com/zendev-lab/zendev@2476bb9953ac71835ec3b27e602ef8d275596c86#subdirectory=packages/zendev-proposal' \
        --with 'zendev-core @ git+https://github.com/zendev-lab/zendev@2476bb9953ac71835ec3b27e602ef8d275596c86#subdirectory=packages/zendev-core' \
        zendev-proposal check {{ args }}

# Build all workspace modules and the native executable
build:
    moon build --target native --deny-warn

# Run the prototype (pass demo, replay, or --help as arguments)
run *args="run":
    moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- {{ args }}

# Run tests
test:
    moon test --target native
