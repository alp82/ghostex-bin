# ghostex-bin

[![AUR version](https://img.shields.io/aur/version/ghostex-bin)](https://aur.archlinux.org/packages/ghostex-bin)
[![Ghostex release](https://img.shields.io/github/v/release/maddada/Ghostex?label=Ghostex)](https://github.com/maddada/Ghostex/releases/latest)

Arch Linux packaging for the prebuilt x86_64 release of
[Ghostex](https://github.com/maddada/Ghostex). Maintained by
[Alp on AUR](https://aur.archlinux.org/account/Alp).

## Install

```sh
git clone https://aur.archlinux.org/ghostex-bin.git
cd ghostex-bin
makepkg -si
```

Or use `yay -S ghostex-bin` / `paru -S ghostex-bin`.

The package installs upstream's application tree under `/opt/ghostex`, the
`ghostex` and `gx` commands, a desktop entry, icon, and upstream MIT license.
The first GUI launch downloads the CEF browser runtime to your user cache.
The optional editor also downloads its runtime on demand. Agent CLIs are
installed separately. Update the packaged application through your AUR workflow.

## How the packaging works

The AUR holds a recipe, not the upstream binaries. `makepkg` downloads the exact
versioned tarball and license in `source`, verifies `sha256sums`, extracts them,
then runs `package()` to stage files under `$pkgdir`. It creates a
`ghostex-bin-<version>-<release>-x86_64.pkg.tar.zst` archive for pacman to install.

| File | Purpose |
| --- | --- |
| `PKGBUILD` | Version, download URLs, checksums, dependencies and installation layout |
| `.SRCINFO` | Generated metadata that the AUR reads; never edit by hand |
| `LICENSE` | 0BSD license for this packaging repository; the application is MIT |
| `scripts/update.py` | Detect a newer stable release and refresh pinned checksums |
| `scripts/check.sh` | Build and test in an isolated Arch Docker container |
| `scripts/publish.sh` | Copy only the three packaging files into the AUR Git repository |

`pkgver` follows upstream, such as `9.0.0`. `pkgrel` starts at `1` for each new
upstream version. Increment `pkgrel` when changing the installed package for the
same upstream release, such as fixing a dependency. Do not bump versions for
README-only changes.

## Release automation

1. **Check upstream releases** runs hourly at 23 minutes past the hour, or manually through
   GitHub Actions. It queries the upstream releases API and requires the exact
   Linux x64 asset. Drafts, prereleases, downgrades and unexpected versions/URLs
   are rejected. An incomplete release fails and is retried on the next run.
2. For a new version, it downloads the archive, calculates SHA-256 and compares
   GitHub's asset digest when available. It also refreshes the versioned license
   checksum, resets `pkgrel`, builds/tests the package and regenerates `.SRCINFO`.
3. It opens an update PR for the audit trail, merges it immediately with a
   squash commit, and dispatches **Publish to AUR**. No human review happens
   before publishing. A checksum pins bytes; it does not itself establish that
   a new release is trustworthy, so keep an eye on upstream release notes,
   license changes and runtime dependencies.
4. **Publish to AUR** runs fresh checks, then uses the dedicated SSH key in the
   `aur` GitHub environment to push to AUR's `master`. Unchanged packaging
   produces no AUR commit. Superseded workflows skip publishing. Only
   `PKGBUILD`, `.SRCINFO` and `LICENSE` go to AUR.

To roll back a bad release, revert the update commit on `main`. That push
publishes the previous recipe with a bumped `pkgrel` if you increment it.

Pushes made with `GITHUB_TOKEN` do not trigger another Actions run, so the
update workflow validates before opening the PR and then starts publishing
through `workflow_dispatch`, which is exempt from that rule. Human-opened PRs
use the **Check package** workflow.

GitHub repository Actions settings must allow Actions to create pull requests.
The `aur` environment contains `AUR_SSH_PRIVATE_KEY`; its public key must be
registered on the AUR maintainer account. The SSH host key is pinned in
`.ci/aur-known-hosts` and was checked against the fingerprint published on
[the AUR homepage](https://aur.archlinux.org/).

## Make an update yourself

Requires Python 3, Git and Docker. Run from this repository:

```sh
git switch main
git pull --ff-only
git switch -c update/ghostex-next
python3 scripts/update.py
bash scripts/check.sh --refresh-srcinfo
git diff -- PKGBUILD .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m 'Update Ghostex packaging'
git push -u origin HEAD
gh pr create
```

For a packaging-only fix, edit `PKGBUILD` and increment `pkgrel` instead of
running the updater. On Arch you can regenerate metadata alone with
`makepkg --printsrcinfo > .SRCINFO`; still build and test before submitting.

Run these checks for an existing recipe:

```sh
python3 -m unittest discover -s tests
bash scripts/check.sh
```

The container checks the build, generated metadata, namcap output, installation,
desktop-file syntax, both CLI help commands, shared-library resolution,
reinstallation and removal. Outputs, including an installable package, are in
`.artifacts/`. `sudo pacman -U .artifacts/ghostex-bin-*.pkg.tar.zst` installs that
local package for interactive GUI testing.

The automated checks do not exercise GUI rendering, first-run CEF downloads,
agent sessions, or migration from an older application version. Namcap's exact
`ELF files outside of a valid path ('opt/')` error is allowed because this
prebuilt application preserves upstream's `/opt` layout. Other namcap errors
fail the build. Warnings about prebuilt binary hardening/stripping and libraries
used by the downloaded browser runtime remain visible in `.artifacts/namcap.log`.

## Maintainer references

- [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [PKGBUILD reference](https://man.archlinux.org/man/PKGBUILD.5.en)
- [Creating packages](https://wiki.archlinux.org/title/Creating_packages)
- [GitHub Actions workflow triggers](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)

Watch AUR comments and out-of-date flags as well as failed Actions runs. If you
stop maintaining the package, disown it on AUR so another maintainer can adopt it.
