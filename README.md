# podman-install

This composite action installs Podman on GitHub-hosted runners for both Linux (Ubuntu) and Windows. It's designed to be a simple, one-stop solution for setting up Podman in your CI workflows.

## Features

The action is cross-platform, working for both ubuntu-latest and windows-latest runners.

On Windows, it uses the official Podman MSI installer, automatically fetching the latest version. You can specify a specific Podman version if your CI needs to be pinned. After installation, the action automatically runs podman machine init --now to ensure the Podman machine is running and ready for use in subsequent steps.

On Linux, the action installs Podman v5.x and its key dependencies (like CRIU) from the openSUSE Kubic repository or from another Ubuntu distros, ensuring you get more modern version into GH runners.

### Inputs

This action accepts three inputs to customize its behavior:

**podman-version-input**: This input is used only on Windows runners. You can set it to 'latest' (which is the default) to automatically install the most recent Podman release, or provide a specific version string (e.g., '5.6.2') to install that exact version.

**ubuntu-version**: This input is used only on Linux runners. It specifies the Ubuntu version codename (like '23.10' or '22.04') needed to construct the correct URL for the Kubic repository. The default value is '23.10'.

**ubuntu-repository**: This input is used only on Linux. It offers new option how to install a podman. With the parameter, the particular repositories can be used to install podman and its dependencies. The input is a choice type and it offers to choose from `questing` (default), `resolute`, `noble` or `kubic` repository. If `kubic` is used, then installation will also consider *ubuntu-version* input parameter and use Kubic repositories. Note: If `resolute` is picked up, it will lead to a system upgrade due to incompatible `libc6` library dependency between distros.

**github-token**: (Optional) A GitHub token used to make authenticated API requests when fetching the latest Podman version on Windows. Providing this token helps avoid GitHub API rate limiting, especially in workflows that run frequently. If not provided, the action will make unauthenticated requests which are subject to stricter rate limits. Example: `github-token: ${{ secrets.GITHUB_TOKEN }}`.

## Usage

### Basic Usage

```yaml
- name: Install Podman
  uses: redhat-actions/podman-install@main
```

### With GitHub Token (Recommended for Windows)

```yaml
- name: Install Podman
  uses: redhat-actions/podman-install@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Install Specific Podman Version on Windows

```yaml
- name: Install Podman 5.6.2
  uses: redhat-actions/podman-install@main
  with:
    podman-version-input: '5.6.2'
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Install Podman 5.2.5 on Ubuntu from Kubic repositories 23.10
```yaml
# Use kubic repository 23.10 (contains podman 5.2.5)
- name: Install Podman on Ubuntu 24.04 from Kubic
  uses: redhat-actions/podman-install@main
  with:
    ubuntu-version: '23.10'
    ubuntu-repository: 'kubic'
```

### Install Podman 5.4.2 on Ubuntu from Questing distribution repository
```yaml
# Use kubic repository 23.10 (contains podman 5.2.5)
- name: Install Podman on Ubuntu from Questing repository
  uses: redhat-actions/podman-install@main
  with:
    ubuntu-repository: 'questing'
```

## Sub-action: Fetch Podman Version for Windows

The composite sub-action at `.github/actions/fetch-latest-podman-version-windows` resolves a Podman Windows installer download URL without installing it. Use it when your workflow needs the URL—for example, to download and install Podman on a remote Windows host.

The main `podman-install` action uses this sub-action internally on Windows runners. It currently passes through `latest` or a specific release version only. To consume nightly CI builds, call the sub-action directly (see examples below).

### Version resolution

| `version_input` | Source | Primary output |
| --- | --- | --- |
| `latest` | [podman-container-tools/podman](https://github.com/podman-container-tools/podman) GitHub Release | `download_url` (public MSI/asset URL) |
| `v5.6.1` / `5.6.1` | Same, pinned tag | `download_url` (public MSI/asset URL) |
| `https://…` | URL used as-is (validated for CR/LF) | `download_url` |
| `nightly` / `main` | Latest successful [release-pipeline-validation.yml](https://github.com/podman-container-tools/podman/actions/workflows/release-pipeline-validation.yml) run; artifact `win-msi-<arch>-main-<sha>` | `download_url` (Actions artifact archive URL) |

`file_type` applies to release downloads only. Nightly resolution always targets the MSI CI artifact (`win-msi-<arch>-main-<sha>`).

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
| `file_type` | no | `msi` | Release asset type: `msi`, `setup.exe`, `installer.exe`, or `remote.zip` |
| `github_token` | no* | — | GitHub token; *required for nightly |

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
    uses: redhat-actions/podman-install/.github/actions/fetch-latest-podman-version-windows@main
    with:
      version_input: latest
      file_type: msi
      github_token: ${{ secrets.GITHUB_TOKEN }}

  - run: curl -LO '${{ steps.fetch-podman.outputs.download_url }}'
```

### Fetch a specific release

```yaml
  - id: fetch-podman
    uses: redhat-actions/podman-install/.github/actions/fetch-latest-podman-version-windows@main
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
    uses: redhat-actions/podman-install/.github/actions/fetch-latest-podman-version-windows@main
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

Pin the sub-action to a commit SHA instead of `@main` in production workflows.