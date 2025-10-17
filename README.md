# podman-install

This composite action installs Podman on GitHub-hosted runners for both Linux (Ubuntu) and Windows. It's designed to be a simple, one-stop solution for setting up Podman in your CI workflows.

## Features

The action is cross-platform, working for both ubuntu-latest and windows-latest runners.

On Windows, it features a smart installer that automatically fetches the latest Podman version by default. However, you can also specify a specific version if your CI needs to be pinned to an older release. After installation, the action automatically runs podman machine init --now to ensure the Podman machine is running and ready for use in subsequent steps.

On Linux, the action installs Podman v5.x and its key dependencies (like CRIU) from the openSUSE Kubic repository, ensuring you get a modern version.

### Inputs

This action accepts two inputs to customize its behavior:

    podman-version-input: This input is used only on Windows runners. You can set it to 'latest' (which is the default) to automatically install the most recent Podman release, or provide a specific version string (e.g., '5.6.2') to install that exact version.

    ubuntu-version: This input is used only on Linux runners. It specifies the Ubuntu version codename (like '23.10' or '22.04') needed to construct the correct URL for the Kubic repository. The default value is '23.10'.