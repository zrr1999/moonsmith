"""Build and validate MoonSmith release material; publishing is a separate command."""

import argparse
import hashlib
import io
import json
import os
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILER = "0.10.18+6c83a7f62"
MODULES = {
    "contracts": "zrr1999/moonsmith-contracts",
    "engine": "zrr1999/moonsmith-engine",
    "moonbit": "zrr1999/moonsmith-moonbit",
    "cli": "zrr1999/moonsmith",
}
DEPENDENCIES = {
    "contracts": set(),
    "engine": {MODULES["contracts"]},
    "moonbit": {MODULES["contracts"]},
    "cli": {MODULES[name] for name in ("contracts", "engine", "moonbit")},
}
CONFIGURATIONS = [
    "native-debug",
    "native-release",
    "wasm-gc-debug",
    "wasm-debug",
    "js-debug",
]
OMIT = {"_build", ".mooncakes", ".git", "__pycache__", ".DS_Store"}


def execute(args, *, cwd=ROOT, log=None, accepted=(0,)):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=False)
    if log is not None:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(result.stdout + result.stderr)
    if result.returncode not in accepted:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(map(str, args))}\n"
            + result.stdout[-3000:]
            + result.stderr[-3000:]
        )
    return result


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def platform_name():
    key = (platform.system(), platform.machine())
    names = {("Darwin", "arm64"): "macos-arm64", ("Linux", "x86_64"): "linux-x86_64"}
    if key not in names:
        raise ValueError(f"unsupported release host: {key}")
    return names[key]


def manifest_value(source, key):
    # These fields use moon fmt's normalized scalar form. Moon validates the full manifest.
    values = re.findall(rf'^{key}\s*=\s*"([^"\n]+)"\s*$', source, re.MULTILINE)
    if len(values) != 1:
        raise ValueError(f"expected exactly one {key} field")
    return values[0]


def validate_versions(root=ROOT, tag=None):
    versions = {}
    for folder, name in MODULES.items():
        source = (root / "modules" / folder / "moon.mod").read_text()
        if manifest_value(source, "name") != name:
            raise ValueError(f"unexpected module identity: {folder}")
        versions[folder] = manifest_value(source, "version")
        declared = re.findall(r'"(zrr1999/moonsmith(?:-[a-z]+)?)@([^"\n]+)"', source)
        if (
            len(declared) != len(DEPENDENCIES[folder])
            or {n for n, _ in declared} != DEPENDENCIES[folder]
        ):
            raise ValueError(f"unexpected internal dependencies: {folder}")
        if any(version != versions[folder] for _, version in declared):
            raise ValueError(f"internal dependency version mismatch: {folder}")
    if len(set(versions.values())) != 1:
        raise ValueError("all four module versions must match")
    version = versions["cli"]
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("release version must be MAJOR.MINOR.PATCH")
    if tag is not None and tag != f"v{version}":
        raise ValueError("release tag does not match module versions")
    return version


def preflight(tag=None):
    version = validate_versions(tag=tag)
    toolchain = execute(["moon", "version", "--all"]).stdout
    if f"moonc v{COMPILER}" not in toolchain:
        raise ValueError(f"release builds require MoonBit {COMPILER}")
    execute(["moon", "check", "--target", "native", "--deny-warn"])
    commit = execute(["git", "rev-parse", "HEAD"]).stdout.strip()
    if tag is not None:
        resolved = execute(
            ["git", "rev-parse", f"refs/tags/{tag}^{{commit}}"]
        ).stdout.strip()
        if resolved != commit:
            raise ValueError("release tag must identify the checked-out commit")
        execute(["git", "merge-base", "--is-ancestor", commit, "origin/main"])
        if execute(["git", "status", "--porcelain"]).stdout:
            raise ValueError("release checkout must be clean")
    return {
        "version": version,
        "commit": commit,
        "platform": platform_name(),
        "host": platform.platform(),
        "toolchain": toolchain,
    }


def safe_member(name):
    path = Path(name)
    return not path.is_absolute() and ".." not in path.parts and "\\" not in name


