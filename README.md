# docker-helper

Small plugins that make the Docker CLI easier to use.

## Install

Run `install.sh` from a checkout of this repository. The installer maintains a
standalone checkout at `~/.local/share/docker-helper` and creates symlinks in
`~/.docker/cli-plugins` for the helpers listed in `plugins.txt`.

The installer is safe to run repeatedly. It clones the standalone checkout
when absent, otherwise updates it with `git pull --ff-only`, validates every
manifest entry, and updates only the corresponding plugin symlinks. Other
entries in `~/.docker/cli-plugins`, including Docker Compose and Buildx links
managed by another tool, are left untouched.

Environment variables can override the defaults for testing or alternate
installations:

- `DOCKER_HELPER_REPO`
- `DOCKER_HELPER_DIR`
- `DOCKER_CLI_PLUGIN_DIR`

Run the installer test with:

```sh
tests/install.bash
```
