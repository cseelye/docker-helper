# docker-helper

Small plugins that make the Docker CLI easier to use.

## Install with Homebrew

```sh
brew install cseelye/tap/docker-helper
docker-helper-link
```

Homebrew installs the helpers from a versioned release. `docker-helper-link`
links the plugins listed in `plugins.txt` into the Docker CLI-plugin directory.
To remove only those links before uninstalling the formula, run:

```sh
docker-helper-link --remove
brew uninstall docker-helper
```

## Install from Git

Run `install.sh` from a checkout of this repository. The installer maintains a
standalone checkout at `~/.local/share/docker-helper` and creates symlinks in
`~/.docker/cli-plugins` for the helpers listed in `plugins.txt`.

The Git installer is safe to run repeatedly. It clones the standalone checkout
when absent, otherwise updates it with `git pull --ff-only`, validates every
manifest entry, and updates only the corresponding plugin symlinks. Other
entries in `~/.docker/cli-plugins`, including Docker Compose and Buildx links
managed by another tool, are left untouched.

Environment variables can override the defaults for testing or alternate
installations:

- `DOCKER_HELPER_REPO`
- `DOCKER_HELPER_DIR`
- `DOCKER_CLI_PLUGIN_DIR`

The standalone `docker-helper-link` command can also link or remove the
manifest entries without cloning or updating a repository. It uses
`${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins` unless `--plugin-dir` or
`DOCKER_CLI_PLUGIN_DIR` overrides the destination.

Run the installer test with:

```sh
tests/install.bash
```