def validate_package(archive, module):
    expected = {"LICENSE", "README.md", "moon.mod"}
    expected.update(
        str(path.relative_to(module))
        for path in (module / "src").rglob("*")
        if path.is_file()
        and safe_member(str(path.relative_to(module)))
        and not any(part in OMIT for part in path.relative_to(module).parts)
        and (path.suffix in {".mbt", ".c"} or path.name == "moon.pkg")
    )
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        if len(set(names)) != len(names) or any(
            not safe_member(name) or any(part in OMIT for part in Path(name).parts)
            for name in names
        ):
            raise ValueError("package contains duplicate or invalid paths")
        if not expected.issubset(names):
            raise ValueError(
                f"package is missing required files: {sorted(expected - set(names))}"
            )
        for name in names:
            if name.endswith("/"):
                continue
            if package.read(name) != (module / name).read_bytes():
                raise ValueError(f"package content mismatch: {name}")
        return {
            name: digest(package.read(name)) for name in names if not name.endswith("/")
        }


def package_modules(output, version):
    packages = {}
    for folder, name in MODULES.items():
        execute(
            ["moon", "-C", f"modules/{folder}", "package", "--list"],
            log=output / "evidence" / f"package-{folder}.log",
        )
        filename = f"{name.replace('/', '-')}-{version}.zip"
        archive = ROOT / "_build" / "publish" / filename
        files = validate_package(archive, ROOT / "modules" / folder)
        target = output / "evidence" / "packages" / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(archive, target)
        packages[folder] = target
        write_json(
            output / "evidence" / f"package-{folder}.json",
            {"file": filename, "sha256": digest(archive.read_bytes()), "files": files},
        )
    return packages


def consumer(directory, version, module_names=None):
    directory.mkdir(parents=True)
    names = module_names if module_names is not None else list(MODULES.values())[:3]
    imports = ",\n".join(f'  "{name}@{version}"' for name in names)
    (directory / "moon.mod").write_text(
        f'name = "release/consumer"\nversion = "0.0.0"\nimport {{\n{imports},\n}}\n'
    )
    if module_names is not None:
        (directory / "moon.pkg").write_text("")
        (directory / "main.mbt").write_text("pub fn probe() -> Int { 42 }\n")
        return
    (directory / "moon.pkg").write_text("""import {
  "zrr1999/moonsmith-contracts" @contracts,
  "zrr1999/moonsmith-engine" @engine,
  "zrr1999/moonsmith-moonbit" @moonbit,
  "moonbitlang/core/debug",
}
pkgtype(kind: "executable")
""")
    (directory / "main.mbt").write_text("""fn main raise {
  let group = @moonbit.synthesize(42).program.equivalent_group()
  @debug.assert_eq(group.members().length(), 3)
  let cost : @contracts.ReductionCost = group.cost()
  assert_true(cost.nodes > 0)
  @debug.assert_eq(
    @engine.compare(["a", "b"], [], normalize=value => Some(value)),
    @contracts.Incomplete,
  )
  println("MoonSmith library consumer passed")
}
""")


def validate_consumers(packages, output, version):
    with tempfile.TemporaryDirectory(prefix="moonsmith-packages-") as temporary:
        root = Path(temporary)
        for folder, archive in packages.items():
            with zipfile.ZipFile(archive) as package:
                package.extractall(root / folder)
        consumer(root / "consumer", version)
        members = [f"./{folder}" for folder in MODULES] + ["./consumer"]
        (root / "moon.work").write_text("members = " + json.dumps(members) + "\n")
        execute(
            ["moon", "-C", "consumer", "run", ".", "--target", "native", "--deny-warn"],
            cwd=root,
            log=output / "evidence" / "package-consumer.log",
        )
        execute(
            ["moon", "install", "./cli/src/cmd/moonsmith", "--bin", str(root / "bin")],
            cwd=root,
            log=output / "evidence" / "package-cli-install.log",
        )
        execute(
            [str(root / "bin/moonsmith"), "--help"],
            cwd=root,
            log=output / "evidence" / "package-cli-help.log",
        )
        shutil.copytree(
            root / "consumer",
            output / "evidence" / "library-consumer",
            ignore=shutil.ignore_patterns(*OMIT),
            dirs_exist_ok=True,
        )


def evidence_files(root):
    for directory, dirs, names in os.walk(root):
        dirs[:] = sorted(name for name in dirs if name not in OMIT)
        for name in sorted(names):
            path = Path(directory) / name
            if name not in OMIT and not path.is_symlink():
                yield path


def snapshot(root):
    return {
        str(path.relative_to(root)): digest(path.read_bytes())
        for path in evidence_files(root)
    }


