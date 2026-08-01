# BLARCHY updates

BLARCHY follows normal Arch package-management behavior.

## System and application packages

Run:

```bash
yay -Syu
```

Yay updates official Arch packages and installed AUR packages. BLARCHY does
not install an ALPM guard, replace pacman configuration, wrap the `yay` binary,
run a separate package transaction, or require a BLARCHY-specific update
command.

The installer saves yay's `devel` setting so plain `yay -Syu` also checks
installed VCS packages such as `quickshell-git`.

The retained `omarchy update` route is only a compatibility alias for
`yay -Syu`. The menu and update indicator launch `yay -Syu` directly.

Direct pacman commands also remain valid Arch administration:

```bash
sudo pacman -Syu
```

Pacman does not update AUR packages, which is why `yay -Syu` is the recommended
single command.

## BLARCHY source

The cloned BLARCHY repository is configuration source, not an installed Arch
package. Normal package updates therefore leave it pinned to the revision the
user installed. They never pull Git code or execute newly downloaded repository
scripts as root.

To update BLARCHY itself:

```bash
cd ~/blarchy
git pull --ff-only
./install.sh
```

The installer is idempotent. On a source upgrade it installs newly introduced
package defaults, reapplies system integration, preserves existing user files,
and runs pending standalone-safe migrations.

This separation remains necessary until `blarchy-git` is published as a real
AUR package. Yay's development-package updater deliberately ignores locally
built VCS packages for which it cannot find AUR metadata, so pretending that a
local package is AUR-managed would make `yay -Syu` silently incomplete.

## Repository ownership

The current branch may track the BLARCHY fork as its normal Git upstream.
Basecamp/Omarchy should remain a separate development remote, conventionally
named `upstream`:

```bash
git fetch upstream
git merge upstream/quattro
```

Incorporating upstream changes is a deliberate repository-maintenance action;
it is unrelated to Arch package updates.
