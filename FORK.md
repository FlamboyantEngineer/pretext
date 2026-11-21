# This fork

`FlamboyantEngineer/pretext` is a fork of [chenglou/pretext](https://github.com/chenglou/pretext). Its fixes land here
first and are offered upstream afterwards. Everything else in this repository is upstream's and is documented there.

## Branches and tags

- `main`: upstream's `main` plus the fork's fixes, each merged by pull request. Upstream is merged into it, never
  rebased under it.
- `release`: one commit per release, holding only the packed package (`package.json`, `dist/`, `src/`, the readme,
  licence and changelog), built, with no lifecycle scripts and no development dependencies. Each release commit's parents
  are the previous release and the `main` commit it was built from, so that source stays reachable.
- `v<version>`: an annotated tag on each release commit. Tags are never moved or deleted.

A version is upstream's last release plus `-fe.<n>`, counting the fork's releases on that upstream release: `1.0.0-fe.1`,
`1.0.0-fe.2`, then `1.1.0-fe.1` once `main` holds upstream's 1.1.0.

## Checks

`.github/workflows/fork-check.yml` runs `bun test --parallel`, `bun run check` and `bun run package-smoke-test` on every
pull request and on `main`. Upstream's demo-site workflow (`pages.yml`) runs only in upstream's repository.

## Installing a release

Pin the release commit, not the tag or a branch, so the lockfile and the installed bytes can't move:

```json
"@chenglou/pretext": "github:FlamboyantEngineer/pretext#<release commit>"
```

The package name stays `@chenglou/pretext`, so imports don't change. Because the release commit has no `prepare` or
`prepack` script, npm installs its files as they are: it builds nothing and installs none of the fork's development
tools. The installed `package.json` names the version and, under `forkSource`, the `main` commit it was built from.

## Releasing

From a clean checkout of `main` at the commit to release, with Bun and Node installed:

1. Add the release to the Fork releases section below: its version, what it changes for an app, and the pull requests.
   Commit that to `main` by pull request.
2. Run `scripts/fork-release.sh <version>`. It installs the locked tools, runs `bun test --parallel`, `bun run check`
   and `bun run package-smoke-test`, packs the package (`prepack` builds `dist/`), commits the packed files on `release`
   and tags the commit. It prints the release commit and the pin line.
3. Look at the release commit (`git show --stat release`), then run `scripts/fork-release.sh` again with `--push`, or
   push it yourself: `git push origin release v<version>`.
4. Check the install in an empty folder: `npm install github:FlamboyantEngineer/pretext#<release commit>` must run no
   script and give `dist/layout.js` and `dist/rich-inline.js`.
5. Bump the pins of the projects that use the fork.

The browser harness (`bun harness`) runs on macOS with pinned browser copies (`harness/README.md`, Setup). A fork
change that can't be run there says so in its pull request and gives the evidence it has instead: `bun test`, the
offline invariants and comparison (`bun harness equal main --offline`) and measurements in Chromium.

## Fork releases

### 1.0.0-fe.1

Upstream `main` at 6ed1edd (1.0.0 and its Unreleased changes), released as a built package so installing it runs no
build.

### 1.0.0-fe.2

Line breaking in Chromium matches Chrome more closely, and the engine inputs can be fixed by the app:

- `setEngine(engine)` gives a named engine's whole profile, for an app that must break lines the same way on every
  machine or in a worker (#3). The readme's "Fonts in a worker" recipe registers the served fonts there.
- Kerning with spaces: a word's kerning against a following space stays on the word, unless `accurateLineEnds` (an
  option and a rich-inline item field) asks for Chrome's placement under justified or centred text and on decorated
  items. Same-font rich-inline items kern across their edges as Chrome shapes them as one run (#4).
- Fit arithmetic: a line fits within one layout unit of the width truncated to units, as in Chrome, and
  `setLayoutScale(scale)` gives the device pixel ratio those units count in. Chrome's rounding of each item's piece of
  a line is not ported yet (#5).

### 1.0.0-fe.3

`setMeasureContext(create)` lets the app make the Canvas contexts Pretext measures through, for example under
`textRendering = 'geometricPrecision'`, without which Chrome's Linux headless shell measures hinted whole-pixel widths
(#6).

### 1.0.0-fe.4

`extraWidthEnd`, a rich-inline item field, gives the end side of the item's `extraWidth`. Chrome fits a line that ends
inside a padded `box-decoration-break: clone` span without the span's cloned end edge, so the Chromium profile now does
too; a line the span ends on still fits both edges (#7).