def campaign(binary, directory, *, equivalent=False, seed=42, count=1, accepted=(0,)):
    directory.mkdir(parents=True)
    args = [
        str(binary),
        "run",
        "--set",
        f"seed_start={seed}",
        "--set",
        f"sample_count={count}",
        "--set",
        "execution.configurations=" + json.dumps(CONFIGURATIONS),
        "--set",
        "output.directory=" + json.dumps(str(directory / "runs")),
    ]
    if equivalent:
        args += ["--set", "execution.equivalent_variants=true"]
    result = execute(args, cwd=directory, log=directory / "run.log", accepted=accepted)
    tasks = list((directory / "runs").glob("task-*"))
    if len(tasks) != 1:
        raise ValueError("validation requires one complete task")
    task = tasks[0].resolve()
    summary = json.loads((task / "summary.json").read_text())
    if summary["attempted"] != count or summary["operation_errors"] != 0:
        raise ValueError(f"campaign did not finish: {summary}")
    write_json(
        directory / "result.json", {"exit_code": result.returncode, "summary": summary}
    )
    return task, summary


def validate_binary(binary, destination):
    with tempfile.TemporaryDirectory(prefix="moonsmith-installed-") as temporary:
        root = Path(temporary)
        try:
            for equivalent, name in [(False, "ordinary"), (True, "equivalent")]:
                task, summary = campaign(binary, root / name, equivalent=equivalent)
                if summary["consistent"] != 1 or summary["comparisons_complete"] != 1:
                    raise ValueError(
                        f"seed 42 did not complete consistently: {summary}"
                    )
                sample = json.loads((task / "samples/0.json").read_text())
                case = Path(sample["outcome"][1]["case_directory"])
                material = (
                    next((case / "groups").glob("group-*")) if equivalent else case
                )
                relative_material, relative_case = (
                    material.relative_to(task),
                    case.relative_to(task),
                )
                before = snapshot(task)
                attempts_before = len(list((case / "attempts").iterdir()))
                moved = root / (name + "-relocated")
                shutil.move(task, moved)
                execute(
                    [str(binary), "replay", str(moved / relative_material)],
                    cwd=root,
                    log=root / name / "replay.log",
                )
                after = snapshot(moved)
                if any(after.get(name) != sha for name, sha in before.items()):
                    raise ValueError("replay changed existing material")
                attempts_after = len(
                    list((moved / relative_case / "attempts").iterdir())
                )
                if attempts_after != attempts_before + (3 if equivalent else 1):
                    raise ValueError("replay did not append every member")
                if (
                    equivalent
                    and len(list((moved / relative_case / "groups").iterdir())) != 2
                ):
                    raise ValueError("replay did not append a group record")
        finally:
            copy_evidence(root, destination)


def copy_evidence(source, destination):
    shutil.copytree(
        source, destination, ignore=shutil.ignore_patterns(*OMIT), dirs_exist_ok=True
    )
    for path in evidence_files(source):
        if path.name != "attempt.json":
            continue
        attempt = json.loads(path.read_text())
        failed = any(
            observation["configuration"] == "native-release"
            and observation["phase"] == "Build"
            and observation["output"]["status"] == ["Exited", 255]
            for observation in attempt["observations"]
        )
        generated = path.parent / "_build/native/release/build/generated.c"
        if failed and generated.is_file():
            target = destination / path.parent.relative_to(source) / "intermediates"
            target.mkdir(exist_ok=True)
            shutil.copy2(generated, target / "generated.c")
            write_json(
                target / "origin.json",
                {
                    "source": "_build/native/release/build/generated.c",
                    "sha256": digest(generated.read_bytes()),
                },
            )


def validate_current_cases(binary, root):
    for seed in (1272, 3745, 6968):
        directory = root / f"current-seed-{seed}"
        task, _ = campaign(binary, directory, seed=seed, accepted=(0, 2, 3))
        confirmations = []
        for path in task.glob("cases/case-*/attempts/run-*/attempt.json"):
            attempt = json.loads(path.read_text())
            if attempt["purpose"] in {"confirmation", "build-confirmation"}:
                confirmations.append(path.parent)
        for confirmation in confirmations:
            before = snapshot(task)
            result = execute(
                [str(binary), "replay", str(confirmation)],
                cwd=directory,
                log=directory / f"replay-{confirmation.name}.log",
                accepted=(0, 2, 3),
            )
            after = snapshot(task)
            if any(after.get(name) != sha for name, sha in before.items()):
                raise ValueError("current-case replay changed original material")
            write_json(
                directory / f"replay-{confirmation.name}.json",
                {
                    "material": str(confirmation.relative_to(task)),
                    "exit_code": result.returncode,
                },
            )


