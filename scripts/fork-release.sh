#!/usr/bin/env bash
# Release a build of this fork as an installable package commit (FORK.md, Releasing).
#
#   scripts/fork-release.sh <version> [--push]
#
# <version> is the upstream release the fork builds on plus `-fe.<n>`, such as 1.0.0-fe.1. The script runs the checks,
# packs the package as npm would, and commits the packed files alone, with `dist/` built and no lifecycle scripts, on the
# `release` branch. The commit's parents are the previous release and the source commit, so the source stays reachable
# for as long as the release does. It tags the commit `v<version>`, and with --push pushes the branch and the tag.
set -euo pipefail

version="${1:-}"
push="${2:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-fe\.[0-9]+$ ]]; then
  echo "usage: scripts/fork-release.sh <upstream version>-fe.<n> [--push]" >&2
  exit 2
fi
if [[ -n "$push" && "$push" != "--push" ]]; then
  echo "unknown argument: $push" >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel)"
cd "$root"
tag="v$version"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "the work tree has changes: release from a clean checkout" >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "tag $tag exists already" >&2
  exit 1
fi
source_commit="$(git rev-parse HEAD)"

bun install --frozen-lockfile
bun test --parallel
bun run check
bun run package-smoke-test

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
# npm pack runs prepack, which builds dist/ from src/ with the locked TypeScript.
npm pack --silent --pack-destination "$scratch" >/dev/null
tar -xzf "$scratch"/*.tgz -C "$scratch"
package="$scratch/package"

# The released manifest: the version, the source commit, and no scripts or development tools, so installing the
# release from git runs nothing.
VERSION="$version" SOURCE="$source_commit" node -e '
  const fs = require("node:fs")
  const file = process.argv[1]
  const manifest = JSON.parse(fs.readFileSync(file, "utf8"))
  manifest.version = process.env.VERSION
  manifest.repository = { type: "git", url: "git+https://github.com/FlamboyantEngineer/pretext.git" }
  manifest.forkSource = process.env.SOURCE
  delete manifest.scripts
  delete manifest.devDependencies
  fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + "\n")
' "$package/package.json"

index="$scratch/index"
GIT_INDEX_FILE="$index" git --work-tree="$package" add -A -f .
tree="$(GIT_INDEX_FILE="$index" git write-tree)"
parents=()
if git ls-remote --exit-code --heads origin release >/dev/null; then
  git fetch -q origin release
  parents+=(-p "$(git rev-parse FETCH_HEAD)")
elif git rev-parse -q --verify refs/heads/release >/dev/null; then
  parents+=(-p "$(git rev-parse refs/heads/release)")
fi
parents+=(-p "$source_commit")
release_commit="$(git commit-tree "$tree" "${parents[@]}" -m "Release $version

Built from $source_commit.")"
git update-ref refs/heads/release "$release_commit"
git tag -a "$tag" -m "Pretext $version, built from $source_commit" "$release_commit"

echo "release $version: $release_commit (tag $tag), built from $source_commit"
echo "pin: \"@chenglou/pretext\": \"github:FlamboyantEngineer/pretext#$release_commit\""
if [[ "$push" == "--push" ]]; then
  git push origin refs/heads/release "refs/tags/$tag"
fi
