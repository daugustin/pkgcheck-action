# pkgcheck-action

Run [pkgcheck](https://github.com/pkgcore/pkgcheck) over a Gentoo ebuild
repository in GitHub Actions.

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0
- uses: daugustin/pkgcheck-action@v2
```

pkgcheck is installed with pip into a venv on the runner — there is no container
and no image to pull. The gentoo tree is synced at runtime and cached; a warm
run is around 45 seconds end to end.

> [!IMPORTANT]
> **`fetch-depth: 0` is not optional** for `scope: commits` (which is what
> `scope: auto` selects on pull requests). `actions/checkout` defaults to a
> depth of 1, and pkgcheck cannot diff against a base ref that was never
> fetched. This is the most common way to misconfigure this action.

## Inputs

| Input | Default | Description |
|---|---|---|
| `pkgcheck-version` | `0.10.44` | Exact version to install. Empty means whatever pip resolves. |
| `python-version` | `3.12` | Python used for the pkgcheck venv. |
| `working-directory` | `.` | Path to the ebuild repository. |
| `scope` | `auto` | `auto`, `all`, `commits` or `staged`. |
| `base-ref` | PR base branch | Tree-ish to diff against for `commits`. |
| `keywords` | — | Passed to `pkgcheck scan -k`, e.g. `-RedundantVersion`. |
| `exit-on` | `GentooCI` | What makes the action fail. Empty to always pass. |
| `net` | `false` | Enable pkgcheck's network checks. |
| `cache` | `true` | Cache the gentoo tree and pkgcheck metadata. |
| `on-unsupported-eapi` | `error` | `error`, `warn` or `ignore` — see below. |

`scope: auto` scans the commits in the pull request on `pull_request` events and
the whole repository otherwise.

`exit-on` is **not** a severity filter. It takes checksets, checks or keywords,
and the default `GentooCI` checkset includes warning-level keywords such as
`BadWhitespaceCharacter`. A result's severity and whether it fails your build
are two independent things.

## Outputs

| Output | Description |
|---|---|
| `results-json` | Path to the results, one JSON object per line (`JsonStream`). |
| `result-count` | Total results. |
| `error-count` | Error-level results. |
| `warning-count` | Warning-level results. |
| `exit-code` | pkgcheck's exit code, before the action fails the job. |
| `pkgcheck-version` | The version actually installed. |

## EAPI 9 needs bash 5.3

pkgcore refuses to enable an EAPI whose bash requirement the host does not meet,
and **`ubuntu-latest` is still Ubuntu 24.04 with bash 5.2**. On such a runner,
an overlay containing EAPI 9 ebuilds does not merely get mis-reported: metadata
regeneration fails outright, and the scan then reports `InvalidEapi` — an
error-level keyword in the `GentooCI` checkset — against perfectly valid
ebuilds.

This action checks for that before it bites and stops with an explanation
naming the offending ebuilds. To fix it, run on a host with a newer bash:

```yaml
jobs:
  qa:
    runs-on: ubuntu-26.04   # ships bash 5.3
```

If your overlay has no EAPI 9 ebuilds, this never triggers and `ubuntu-latest`
is fine. Set `on-unsupported-eapi: warn` to scan anyway and accept that results
for those ebuilds will be wrong.

## Examples

Scan everything on a schedule, including network checks:

```yaml
- uses: daugustin/pkgcheck-action@v2
  with:
    scope: all
    net: true
```

Report findings without failing the build:

```yaml
- uses: daugustin/pkgcheck-action@v2
  id: pkgcheck
  with:
    exit-on: ""
- run: echo "${{ steps.pkgcheck.outputs.error-count }} errors"
```

Ignore a keyword you disagree with:

```yaml
- uses: daugustin/pkgcheck-action@v2
  with:
    keywords: "-RedundantVersion,-VariableOrderWrong"
```

## Relationship to upstream

[`pkgcore/pkgcheck-action`](https://github.com/pkgcore/pkgcheck-action) is the
official action and works well. It runs `pkgcheck ci` in a container and prints
the log. This one exists to attach findings to the files they belong to —
inline pull request annotations and SARIF for code scanning — which needs the
machine-readable result stream rather than formatted log output, and needs the
scan to run as the runner user rather than as root inside a container.

If you only want the log, prefer upstream.

## Versioning

`v1` was a Docker action built on a Gentoo stage3 image. `v2` is a composite
action and is a breaking change; `v1` is unchanged and unmaintained.