def make_archive(root, target, extra=None):
    """Archive evidence with an inventory; never include build caches or symlinks."""
    files = {
        str(path.relative_to(root)): path.read_bytes() for path in evidence_files(root)
    }
    if extra:
        files.update(extra)
    inventory = [
        {"path": name, "bytes": len(data), "sha256": digest(data)}
        for name, data in sorted(files.items())
    ]
    files["manifest.json"] = (
        json.dumps({"format_version": 1, "files": inventory}, indent=2) + "\n"
    ).encode()
    files["SHA256SUMS"] = "".join(
        f"{digest(data)}  {name}\n" for name, data in sorted(files.items())
    ).encode()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(target, "w:gz", compresslevel=6) as archive:
        for name, data in sorted(files.items()):
            item = tarfile.TarInfo(name)
            item.size, item.mode, item.mtime = (
                len(data),
                0o755 if name == "moonsmith" else 0o644,
                0,
            )
            archive.addfile(item, io.BytesIO(data))
    verify_archive(target)


def verify_archive(path):
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        names = [item.name for item in members]
        if len(set(names)) != len(names) or any(
            not safe_member(name) for name in names
        ):
            raise ValueError("invalid archive paths")
        if any(not item.isfile() for item in members):
            raise ValueError("archive must contain only regular files")
        by_name = {item.name: item for item in members}
        expected = {}
        for line in (
            archive.extractfile(by_name["SHA256SUMS"]).read().decode().splitlines()
        ):
            sha, name = line.split("  ", 1)
            if name in expected:
                raise ValueError("duplicate checksum path")
            expected[name] = sha
        if set(expected) != set(names) - {"SHA256SUMS"}:
            raise ValueError("checksum inventory does not match archive")
        for name, sha in expected.items():
            if digest(archive.extractfile(by_name[name]).read()) != sha:
                raise ValueError(f"archive checksum mismatch: {name}")


def prepare(output, full=False):
    metadata = preflight()
    version, host = metadata["version"], metadata["platform"]
    if (output / "evidence").exists() or (output / "binary").exists():
        raise ValueError("prepare requires a fresh output directory")
    output.mkdir(parents=True, exist_ok=True)
    packages = package_modules(output, version)
    validate_consumers(packages, output, version)
    build = execute(
        [
            "moon",
            "build",
            "modules/cli/src/cmd/moonsmith",
            "--target",
            "native",
            "--release",
            "--deny-warn",
            "--output-json",
        ],
        log=output / "evidence" / "release-build.log",
    )
    artifacts = [
        json.loads(line) for line in build.stdout.splitlines() if line.startswith("{")
    ]
    binary = Path(
        next(
            item["path"]
            for item in artifacts
            if item.get("$message_type") == "artifact"
            and item.get("package") == "zrr1999/moonsmith/cmd/moonsmith"
        )
    )
    staging = output / "binary"
    staging.mkdir(exist_ok=True)
    installed = staging / "moonsmith"
    shutil.copy2(binary, installed)
    installed.chmod(0o755)
    shutil.copy2(ROOT / "LICENSE", staging / "LICENSE")
    (staging / "README.md").write_text(
        f"# MoonSmith {version}\n\nPlatform: {host}. Source commit: {metadata['commit']}.\n\nRequires MoonBit/core {COMPILER}, a C compiler, and Node.js for the JS configuration. Put `moonsmith` on PATH, then run `moonsmith --help`.\n\nRun `moonsmith run --set seed_start=42` or add `--set execution.equivalent_variants=true`. Use `moonsmith replay GROUP_DIR` for a complete group, or a case/attempt directory for one program.\n"
    )
    metadata["binary_sha256"] = digest(installed.read_bytes())
    write_json(staging / "build.json", metadata)
    write_json(output / "evidence" / "build.json", metadata)
    validate_binary(installed, output / "evidence" / "installed-cli")
    with tempfile.TemporaryDirectory(prefix="moonsmith-release-cases-") as temporary:
        root = Path(temporary)
        try:
            validate_current_cases(installed, root)
            if full:
                _, summary = campaign(
                    installed,
                    root / "five-configuration-equivalents",
                    seed=0,
                    count=100,
                    equivalent=True,
                )
                if (
                    summary["consistent"] != 100
                    or summary["comparisons_complete"] != 100
                ):
                    raise ValueError(f"release acceptance did not complete: {summary}")
        finally:
            copy_evidence(root, output / "evidence" / "current-product")
    make_archive(staging, output / f"moonsmith-{version}-{host}.tar.gz")
    print(json.dumps(metadata, indent=2))


