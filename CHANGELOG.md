# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-02

### Added

- `podman-version` output on Linux reporting the installed Podman version ([#37], [#39])

### Fixed

- Install Podman from runner's native Ubuntu repositories instead of external sources ([#33])

### Changed

- Removed openSUSE Kubic references from documentation ([#38])
- License changed from Apache-2.0 to MIT to match organization convention
- CODEOWNERS updated to `@redhat-actions/maintainers`

### CI

- Bumped `fetch-latest-podman-version-windows` sub-action reference ([#35])
- Updated fetch action version in tests ([#32])

## [1.0.0] - 2026-07-23

First stable release.

### Added

- Cross-platform Podman installation for Linux (x86_64 and ARM) and Windows runners
- Linux installation from Ubuntu distribution repositories: `questing` (default), `resolute`, `noble` ([#15], [#18])
- Linux installation from openSUSE Kubic repository with configurable Ubuntu version
- `allow-upgrade` input to permit Ubuntu system upgrades when required by repository dependencies ([#18])
- Windows MSI installer support with `latest` or pinned version ([#12])
- `install-scope` input for Windows: `user` (no admin required) or `machine` scope ([#12])
- `github-token` input to avoid GitHub API rate limiting on Windows ([#9])
- `start-service` input to start `podman.socket` after installation on Linux ([#19], [#28])
- Sub-action at `.github/actions/fetch-latest-podman-version-windows` for resolving Podman download URLs without installing ([#5], [#24])
- Nightly CI artifact URL resolution for Windows via the sub-action ([#24], [#26])
- CI test workflow validating the action on x86_64 Linux, ARM Linux, and Windows ([#27], [#28])
- Dependabot configuration for GitHub Actions version monitoring ([#27])

### Fixed

- Podman PATH now persists to subsequent workflow steps on Windows via `GITHUB_PATH` ([#27])
- Composite action step name uses correct `inputs` context instead of `github.event.inputs` ([#27])
- Kubic installation step now has `set -euo pipefail` error handling ([#27])
- CRIU package download uses `dpkg --print-architecture` instead of hardcoded `amd64`, enabling ARM runner support ([#14], [#28])
- Sub-action SHA reference kept current with latest fixes ([#22], [#27])
- Podman org updated to `podman-container-tools/podman` ([#20])
- Curl calls use follow-redirects flag ([#22])

### Changed

- Release workflow uses `gh release create` instead of archived `actions/create-release` ([#27])
- Default workflow permissions set to read-only (least privilege) ([#27])
- `actions/checkout` upgraded to v7 to resolve node20 deprecation warnings ([#27])
- Nightly sub-action returns `download_url` instead of downloading artifacts locally; `local_installer_path` output removed ([#26])

[1.1.0]: https://github.com/redhat-actions/podman-install/releases/tag/v1.1.0
[1.0.0]: https://github.com/redhat-actions/podman-install/releases/tag/v1.0.0

[#5]: https://github.com/redhat-actions/podman-install/pull/5
[#9]: https://github.com/redhat-actions/podman-install/pull/9
[#12]: https://github.com/redhat-actions/podman-install/pull/12
[#14]: https://github.com/redhat-actions/podman-install/issues/14
[#15]: https://github.com/redhat-actions/podman-install/pull/15
[#18]: https://github.com/redhat-actions/podman-install/pull/18
[#19]: https://github.com/redhat-actions/podman-install/issues/19
[#20]: https://github.com/redhat-actions/podman-install/pull/20
[#22]: https://github.com/redhat-actions/podman-install/pull/22
[#24]: https://github.com/redhat-actions/podman-install/pull/24
[#26]: https://github.com/redhat-actions/podman-install/pull/26
[#27]: https://github.com/redhat-actions/podman-install/pull/27
[#28]: https://github.com/redhat-actions/podman-install/pull/28
[#32]: https://github.com/redhat-actions/podman-install/pull/32
[#33]: https://github.com/redhat-actions/podman-install/pull/33
[#35]: https://github.com/redhat-actions/podman-install/pull/35
[#37]: https://github.com/redhat-actions/podman-install/pull/37
[#38]: https://github.com/redhat-actions/podman-install/pull/38
[#39]: https://github.com/redhat-actions/podman-install/pull/39
