# AGENTS.md

Guidance for coding agents working in this repository.

## What this is

A composite GitHub Action that installs Podman on Ubuntu and Windows runners. There is no application build, package manifest, or test framework: `action.yml` and the scripts under `.github/` are the product, and the CI workflows are the test suite.

## Layout

| Path | Purpose |
| --- | --- |
| `action.yml` | The composite action: Linux install, Windows URL lookup, Windows install, machine init |
| `.github/actions/fetch-latest-podman-version-windows/action.yml` | Standalone sub-action that resolves a Windows installer URL |
| `.github/actions/fetch-latest-podman-version-windows/fetch.sh` | Shared lookup logic; called by both actions |
| `.github/workflows/ci.yml` | Linux (24.04, 26.04, ARM, 22.04, root container), Windows and sub-action tests |
| `.github/workflows/create-release.yml` | Creates a `commit-<sha>` pre-release on every push to `main` |
| `.github/workflows/update-major-tag.yml` | Moves the floating `v1` tag when a stable `vX.Y.Z` tag is pushed |
| `README.md` | User-facing docs; every input and output is documented here |
| `CHANGELOG.md` | Keep a Changelog format, released sections plus `[Unreleased]` |

## Invariants

These have caused real regressions. Keep them intact unless the change is explicitly about them.

- **No nested `uses:` for actions in this repo.** `action.yml` calls `fetch.sh` with `${{ github.action_path }}` instead of `uses: ./.github/actions/...`. GitHub resolves local `uses:` through `owner/repo`, but Gitea/Forgejo resolve it against their own instance, so a nested reference breaks non-GitHub forges. It also cannot be made forge-conditional: `uses:` accepts only `owner/repo[/path]@ref`, `./path`, or `docker://`, and takes no expressions.
- **Escalate privileges through `as_root`.** It runs the command directly when `EUID` is 0, uses `sudo` when available, and fails clearly otherwise. Never call `sudo` directly: rootful containers and self-hosted runners may not have it.
- **Do not require GNU `time`.** The Linux step uses bash's `time` builtin with `TIMEFORMAT`; `/bin/time` does not exist on every distribution.
- **Keep the Linux step portable to old bash.** It can run on self-hosted and forge runners, so target bash 4.2 (the oldest likely runner, e.g. CentOS 7): do not use features added later (namerefs, `wait -n`), and never expand an empty array under `set -u` (fixed in bash 4.4). `fetch.sh` is allowed slightly newer bash, but stays compatible anyway.
- **Windows steps use `shell: bash` (Git Bash) for the lookup and `pwsh` for installation.** `github.action_path` is used to locate `fetch.sh`; do not rely on the working directory.
- **The main action and the sub-action share `fetch.sh`.** Change the logic once, in that file; do not copy it into `action.yml`.

## Making changes

- Use conventional commit subjects (`fix:`, `feat:`, `ci:`, `chore:`, `docs:`) with a scope when it helps (`fix(windows):`). Explain the *why* in the body.
- Keep PRs focused, and follow the existing style in the file you are editing: two-space YAML indent, `set -euo pipefail` in bash steps, quoted variables, and the Apache-2.0 SPDX header at the top of new workflow and script files.
- Add new files under `.github/` rather than at the repository root unless they are user-facing documentation.
- Pass action inputs to shell steps through `env:` rather than interpolating `${{ inputs.* }}` directly into the script.

## Validating

`actionlint` is not vendored. Install it with `go install github.com/rhysd/actionlint/cmd/actionlint@latest` or from its releases, then:

```bash
actionlint
shellcheck .github/actions/fetch-latest-podman-version-windows/fetch.sh
bash -n .github/actions/fetch-latest-podman-version-windows/fetch.sh
```

Notes:

- `actionlint` checks the workflows and runs `shellcheck` on their inline `run:` blocks when it is on `PATH`. It does not understand composite `action.yml` files (it reports them as malformed workflows), so shellcheck scripts directly and let CI exercise the inline action shell.
- `actionlint` may report `ubuntu-26.04` as an unknown runner label when its label database is older than the runner. The label is valid here; ignore that specific warning unless the label itself changed.
- `shellcheck` reports two pre-existing findings in `fetch.sh`: `SC2295` (info, an expansion inside `${...}` that should be quoted separately) and `SC2129` (style, separate redirects to `$GITHUB_OUTPUT`). Do not treat those as new breakage, but do not add more.
- The install logic cannot be exercised meaningfully on a workstation: it runs `apt-get` as root and then starts Podman. Test it in CI or in a disposable Ubuntu container/VM, not on your machine.
- End-to-end coverage comes from opening a PR: `ci.yml` runs the action on real Ubuntu and Windows runners. For paths CI does not cover, push a temporary workflow on a scratch branch, confirm the result, then delete the branch. Do not merge scratch workflows.
- Tag-triggered workflows run from the commit the tag points at, so a validation tag on a scratch branch exercises that branch's workflow without touching `main`.

## CI and merging

`ci.yml` must pass. The required checks on `main` are the four original jobs (`Test on Linux (ubuntu-24.04, auto)`, `ubuntu-26.04`, `ubuntu-24.04-arm`, and `Test on Windows (windows-latest)`); the root-container, 22.04 and sub-action jobs are additional signal. A review is required, and admins can merge with `--admin` when a second maintainer is unavailable.

The `ubuntu-24.04` job occasionally fails while fetching the Ubuntu Questing repository (`archive.ubuntu.com` vs `old-releases.ubuntu.com`) before any of this repository's code runs. Re-run the job before investigating; it is infrastructure, not an action bug.

## Documentation and changelog

- User-visible behaviour changes need an entry under `## [Unreleased]` in `CHANGELOG.md`, in the matching heading (`Added`, `Changed`, `Fixed`), ending with the PR reference. Add the matching link definition (`[#NN]: https://github.com/redhat-actions/podman-install/pull/NN`) at the bottom of the file.
- CI-only changes generally do not need a changelog entry.
- `README.md` is the contract: update the inputs/outputs tables and the examples whenever an input, output, default or behaviour changes.

## Releases

- Version tags are annotated `vX.Y.Z` tags. Pushing one triggers `update-major-tag.yml`, which moves the floating major tag (`v1`) to the highest stable release in that line. Never move the major tag by hand.
- `create-release.yml` creates a `commit-<sha>` pre-release on every push to `main`; that is not a version release.
- Release notes are written from the `CHANGELOG.md` section for the tag, with a `**Full Changelog**` compare link against the previous version.
