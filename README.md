# podman-install
This composite action installs Podman on GitHub-hosted runners for both Linux (Ubuntu) and Windows.

It's designed to be a simple, one-stop solution for setting up Podman in your CI workflows.

## Features

Cross-Platform: Works for both ubuntu-latest and windows-latest runners.

Smart Windows Installation: Automatically installs the latest Podman version by default, or lets you specify a specific version (e.g., 5.6.2).

Windows Ready-to-Use: On Windows, the action automatically runs podman machine init --now after installation, so your machine is ready for use in subsequent steps.

Modern Linux Support: On Ubuntu, it installs Podman v5.x and its dependencies (like CRIU) from the Kubic repository.

### Usage

Example: Install Latest Podman

This is the simplest use case. It will install Podman 5.x from Kubic on Linux and the latest available version on Windows.
YAML

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
    steps:
      - name: Install Podman
        uses: redhat-developer/podman-install@main

#### Example: Install a Specific Podman Version on Windows

If your CI needs to be pinned to a specific Podman version on Windows, use the podman-version-input input.
YAML

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - name: Install specific Podman version
        uses: redhat-developer/podman-install@main
        with:
          podman-version-input: '5.6.2'

##### Example: Target a Different Ubuntu Version

If you are using an older Ubuntu runner (e.g., ubuntu-22.04), you may need to specify the corresponding ubuntu-version for the Kubic repository.
YAML

jobs:
  build-linux:
    runs-on: ubuntu-22.04
    steps:
      - name: Install Podman on Ubuntu 22.04
        uses: redhat-developer/podman-install@main
        with:
          ubuntu-version: '22.04'

Inputs

podman-version-input: (Windows only) The Podman version to install.

    Default: latest

    Options: latest or a specific version string (e.g., '5.6.2').

ubuntu-version: (Linux only) The Ubuntu version codename to use for the Kubic repository URL.

    Default: 23.10