def historical(output):
    with tempfile.TemporaryDirectory(prefix="moonsmith-release-history-") as temporary:
        root = Path(temporary)
        shutil.copytree(
            ROOT / ".artifacts/historical-bin", root / ".artifacts/historical-bin"
        )
        try:
            execute(
                [
                    "just",
                    "--justfile",
                    str(ROOT / "justfile"),
                    "--working-directory",
                    str(root),
                    "test-historical",
                ],
                log=output / "evidence" / "historical.log",
            )
        finally:
            if (root / "runs").exists():
                copy_evidence(root / "runs", output / "evidence" / "historical")
            coverage = root / ".artifacts/historical-coverage.log"
            if coverage.exists():
                shutil.copy2(coverage, output / "evidence" / "historical-coverage.log")


def archive_evidence(output):
    metadata = json.loads((output / "evidence/build.json").read_text())
    name = f"moonsmith-{metadata['version']}-evidence-{metadata['platform']}.tar.gz"
    make_archive(output / "evidence", output / name)
    checksums = {
        p.name: digest(p.read_bytes()) for p in sorted(output.glob("*.tar.gz"))
    }
    (output / "SHA256SUMS").write_text(
        "".join(f"{sha}  {name}\n" for name, sha in checksums.items())
    )
    print(json.dumps(checksums, indent=2))


def registry_metadata(name, version):
    url = f"https://mooncakes.io/api/v0/manifest/{name}@{version}"
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        error.close()
        if error.code == 404:
            return None
        raise


def verify_registry_module(name, version, archive):
    with tempfile.TemporaryDirectory(prefix="moonsmith-registry-probe-") as temporary:
        root = Path(temporary) / "consumer"
        consumer(root, version, [name])
        execute(["moon", "update"], cwd=root)
        execute(["moon", "check", "--target", "native", "--deny-warn"], cwd=root)
        graph = json.loads(execute(["moon", "tree", "--json"], cwd=root).stdout)
        found = [module for module in graph["modules"] if module["name"] == name]
        if (
            len(found) != 1
            or found[0]["version"] != version
            or found[0]["source"]["kind"] != "registry"
        ):
            raise ValueError(
                f"exact registry dependency did not resolve: {name}@{version}"
            )
        with zipfile.ZipFile(archive) as package:
            for filename in package.namelist():
                if (
                    not filename.endswith("/")
                    and package.read(filename)
                    != (root / ".mooncakes" / name / filename).read_bytes()
                ):
                    raise ValueError(f"published content differs: {name}/{filename}")


