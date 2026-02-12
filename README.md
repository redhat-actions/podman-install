# podman-install

This composite action installs Podman on GitHub-hosted runners for both Linux (Ubuntu) and Windows. It's designed to be a simple, one-stop solution for setting up Podman in your CI workflows.

## Features

The action is cross-platform, working for both ubuntu-latest and windows-latest runners.

On Windows, it uses the official Podman MSI installer, automatically fetching the latest version. You can specify a specific Podman version if your CI needs to be pinned. After installation, the action automatically runs podman machine init --now to ensure the Podman machine is running and ready for use in subsequent steps.

On Linux, the action installs Podman v5.x and its key dependencies (like CRIU) from the openSUSE Kubic repository, ensuring you get a modern version.

### Inputs

This action accepts three inputs to customize its behavior:

**podman-version-input**: This input is used only on Windows runners. You can set it to 'latest' (which is the default) to automatically install the most recent Podman release, or provide a specific version string (e.g., '5.6.2') to install that exact version.

**ubuntu-version**: This input is used only on Linux runners. It specifies the Ubuntu version codename (like '23.10' or '22.04') needed to construct the correct URL for the Kubic repository. The default value is '23.10'.

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

### Custom Ubuntu Version for Linux

```yaml
- name: Install Podman on Ubuntu 22.04
  uses: redhat-actions/podman-install@main
  with:
    ubuntu-version: '22.04'
```