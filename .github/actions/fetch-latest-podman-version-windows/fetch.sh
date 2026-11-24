#!/usr/bin/env bash
# /**********************************************************************
#  * Copyright (C) 2025-2026 Red Hat, Inc.
#  *
#  * Licensed under the Apache License, Version 2.0 (the "License");
#  * you may not use this file except in compliance with the License.
#  * You may obtain a copy of the License at
#  *
#  * http://www.apache.org/licenses/LICENSE-2.0
#  *
#  * Unless required by applicable law or agreed to in writing, software
#  * distributed under the License is distributed on an "AS IS" BASIS,
#  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  * See the License for the specific language governing permissions and
#  * limitations under the License.
#  *
#  * SPDX-License-Identifier: Apache-2.0
#  ***********************************************************************/

# Resolves a Podman Windows installer download URL.
#
# Shared by action.yml (the main composite action) and the
# fetch-latest-podman-version-windows sub-action so the logic lives in exactly
# one place. Inputs are read from the environment:
#
#   INPUT_VERSION    latest | nightly | main | vX.Y.Z | https://...
#   ARCHITECTURE     amd64 (default) | arm64
#   FILE_TYPE        msi (default) | setup.exe | installer.exe | remote.zip
#   GITHUB_TOKEN     optional; required for nightly, recommended for releases
#   GITHUB_OUTPUT    required; receives version, download_url, is_latest, is_nightly

set -euo pipefail

: "${INPUT_VERSION:=}"
: "${ARCHITECTURE:=amd64}"
: "${FILE_TYPE:=msi}"
: "${GITHUB_TOKEN:=}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"
: "${PODMAN_REPO:=podman-container-tools/podman}"
: "${NIGHTLY_WORKFLOW:=release-pipeline-validation.yml}"

echo "Input version: $INPUT_VERSION"
echo "Architecture: $ARCHITECTURE"
echo "File type: $FILE_TYPE"
if [ -n "$GITHUB_TOKEN" ]; then
  echo "GitHub Token: ***"
else
  echo "GitHub Token: not provided"
fi

# Input validation
if [ -z "$INPUT_VERSION" ]; then
  echo "Error: Version input cannot be empty"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed"
  exit 1
fi

gh_api() {
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: github_token is required for this operation"
    exit 1
  fi
  gh api "$@" --header "Authorization: Bearer ${GITHUB_TOKEN}"
}