def publish(output, tag):
    metadata = preflight(tag)
    version = metadata["version"]
    packages = package_modules(output, version)
    existing = {
        name: registry_metadata(name, version) is not None for name in MODULES.values()
    }
    for folder, name in MODULES.items():
        if existing[name]:
            verify_registry_module(name, version, packages[folder])
    credential = (
        Path(os.environ.get("MOON_HOME", str(Path.home() / ".moon")))
        / "credentials.json"
    )
    secret = os.environ.get("MOONCAKES_CREDENTIALS", "")
    if not secret:
        raise ValueError("MOONCAKES_CREDENTIALS is required")
    json.loads(secret)
    descriptor = os.open(credential, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(secret)
        for folder, name in MODULES.items():
            if not existing[name]:
                with tempfile.TemporaryDirectory(
                    prefix="moonsmith-publish-"
                ) as temporary:
                    root = Path(temporary)
                    with zipfile.ZipFile(packages[folder]) as package:
                        package.extractall(root)
                    execute(["moon", "update"], cwd=root)
                    execute(
                        ["moon", "publish"],
                        cwd=root,
                        log=output / "evidence" / f"publish-{folder}.log",
                    )
                for attempt in range(12):
                    if registry_metadata(name, version) is not None:
                        break
                    if attempt == 11:
                        raise ValueError(
                            f"published module is not visible: {name}@{version}"
                        )
                    time.sleep(5)
            verify_registry_module(name, version, packages[folder])
            print(f"Verified published module {name}@{version}", flush=True)
    finally:
        credential.unlink()


def registry_validation(output):
    version = validate_versions()
    with tempfile.TemporaryDirectory(prefix="moonsmith-registry-") as temporary:
        root = Path(temporary)
        consumer(root / "consumer", version)
        execute(["moon", "update"], cwd=root / "consumer")
        execute(
            ["moon", "-C", "consumer", "run", ".", "--target", "native", "--deny-warn"],
            cwd=root,
            log=output / "library-consumer.log",
        )
        graph = json.loads(
            execute(["moon", "-C", "consumer", "tree", "--json"], cwd=root).stdout
        )
        for name in list(MODULES.values())[:3]:
            modules = [module for module in graph["modules"] if module["name"] == name]
            if (
                len(modules) != 1
                or modules[0]["version"] != version
                or modules[0]["source"]["kind"] != "registry"
            ):
                raise ValueError(
                    f"library did not resolve from the exact registry release: {name}"
                )
        execute(
            [
                "moon",
                "install",
                f"zrr1999/moonsmith/cmd/moonsmith@{version}",
                "--bin",
                str(root / "bin"),
            ],
            cwd=root,
            log=output / "cli-install.log",
        )
        validate_binary(root / "bin/moonsmith", output / "installed-cli")
        write_json(
            output / "registry.json",
            {
                "version": version,
                "commit": execute(["git", "rev-parse", "HEAD"]).stdout.strip(),
                "platform": platform_name(),
                "dependencies": graph,
            },
        )
    make_archive(
        output, output.parent / f"moonsmith-{version}-registry-{platform_name()}.tar.gz"
    )


def verify_download(directory):
    verified = set()
    for line in (directory / "SHA256SUMS").read_text().splitlines():
        sha, name = line.split("  ", 1)
        if (
            Path(name).name != name
            or name in verified
            or digest((directory / name).read_bytes()) != sha
        ):
            raise ValueError("downloaded release checksum mismatch")
        verify_archive(directory / name)
        verified.add(name)
    if verified != {path.name for path in directory.glob("*.tar.gz")}:
        raise ValueError("downloaded release inventory does not match checksums")
    version = validate_versions()
    with tempfile.TemporaryDirectory(prefix="moonsmith-downloaded-") as temporary:
        root = Path(temporary)
        binary_archive = directory / f"moonsmith-{version}-{platform_name()}.tar.gz"
        evidence_archive = (
            directory / f"moonsmith-{version}-evidence-{platform_name()}.tar.gz"
        )
        with tarfile.open(binary_archive) as archive:
            archive.extractall(root / "binary", filter="data")
        with tarfile.open(evidence_archive) as archive:
            archive.extractall(root / "evidence", filter="data")
        groups = list(
            (root / "evidence/installed-cli/equivalent-relocated/cases").glob(
                "case-*/groups/group-*"
            )
        )
        if not groups:
            raise ValueError(
                "downloaded evidence is missing whole-group replay material"
            )
        execute(
            [str(root / "binary/moonsmith"), "replay", str(groups[0])],
            cwd=root,
            log=directory / "download-replay.log",
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=[
            "preflight",
            "prepare",
            "historical",
            "archive",
            "publish",
            "verify-registry",
            "verify-archive",
            "verify-download",
        ],
    )
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/release")
    parser.add_argument("--tag")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if args.command == "preflight":
        print(json.dumps(preflight(args.tag), indent=2))
    elif args.command == "prepare":
        prepare(output, args.full)
    elif args.command == "historical":
        historical(output)
    elif args.command == "archive":
        archive_evidence(output)
    elif args.command == "publish":
        if not args.tag:
            parser.error("publish requires --tag")
        publish(output, args.tag)
    elif args.command == "verify-registry":
        registry_validation(output)
    elif args.command == "verify-download":
        verify_download(output)
    else:
        if args.archive is None:
            parser.error("verify-archive requires --archive")
        verify_archive(args.archive)


if __name__ == "__main__":
    main()
