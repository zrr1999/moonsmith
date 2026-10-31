#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "moonbit-pygments",
#   "zensical==0.0.74",
# ]
#
# [tool.uv.sources]
# moonbit-pygments = { path = "../tools/moonbit-lexer" }
# ///
"""Stage docs/ and build or serve the Zensical site."""

import argparse
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import quote, unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
SOURCE = ROOT / ".artifacts/docs/source"
GITHUB = "https://github.com/zrr1999/moonsmith/blob/main/"
LINK = re.compile(r"(?<!!)\[([^\[\]]*)\]\(([^)\s]+)\)")


def stage() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    kept: set[Path] = set()
    for source in DOCS.rglob("*"):
        if not source.is_file():
            continue
        target = SOURCE / source.relative_to(DOCS)
        kept.add(target)
        content = (
            rewrite(source.read_text(), source).encode()
            if source.suffix == ".md"
            else source.read_bytes()
        )
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != content:
            target.write_bytes(content)
    for target in SOURCE.rglob("*"):
        if target.is_file() and target not in kept:
            target.unlink()


def rewrite(text: str, source: Path) -> str:
    lines = text.splitlines(keepends=True)
    rendered: list[str] = []
    fenced = False
    for line in lines:
        if line.startswith("```"):
            fenced = not fenced
            rendered.append(line)
            continue
        if fenced:
            rendered.append(line)
            continue
        rendered.append(LINK.sub(lambda match: replace_link(match, source), line))
    return "".join(rendered)


def replace_link(match: re.Match[str], source: Path) -> str:
    label, target = match.group(1), match.group(2)
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or target.startswith("#"):
        return match.group(0)
    path, _separator, fragment = target.partition("#")
    if path == "":
        return match.group(0)
    resolved = (source.parent / unquote(path)).resolve()
    repo = ROOT.resolve()
    docs = DOCS.resolve()
    if not resolved.is_relative_to(repo) or resolved.is_relative_to(docs):
        return match.group(0)
    relative = resolved.relative_to(repo).as_posix()
    url = GITHUB + "/".join(quote(part) for part in relative.split("/"))
    if fragment:
        url += "#" + fragment
    return f"[{label}]({url})"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "serve"])
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    stage()
    if args.command == "build":
        return subprocess.call(
            [sys.executable, "-m", "zensical", "build", "--clean", "--strict"],
            cwd=ROOT,
        )

    process = subprocess.Popen(
        [sys.executable, "-m", "zensical", "serve", "--dev-addr", f"127.0.0.1:{args.port}"],
        cwd=ROOT,
    )
    try:
        while process.poll() is None:
            time.sleep(0.5)
            stage()
        return process.returncode or 0
    except KeyboardInterrupt:
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait()


if __name__ == "__main__":
    raise SystemExit(main())
