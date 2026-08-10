#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/docker-helper-test.XXXXXX")"
TEST_DIR="$(cd "$TEST_DIR" && pwd)"
REMOTE_DIR="$TEST_DIR/remote.git"
SOURCE_DIR="$TEST_DIR/source"
INSTALL_DIR="$TEST_DIR/install"
PLUGIN_DIR="$TEST_DIR/cli-plugins"
UNRELATED_TARGET="$TEST_DIR/orbstack/docker-compose"
UNRELATED_BUILDX_TARGET="$TEST_DIR/orbstack/docker-buildx"
FOREIGN_CLEANUP_TARGET="$TEST_DIR/foreign/docker-cleanup"
FAKE_BIN="$TEST_DIR/fake-bin"
SUDO_LOG="$TEST_DIR/sudo.log"

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_link_target() {
    local link_path="$1"
    local expected="$2"
    [[ -L "$link_path" ]] || fail "$link_path is not a symlink"
    [[ "$(readlink "$link_path")" == "$expected" ]] || \
        fail "$link_path points to $(readlink "$link_path"), expected $expected"
}

mkdir -p "$SOURCE_DIR" "$(dirname "$UNRELATED_TARGET")" "$PLUGIN_DIR"
mkdir -p "$(dirname "$FOREIGN_CLEANUP_TARGET")"
cp "$PROJECT_DIR/install.sh" "$PROJECT_DIR/docker-helper-link" \
    "$PROJECT_DIR/plugins.txt" \
    "$PROJECT_DIR/docker-cleanup" "$PROJECT_DIR/docker-ip" \
    "$PROJECT_DIR/docker-query" "$SOURCE_DIR/"
chmod +x "$SOURCE_DIR/install.sh" "$SOURCE_DIR/docker-helper-link" \
    "$SOURCE_DIR/docker-cleanup" \
    "$SOURCE_DIR/docker-ip" "$SOURCE_DIR/docker-query"

mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SUDO_LOG"
EOF
chmod +x "$FAKE_BIN/sudo"

git init --bare "$REMOTE_DIR" >/dev/null
git -C "$SOURCE_DIR" init >/dev/null
git -C "$SOURCE_DIR" config user.name "Docker Helper Test"
git -C "$SOURCE_DIR" config user.email "docker-helper-test@example.invalid"
git -C "$SOURCE_DIR" add .
git -C "$SOURCE_DIR" commit -m "initial test fixture" >/dev/null
git -C "$SOURCE_DIR" remote add origin "$REMOTE_DIR"
git -C "$SOURCE_DIR" push -u origin HEAD:main >/dev/null
git --git-dir="$REMOTE_DIR" symbolic-ref HEAD refs/heads/main

touch "$UNRELATED_TARGET"
touch "$UNRELATED_BUILDX_TARGET"
ln -s "$UNRELATED_TARGET" "$PLUGIN_DIR/docker-compose"
ln -s "$UNRELATED_BUILDX_TARGET" "$PLUGIN_DIR/docker-buildx"

run_installer() {
    DOCKER_HELPER_REPO="$REMOTE_DIR" \
    DOCKER_HELPER_DIR="$INSTALL_DIR" \
    DOCKER_CLI_PLUGIN_DIR="$PLUGIN_DIR" \
        "$PROJECT_DIR/install.sh" >/dev/null
}

run_installer
for plugin in docker-cleanup docker-ip docker-query; do
    assert_link_target "$PLUGIN_DIR/$plugin" "$INSTALL_DIR/$plugin"
done
assert_link_target "$PLUGIN_DIR/docker-compose" "$UNRELATED_TARGET"
assert_link_target "$PLUGIN_DIR/docker-buildx" "$UNRELATED_BUILDX_TARGET"

DOCKER_CLI_PLUGIN_DIR="$PLUGIN_DIR" \
    "$INSTALL_DIR/docker-helper-link" --source "$INSTALL_DIR" --remove >/dev/null
