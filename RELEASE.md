# Releasing docker-helper

This repository is released as a signed Git tag. The Homebrew formula in
`cseelye/homebrew-tap` downloads GitHub's source archive for that tag and pins
it with a SHA-256 checksum.

Publish in this order:

1. Test and publish the Docker-helper source and tag.
2. Calculate the tagged archive checksum.
3. Update and test the Homebrew formula.
4. Publish the Homebrew tap change.
5. Test the bootstrapper on fresh macOS and Linux systems.

Never publish the formula before its source tag is available.

## 1. Prepare the source release

Start from a clean `main` branch with the intended changes committed and
signed:

```sh
git switch main
git status --short --branch
tests/install.bash
git log -1 --show-signature
```

Choose the next version using semantic versioning. Use a minor release for a
backward-compatible feature, a patch release for a backward-compatible fix,
and a major release for an incompatible change.

Push `main` before creating the release tag:

```sh
git push origin main
```

## 2. Create and publish the signed tag

Set the release version without the leading `v`, then create an annotated,
signed tag:

```sh
version=0.2.0
git tag -s "v${version}" -m "docker-helper v${version}"
git tag --verify "v${version}"
git push origin "v${version}"
```

Confirm that the tag resolves to the intended commit:

```sh
git show --no-patch --show-signature "v${version}"
```

Do not move or replace a published tag. If a release is wrong, fix it in a new
patch release.

## 3. Calculate the Homebrew archive checksum

Download the archive from the published tag and calculate its SHA-256:

```sh
archive="$(mktemp -t docker-helper-v${version}.XXXXXX.tar.gz)"
curl -fsSL \
  "https://github.com/cseelye/docker-helper/archive/refs/tags/v${version}.tar.gz" \
  -o "$archive"
shasum -a 256 "$archive"
```

Keep the resulting checksum for the formula update. Remove the temporary
archive after confirming the formula contains the same checksum.

## 4. Update and validate the Homebrew formula

In `cseelye/homebrew-tap`, update `Formula/docker-helper.rb`:

```ruby
url "https://github.com/cseelye/docker-helper/archive/refs/tags/vVERSION.tar.gz"
sha256 "ARCHIVE_SHA256"
```

Do not change the Docker CLI plugin metadata assertion merely to match the
package version. `SchemaVersion` is the Docker plugin protocol version.

Run the local formula checks:

```sh
brew style Formula/docker-helper.rb
brew audit --formula cseelye/tap/docker-helper
```

On a disposable macOS system, install from the updated tap, then create the
system links outside Homebrew's post-install sandbox:

```sh
brew install cseelye/tap/docker-helper
docker-helper-link --system
```

Verify each manifest entry is a link into the formula's `opt_libexec`:

```sh
while IFS= read -r plugin; do
  case "$plugin" in ''|'#'*) continue ;; esac
  test -L "/usr/local/lib/docker/cli-plugins/$plugin"
  readlink "/usr/local/lib/docker/cli-plugins/$plugin"
done < "$(brew --prefix docker-helper)/libexec/plugins.txt"
```

Run the formula test, remove the system links, and test a second installation
or upgrade when the release changes installation behavior:

```sh
brew test cseelye/tap/docker-helper
docker-helper-link --system --remove
brew reinstall cseelye/tap/docker-helper
docker-helper-link --system
```

After validation, commit and push the formula update.

## 5. Validate bootstrap integration

Test the bootstrapper on fresh disposable macOS and Linux systems. Run it twice
on each system to cover both installation and idempotent update paths.

On macOS, verify:

```sh
brew list --formula docker-helper
test -L /usr/local/lib/docker/cli-plugins/docker-cleanup
test -L /usr/local/lib/docker/cli-plugins/docker-ip
test -L /usr/local/lib/docker/cli-plugins/docker-query
```

On Linux without Homebrew, verify that the Git fallback checkout and user-level
plugin links still work:

```sh
test -d "$HOME/.local/share/docker-helper/.git"
test -L "$HOME/.docker/cli-plugins/docker-cleanup"
test -L "$HOME/.docker/cli-plugins/docker-ip"
test -L "$HOME/.docker/cli-plugins/docker-query"
```

## Rollback

If the formula has not been published, fix it locally and repeat validation.
If the formula has been published with a bad source version or checksum, revert
the formula to the last working release or publish a corrected patch release.
Never rewrite a published release tag.