if [ "$INPUT_VERSION" = "nightly" ] || [ "$INPUT_VERSION" = "main" ]; then
  echo "Resolving latest successful Podman nightly artifact URL from GitHub Actions..."

  RUN_ID="$(gh_api "repos/${PODMAN_REPO}/actions/workflows/${NIGHTLY_WORKFLOW}/runs?status=success&per_page=20" \
    --jq '.workflow_runs[0].id')"

  if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
    echo "Error: Could not find a successful ${NIGHTLY_WORKFLOW} workflow run"
    exit 1
  fi

  echo "Using workflow run: $RUN_ID"

  ARTIFACT_PREFIX="win-msi-${ARCHITECTURE}-main-"
  ARTIFACT_NAME="$(gh_api "repos/${PODMAN_REPO}/actions/runs/${RUN_ID}/artifacts" \
    --jq ".artifacts[] | select(.name | startswith(\"${ARTIFACT_PREFIX}\")) | .name" | head -n1)"

  if [ -z "$ARTIFACT_NAME" ]; then
    echo "Error: Could not find artifact matching prefix ${ARTIFACT_PREFIX} in run ${RUN_ID}"
    gh_api "repos/${PODMAN_REPO}/actions/runs/${RUN_ID}/artifacts" --jq '.artifacts[].name'
    exit 1
  fi

  ARTIFACT_ID="$(gh_api "repos/${PODMAN_REPO}/actions/runs/${RUN_ID}/artifacts" \
    --jq ".artifacts[] | select(.name == \"${ARTIFACT_NAME}\") | .id")"

  DOWNLOAD_URL="$(gh_api "repos/${PODMAN_REPO}/actions/artifacts/${ARTIFACT_ID}" \
    --jq '.archive_download_url')"

  if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Error: Could not resolve archive_download_url for artifact ${ARTIFACT_NAME} (id=${ARTIFACT_ID})"
    exit 1
  fi

  VERSION_SUFFIX="${ARTIFACT_NAME#${ARTIFACT_PREFIX}}"
  VERSION="main-${VERSION_SUFFIX}"

  echo "Nightly Podman version: $VERSION"
  echo "Artifact: ${ARTIFACT_NAME} (id=${ARTIFACT_ID})"
  echo "Download URL: $DOWNLOAD_URL"
  echo "version=$VERSION" >> "$GITHUB_OUTPUT"
  echo "download_url=$DOWNLOAD_URL" >> "$GITHUB_OUTPUT"
  echo "is_latest=false" >> "$GITHUB_OUTPUT"
  echo "is_nightly=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "is_nightly=false" >> "$GITHUB_OUTPUT"

if [ "$INPUT_VERSION" = "latest" ]; then
  echo "Fetching latest Podman release..."

  # Fetch latest release with error handling
  if [ -n "$GITHUB_TOKEN" ]; then
    echo "Using GITHUB_TOKEN for authenticated API request."
    API_RESPONSE=$(curl -sL -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/${PODMAN_REPO}/releases/latest")
  else
    echo "Warning: GITHUB_TOKEN is not set. API requests may be subject to stricter rate limits."
    API_RESPONSE=$(curl -sL "https://api.github.com/repos/${PODMAN_REPO}/releases/latest")
  fi

  # Check for API errors (rate limiting, etc.)
  if echo "$API_RESPONSE" | jq -e '.message' >/dev/null 2>&1; then
    ERROR_MESSAGE=$(echo "$API_RESPONSE" | jq -r '.message')
    echo "Error: GitHub API returned an error: $ERROR_MESSAGE"
    exit 1
  fi

  # Parse version with validation
  LATEST_VERSION=$(echo "$API_RESPONSE" | jq -r '.tag_name')
  if [ "$LATEST_VERSION" = "null" ] || [ -z "$LATEST_VERSION" ]; then
    echo "Error: Could not parse version from GitHub API response"
    exit 1
  fi

  echo "Latest Podman version: $LATEST_VERSION"
  echo "version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
  echo "is_latest=true" >> "$GITHUB_OUTPUT"
  VERSION_NUMBER=${LATEST_VERSION#v}
elif [[ "$INPUT_VERSION" =~ ^https?:// ]]; then
  if [[ "$INPUT_VERSION" == *$'\n'* || "$INPUT_VERSION" == *$'\r'* ]]; then
    echo "Error: URL input cannot contain newline characters"
    exit 1
  fi

  echo "Full URL provided: $INPUT_VERSION"
  echo "download_url=$INPUT_VERSION" >> "$GITHUB_OUTPUT"
  echo "is_latest=false" >> "$GITHUB_OUTPUT"
  if [[ "$INPUT_VERSION" =~ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    echo "version=v${BASH_REMATCH[1]}" >> "$GITHUB_OUTPUT"
  else
    echo "version=custom" >> "$GITHUB_OUTPUT"
  fi
  exit 0
else
  echo "Specific version provided: $INPUT_VERSION"

  if [[ ! "$INPUT_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-](rc|alpha|beta)[0-9]*)?$ ]]; then
    echo "Error: Invalid version format: $INPUT_VERSION"
    echo "Expected formats: latest, nightly, v5.6.1, 5.6.1, or a full URL"
    exit 1
  fi

  if [[ "$INPUT_VERSION" =~ ^v ]]; then
    LATEST_VERSION="$INPUT_VERSION"
  else
    LATEST_VERSION="v$INPUT_VERSION"
  fi
  echo "version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
  echo "is_latest=false" >> "$GITHUB_OUTPUT"
  VERSION_NUMBER=${LATEST_VERSION#v}
fi

# Construct the candidate Windows download URLs. The published assets depend
# on the release: 4.x and early 5.x publish podman-<version>-setup.exe, some
# 5.x releases also ship an .exe installer, and current releases only publish
# the .msi. Try the requested type first, then fall back to the other
# installers so a pinned version resolves whenever any installer exists.
release_base="https://github.com/${PODMAN_REPO}/releases/download/${LATEST_VERSION}"
msi_url="${release_base}/podman-installer-windows-${ARCHITECTURE}.msi"
installer_url="${release_base}/podman-installer-windows-${ARCHITECTURE}.exe"
setup_url="${release_base}/podman-${VERSION_NUMBER}-setup.exe"
zip_url="${release_base}/podman-remote-release-windows_${ARCHITECTURE}.zip"

case "$FILE_TYPE" in
  setup.exe) CANDIDATE_URLS=("$setup_url" "$installer_url" "$msi_url") ;;
  installer.exe) CANDIDATE_URLS=("$installer_url" "$msi_url" "$setup_url") ;;
  remote.zip) CANDIDATE_URLS=("$zip_url") ;;
  msi) CANDIDATE_URLS=("$msi_url" "$installer_url" "$setup_url") ;;
  *)
    echo "Error: Unsupported Windows file type: $FILE_TYPE"
    echo "Supported types: setup.exe, installer.exe, remote.zip, msi"
    exit 1
    ;;
esac

DOWNLOAD_URL=""
for candidate in "${CANDIDATE_URLS[@]}"; do
  echo "Validating download URL: $candidate"
  HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" -I "$candidate")
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    DOWNLOAD_URL="$candidate"
    break
  fi
  echo "Not available (HTTP $HTTP_CODE)"
done

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: No Windows installer found for ${LATEST_VERSION}"
  echo "Tried:"
  printf '  %s\n' "${CANDIDATE_URLS[@]}"
  echo "This may indicate the version doesn't exist or has no Windows installer"
  exit 1
fi

if [ "$DOWNLOAD_URL" != "${CANDIDATE_URLS[0]}" ]; then
  echo "No ${FILE_TYPE} asset for ${LATEST_VERSION}; falling back to $(basename "$DOWNLOAD_URL")"
fi

echo "Download URL: $DOWNLOAD_URL"

echo "Download URL validated successfully"
echo "download_url=$DOWNLOAD_URL" >> "$GITHUB_OUTPUT"
