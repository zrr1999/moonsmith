"""Exercise FP-0001 against isolated copies, including expected failures."""

import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEMBERS = ("contracts", "engine", "moonbit", "cli")


def run(root, *args, succeeds=True):
    result = subprocess.run(args, cwd=root, text=True, capture_output=True, timeout=180)
    if (result.returncode == 0) != succeeds:
        raise AssertionError(f"{args!r}\n{result.stdout}\n{result.stderr}")
    return result.stdout + result.stderr


def check_import(root, relative, dependency, rule):
    path = root / relative
    original = path.read_text()
    try:
        path.write_text(
            original.replace("import {", f'import {{\n  "{dependency}",', 1)
        )
        output = run(root, "alint", "--compact", succeeds=False)
        assert rule in output, output
    finally:
        path.write_text(original)


def check_architecture(root):
    run(root, "alint")
    for relative, dependency, rule in (
        (
            "modules/contracts/src/moon.pkg",
            "zrr1999/moonsmith-engine",
            "contracts-have-no-internal-dependencies",
        ),
        (
            "modules/engine/src/moon.pkg",
            "zrr1999/moonsmith-moonbit",
            "engine-stays-language-neutral",
        ),
        (
            "modules/moonbit/src/moon.pkg",
            "zrr1999/moonsmith-engine",
            "moonbit-does-not-own-orchestration",
        ),
        (
            "modules/engine/moon.mod",
            "moonbitlang/async@0.22.4",
            "pure-packages-have-no-host-imports",
        ),
        (
            "modules/cli/src/report/moon.pkg",
            "moonbitlang/async/fs",
            "pure-packages-have-no-host-imports",
        ),
        (
            "modules/cli/src/host/moon.pkg",
            "zrr1999/moonsmith/app",
            "infrastructure-stays-below-application",
        ),
        (
            "modules/cli/src/cmd/moonsmith/moon.pkg",
            "zrr1999/moonsmith-engine",
            "cli-uses-application-and-host",
        ),
    ):
        check_import(root, relative, dependency, rule)
    for relative in (
        "modules/contracts/README.md",
        "modules/contracts/LICENSE",
        "moon.work",
        *(f"modules/{member}" for member in MEMBERS),
        *(f"modules/{member}/src/moon.pkg" for member in MEMBERS[:3]),
        *(
            f"modules/cli/src/{package}"
            for package in (
                "host",
                "toolchains/moon",
                "artifacts",
                "report",
                "app",
                "cmd/moonsmith",
            )
        ),
    ):
        path = root / relative
        # Move outside the lint root so a missing component cannot be matched elsewhere.
        with tempfile.TemporaryDirectory(prefix="moonsmith-removed-") as removed:
            destination = Path(removed) / path.name
            shutil.move(path, destination)
            try:
                run(root, "alint", succeeds=False)
            finally:
                shutil.move(destination, path)
    run(root, "alint")
    print("FP-0001: required components and dependency boundaries verified", flush=True)


def check_workspace(root):
    tree = run(root, "moon", "-C", "modules/cli", "tree")
    for member in MEMBERS:
        assert f"{root}/modules/{member}" in tree, tree
    provider = root / "modules/contracts/src/workspace_probe.mbt"
    consumer = root / "modules/engine/src/workspace_probe_wbtest.mbt"
    provider.write_text("///|\npub fn workspace_probe() -> Int { 11 }\n")
    consumer.write_text(
        '///|\ntest "workspace provider changes reach the consumer" { assert_eq(@contracts.workspace_probe(), 11) }\n'
    )
    args = ("moon", "test", "-p", "zrr1999/moonsmith-engine", "--target", "native")
    run(root, *args)
    provider.write_text("///|\npub fn workspace_probe() -> Int { 17 }\n")
    failure = run(root, *args, succeeds=False)
    assert "workspace provider changes reach the consumer" in failure, failure
    consumer.write_text(consumer.read_text().replace(", 11)", ", 17)"))
    run(root, *args)
    provider.unlink()
    consumer.unlink()
    print("FP-0001: local member edits reach downstream tests", flush=True)

    versions = {}
    for member in MEMBERS:
        manifest = (root / "modules" / member / "moon.mod").read_text()
        match = re.search(r'^version = "([^\"]+)"$', manifest, re.MULTILINE)
        assert match, manifest
        versions[member] = match.group(1)
    version = "0.0.1" if versions["contracts"] != "0.0.1" else "0.0.2"
    provider_manifest = root / "modules/contracts/moon.mod"
    provider_manifest.write_text(
        provider_manifest.read_text().replace(
            f'version = "{versions["contracts"]}"', f'version = "{version}"', 1
        )
    )
    run(root, "moon", "work", "sync")
    for member in MEMBERS[1:]:
        manifest = (root / "modules" / member / "moon.mod").read_text()
        assert f'"zrr1999/moonsmith-contracts@{version}"' in manifest, manifest
        assert f'version = "{versions[member]}"' in manifest, manifest
    print(
        "FP-0001: version sync changes dependencies without bumping consumers",
        flush=True,
    )

    for member in MEMBERS:
        output = run(root, "moon", "-C", f"modules/{member}", "package", "--list")
        match = re.search(r"Package to (.+\.zip)", output)
        assert match, output
        with zipfile.ZipFile(match.group(1)) as archive:
            names = set(archive.namelist())
            assert {"moon.mod", "README.md", "LICENSE"} <= names, names
            assert any(
                name.startswith("src/") and name.endswith(".mbt") for name in names
            ), names
            assert all(not name.startswith("modules/") for name in names), names
    print(
        "FP-0001: all four members package their own manifests, documentation and sources",
        flush=True,
    )


def main():
    with tempfile.TemporaryDirectory(prefix="moonsmith-workspace-") as directory:
        root = Path(directory).resolve()
        shutil.copytree(
            ROOT / "modules",
            root / "modules",
            ignore=shutil.ignore_patterns("_build", ".mooncakes", ".DS_Store"),
        )
        for name in ("moon.work", ".alint.yml"):
            shutil.copy2(ROOT / name, root / name)
        check_architecture(root)
        check_workspace(root)


if __name__ == "__main__":
    main()
