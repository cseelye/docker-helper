#!/usr/bin/env bash
set -euo pipefail

DOCKER_HELPER_REPO="${DOCKER_HELPER_REPO:-git@github.com:cseelye/docker-helper.git}"
DOCKER_HELPER_DIR="${DOCKER_HELPER_DIR:-$HOME/.local/share/docker-helper}"
DOCKER_CLI_PLUGIN_DIR="${DOCKER_CLI_PLUGIN_DIR:-$HOME/.docker/cli-plugins}"

die() {
    echo "Error: $*" >&2
    exit 1
}

if [[ -e "$DOCKER_HELPER_DIR" && ! -d "$DOCKER_HELPER_DIR/.git" ]]; then
    die "$DOCKER_HELPER_DIR exists but is not a Git checkout."
fi

if [[ ! -d "$DOCKER_HELPER_DIR/.git" ]]; then
    echo "==> Cloning docker-helper into $DOCKER_HELPER_DIR..."
    mkdir -p "$(dirname "$DOCKER_HELPER_DIR")"
    git clone "$DOCKER_HELPER_REPO" "$DOCKER_HELPER_DIR"
else
    echo "==> Updating docker-helper in $DOCKER_HELPER_DIR..."
    git -C "$DOCKER_HELPER_DIR" pull --ff-only
fi

LINKER="$DOCKER_HELPER_DIR/docker-helper-link"
[[ -x "$LINKER" ]] || die "Docker helper linker not found or not executable: $LINKER"

DOCKER_CLI_PLUGIN_DIR="$DOCKER_CLI_PLUGIN_DIR" \
    "$LINKER" --source "$DOCKER_HELPER_DIR"
