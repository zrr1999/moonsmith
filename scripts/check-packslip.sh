#!/usr/bin/env bash
set -euo pipefail

directory=${1:?usage: check-packslip.sh /path/to/binary-artifacts}
shopt -s nullglob
archives=("$directory"/moonsmith-*-linux-x86_64.tar.gz "$directory"/moonsmith-*-macos-arm64.tar.gz)
test "${#archives[@]}" -eq 2
version=$(tar -xzOf "${archives[0]}" build.json | jq -er .version)
commit=$(tar -xzOf "${archives[0]}" build.json | jq -er .commit)
for archive in "${archives[@]}"; do
  tar -xzOf "$archive" build.json |
    jq -e --arg version "$version" --arg commit "$commit" '.version == $version and .commit == $commit'
done

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
packslip keygen --out "$temporary/release.key"
packslip create --project github.com/zrr1999/moonsmith --version "$version" \
  --source-repo https://github.com/zrr1999/moonsmith --tag "v$version" --commit "$commit" \
  --url-base "https://github.com/zrr1999/moonsmith/releases/download/v$version" \
  --bin moonsmith --require bin:moon --key "$temporary/release.key" --no-log \
  --out "$temporary" "${archives[@]}"
bundle="$temporary/packslip.sigstore.json"
packslip show "$bundle" | jq -e --arg version "$version" --arg commit "$commit" '
  .predicate.project == "github.com/zrr1999/moonsmith" and
  .predicate.version == $version and .predicate.source.commit == $commit and
  ([.predicate.artifacts[] | [.os, .arch]] | sort) == [["darwin", "aarch64"], ["linux", "x86_64"]] and
  all(.predicate.artifacts[]; .bin == ["moonsmith"] and .format == "tar.gz")
'
for archive in "${archives[@]}"; do
  packslip verify "$bundle" --pubkey "$temporary/release.pub" --allow-unlogged --artifact "$archive"
done

packslip keygen --out "$temporary/other.key"
if packslip verify "$bundle" --pubkey "$temporary/other.pub" --allow-unlogged > "$temporary/wrong-key.log" 2>&1; then
  echo "verification accepted the wrong signing key" >&2
  exit 1
fi
tampered="$temporary/${archives[0]##*/}"
cp "${archives[0]}" "$tampered"
printf x >> "$tampered"
if packslip verify "$bundle" --pubkey "$temporary/release.pub" --allow-unlogged \
  --artifact "$tampered" > "$temporary/tampered.log" 2>&1; then
  echo "verification accepted a modified archive" >&2
  exit 1
fi
echo "Release metadata, archive verification, wrong-key rejection and tamper rejection passed."
