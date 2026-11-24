# podman-install

This composite action installs Podman on GitHub-hosted runners for both Linux (Ubuntu) and Windows. It's designed to be a simple, one-stop solution for setting up Podman in your CI workflows.

## Features

The action is cross-platform, working for both Ubuntu and Windows runners (including ARM).

On **Windows**, it uses the official Podman MSI installer, automatically fetching the latest version. You can specify a specific Podman version if your CI needs to be pinned. After installation, the action automatically runs `podman machine init --now` to ensure the Podman machine is running and ready for use in subsequent steps.

On **Linux**, Ubuntu 24.04 installs Podman v5.x and its dependencies from Ubuntu's Questing repository, with APT pinning to limit other package upgrades. Ubuntu 26.04 uses its native repository. Questing has reached end of life, so these Ubuntu 24.04 packages no longer receive updates.

The action is self-contained: it does not reference any other repository action, and only escalates privileges when it is not already running as root. That makes it usable on Gitea/Forgejo and other forges, and on self-hosted Linux runners, in addition to GitHub-hosted runners.

## Inputs

| Input | Platform | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `start-service` | Linux | no | `false` | Start the Podman socket service (`systemctl --user start podman.socket`) after installation |
| `podman-version-input` | Windows | no | `latest` | Podman version: `latest` or a specific version (e.g. `5.6.2`) |
| `install-scope` | Windows | no | `user` | MSI installation scope: `user` (no admin required) or `machine` (requires admin) |
| `github-token` | Windows | no | -- | GitHub token for authenticated API requests (avoids rate limiting) |

## Outputs

| Output | Description |
| --- | --- |
| `podman-version` | Resolved version (e.g. `5.8.4`) 

## Usage

### Basic Usage

```yaml
- name: Install Podman
  uses: redhat-actions/podman-install@v1
```

### With GitHub Token (Recommended for Windows)

```yaml
- name: Install Podman
  uses: redhat-actions/podman-install@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Install Specific Podman Version on Windows

```yaml
- name: Install Podman 5.6.2
  uses: redhat-actions/podman-install@v1
  with:
    podman-version-input: '5.6.2'
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Install Podman and Start the Socket Service (Linux)

```yaml
- name: Install Podman with socket service
  uses: redhat-actions/podman-install@v1
  with:
    start-service: 'true'
```

## Sub-action: Fetch Podman Version for Windows

The composite sub-action at `.github/actions/fetch-latest-podman-version-windows` resolves a Podman Windows installer download URL without installing it. Use it when your workflow needs the URL -- for example, to download and install Podman on a remote Windows host.

The main `podman-install` action runs the same `fetch.sh` script internally on Windows runners rather than referencing this sub-action with `uses:`. It currently passes through `latest` or a specific release version only. To consume nightly CI builds, call the sub-action directly (see examples below).

### Version resolution

| `version_input` | Source | Primary output |
| --- | --- | --- |
| `latest` | [podman-container-tools/podman](https://github.com/podman-container-tools/podman) GitHub Release | `download_url` (public MSI/asset URL) |
| `v5.6.1` / `5.6.1` | Same, pinned tag | `download_url` (public MSI/asset URL) |
| `https://...` | URL used as-is (validated for CR/LF) | `download_url` |
| `nightly` / `main` | Latest successful [release-pipeline-validation.yml](https://github.com/podman-container-tools/podman/actions/workflows/release-pipeline-validation.yml) run; artifact `win-msi-<arch>-main-<sha>` | `download_url` (Actions artifact archive URL) |

`file_type` applies to release downloads only. Nightly resolution always targets the MSI CI artifact (`win-msi-<arch>-main-<sha>`).

The published Windows assets vary by release: 4.x and early 5.x only ship `podman-<version>-setup.exe`, 5.6.x also publishes an `.exe` installer, and current releases only publish the `.msi`. If the requested `file_type` is not available for a version, the sub-action falls back to the other installer assets, so pinned versions resolve whenever the release has any Windows installer. `remote.zip` has no equivalent and is not retried.

Release assets are public download URLs. Nightly `download_url` is the GitHub Actions [`archive_download_url`](https://docs.github.com/en/rest/actions/artifacts#get-an-artifact) for the matching artifact (a zip archive containing the MSI). Downloading that URL requires an authenticated request with a token that has `actions: read` on `podman-container-tools/podman`.

### Requirements for nightly

- `github_token` must be provided (typically `${{ secrets.GITHUB_TOKEN }}`, or a PAT with access to the Podman repo artifacts)
- The workflow job needs `permissions.actions: read`
- The runner must have `gh` and `jq` available (pre-installed on `ubuntu-latest` and `windows-latest`)

### Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `version_input` | yes | `latest` | Version selector (see table above) |
| `architecture` | no | `amd64` | Windows architecture: `amd64` or `arm64` |
| `file_type` | no | `msi` | Preferred release asset type: `msi`, `setup.exe`, `installer.exe`, or `remote.zip`; falls back to another installer when this type is not published for the release |
| `github_token` | no* | -- | GitHub token; *required for nightly |

### Outputs

| Output | Description |
| --- | --- |
| `version` | Resolved version (e.g. `v5.6.1` or `main-696772b`) |
| `download_url` | Installer download URL (public release asset, or authenticated Actions artifact archive for nightly) |
| `is_latest` | `true` when `version_input` was `latest` |
| `is_nightly` | `true` when a CI nightly artifact URL was resolved |

### Fetch latest stable release

```yaml
permissions:
  contents: read

steps:
  - id: fetch-podman
    uses: redhat-actions/podman-install/.github/actions/fetch-latest-podman-version-windows@v1
    with:
      version_input: latest
      file_type: msi
      github_token: ${{ secrets.GITHUB_TOKEN }}

  - run: curl -LO '${{ steps.fetch-podman.outputs.download_url }}'
```

### Fetch a specific release

```yaml
  - id: fetch-podman
    uses: redhat-actions/podman-install/.github/actions/fetch-latest-podman-version-windows@v1
    with:
      version_input: v5.6.1
      architecture: amd64
      file_type: msi
```

### Fetch nightly CI build

```yaml
permissions:
  contents: read
  actions: read

steps:
  - id: fetch-podman
    uses: redhat-actions/podman-install/.github/actions/fetch-latest-podman-version-windows@v1
    with:
      version_input: nightly
      architecture: amd64
      github_token: ${{ secrets.GITHUB_TOKEN }}

  - run: |
      echo "version=${{ steps.fetch-podman.outputs.version }}"
      curl -L -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
        -o podman-nightly.zip \
        '${{ steps.fetch-podman.outputs.download_url }}'
      unzip -qo podman-nightly.zip
```

## Versioning

`@v1` tracks the latest stable 1.x release; the tag is moved automatically when a stable `vX.Y.Z` tag is pushed. Pin a full version tag or a commit SHA in production workflows for reproducible runs.