for plugin in docker-cleanup docker-ip docker-query; do
    [[ ! -e "$PLUGIN_DIR/$plugin" && ! -L "$PLUGIN_DIR/$plugin" ]] || \
        fail "$plugin link was not removed"
done
assert_link_target "$PLUGIN_DIR/docker-compose" "$UNRELATED_TARGET"
assert_link_target "$PLUGIN_DIR/docker-buildx" "$UNRELATED_BUILDX_TARGET"

touch "$FOREIGN_CLEANUP_TARGET"
ln -s "$FOREIGN_CLEANUP_TARGET" "$PLUGIN_DIR/docker-cleanup"
DOCKER_CLI_PLUGIN_DIR="$PLUGIN_DIR" \
    "$INSTALL_DIR/docker-helper-link" --source "$INSTALL_DIR" --remove >/dev/null
assert_link_target "$PLUGIN_DIR/docker-cleanup" "$FOREIGN_CLEANUP_TARGET"
run_installer

if command -v docker >/dev/null; then
    for command_name in cleanup ip query; do
        DOCKER_CONFIG="$TEST_DIR" docker "$command_name" --help >/dev/null 2>&1 || \
            fail "docker did not resolve the $command_name plugin"
    done
fi

run_installer
assert_link_target "$PLUGIN_DIR/docker-compose" "$UNRELATED_TARGET"
assert_link_target "$PLUGIN_DIR/docker-buildx" "$UNRELATED_BUILDX_TARGET"

if [[ "$EUID" -ne 0 ]]; then
    PATH="$FAKE_BIN:$PATH" SUDO_LOG="$SUDO_LOG" \
        "$INSTALL_DIR/docker-helper-link" --source "$INSTALL_DIR" \
        --system >/dev/null
    grep -Fxq 'mkdir -p /usr/local/lib/docker/cli-plugins' "$SUDO_LOG" || \
        fail "--system did not use sudo to create the plugin directory"
    for plugin in docker-cleanup docker-ip docker-query; do
        grep -Fxq \
            "ln -sfn $INSTALL_DIR/$plugin /usr/local/lib/docker/cli-plugins/$plugin" \
            "$SUDO_LOG" || fail "--system did not use sudo to link $plugin"
    done
fi

if "$INSTALL_DIR/docker-helper-link" --source "$INSTALL_DIR" --system \
    --plugin-dir "$PLUGIN_DIR" >/dev/null 2>&1; then
    fail "linker accepted --system with --plugin-dir"
fi

printf '\n# update marker\n' >> "$SOURCE_DIR/docker-ip"
git -C "$SOURCE_DIR" add docker-ip
git -C "$SOURCE_DIR" commit -m "update test fixture" >/dev/null
git -C "$SOURCE_DIR" push >/dev/null
run_installer
grep -q 'update marker' "$INSTALL_DIR/docker-ip" || fail "installer did not pull update"
assert_link_target "$PLUGIN_DIR/docker-compose" "$UNRELATED_TARGET"
assert_link_target "$PLUGIN_DIR/docker-buildx" "$UNRELATED_BUILDX_TARGET"

printf 'docker-cleanup\ndocker-missing\n' > "$SOURCE_DIR/plugins.txt"
git -C "$SOURCE_DIR" add plugins.txt
git -C "$SOURCE_DIR" commit -m "add invalid test fixture" >/dev/null
git -C "$SOURCE_DIR" push >/dev/null
if run_installer 2>/dev/null; then
    fail "installer accepted a missing manifest plugin"
fi
assert_link_target "$PLUGIN_DIR/docker-compose" "$UNRELATED_TARGET"
assert_link_target "$PLUGIN_DIR/docker-buildx" "$UNRELATED_BUILDX_TARGET"

echo "PASS: installer clones, updates, links, unlinks, validates, supports system links, and preserves unrelated plugins"
