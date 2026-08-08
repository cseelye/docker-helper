#!/usr/bin/env bash
set -euo pipefail

DOCKER_HELPER_REPO="${DOCKER_HELPER_REPO:-git@github.com:cseelye/docker-helper.git}"
DOCKER_HELPER_DIR="${DOCKER_HELPER_DIR:-$HOME/.local/share/docker-helper}"
DOCKER_CLI_PLUGIN_DIR="${DOCKER_CLI_PLUGIN_DIR:-$HOME/.docker/cli-plugins}"
PLUGIN_MANIFEST="$DOCKER_HELPER_DIR/plugins.txt"

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

[[ -f "$PLUGIN_MANIFEST" ]] || die "Plugin manifest not found: $PLUGIN_MANIFEST"

plugins=()
while IFS= read -r plugin || [[ -n "$plugin" ]]; do
    case "$plugin" in
        ''|'#'*) continue ;;
    esac

    case "$plugin" in
        docker-*) ;;
        *) die "Invalid plugin name in manifest: $plugin" ;;
    esac
    [[ "$plugin" != *[!A-Za-z0-9._-]* ]] || \
        die "Invalid plugin name in manifest: $plugin"

    plugin_path="$DOCKER_HELPER_DIR/$plugin"
    [[ -f "$plugin_path" ]] || die "Plugin not found: $plugin_path"
    [[ -x "$plugin_path" ]] || die "Plugin is not executable: $plugin_path"
    plugins+=("$plugin")
done < "$PLUGIN_MANIFEST"

[[ ${#plugins[@]} -gt 0 ]] || die "Plugin manifest is empty: $PLUGIN_MANIFEST"

mkdir -p "$DOCKER_CLI_PLUGIN_DIR"
for plugin in "${plugins[@]}"; do
    plugin_path="$DOCKER_HELPER_DIR/$plugin"
    link_path="$DOCKER_CLI_PLUGIN_DIR/$plugin"

    if [[ -d "$link_path" && ! -L "$link_path" ]]; then
        die "Cannot replace plugin directory: $link_path"
    fi

    ln -sfn "$plugin_path" "$link_path"
    echo "    Linked $link_path -> $plugin_path"
done

echo "==> Docker helper plugins installed."
