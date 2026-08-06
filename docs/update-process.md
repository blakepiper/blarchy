# BLARCHY updates

BLARCHY's full update path updates Arch/AUR packages and the BLARCHY environment
in one command. Neither path consumes Omarchy automatically.

## System and application packages

For the package-only path, run:

```bash
yay -Syu
# or: blarchy system update
```

Yay updates official Arch packages and installed AUR packages. BLARCHY does
not replace pacman configuration or repositories. The installer enables yay's
`devel` setting so installed VCS packages such as `quickshell-git` participate.

Direct pacman commands remain valid Arch administration. Pacman does not update
AUR packages, which is why `yay -Syu` is the recommended full system update.

## Full update

Run:

```bash
blarchy update
```

This runs `yay -Syu` first, updating all installed packages owned by Arch
repositories or the AUR, then updates BLARCHY. The BLARCHY phase requires a
clean configured source worktree with a tracked remote at
`https://github.com/blakepiper/blarchy`. It verifies that ownership before it
fast-forwards the source and invokes the idempotent installer. The installer
refreshes the stable runtime under `/usr/local/share/blarchy`, adds newly
required packages, reapplies system integration, preserves user-owned
configuration, and runs pending BLARCHY migrations.

If the package transaction succeeds but the source checkout is unavailable,
dirty, or untrusted, the command reports the BLARCHY failure after completing
the package update. Use `blarchy system update` when only the package phase is
desired.

This does not update software installed through unrelated package managers such
as Flatpak, npm, mise, or rustup, and it does not perform device firmware
updates through `fwupd`. Those tools have separate update commands.

The installed desktop does not execute from the Git worktree. Its ordinary
behavior is therefore unaffected by the checkout's location, active branch, or
uncommitted development files. A source update becomes live only after the
installer has successfully refreshed the installed runtime.

The retained `omarchy update` route is a compatibility alias for the system
package update. It does not update BLARCHY source. Use `blarchy update` for the
combined package and environment update.

## Repository ownership

The BLARCHY checkout normally tracks `blakepiper/blarchy`. Basecamp/Omarchy may
remain a separate developer remote named `upstream`, but it is never consulted
by installation, login, package updates, `blarchy update`, or migration
discovery.

Developers can inspect it explicitly:

```bash
git fetch upstream
git log --oneline upstream/quattro
```

Useful changes should be reviewed and deliberately ported or cherry-picked.
Merging an upstream branch is not a user update workflow or a BLARCHY release
requirement.

The v0.2 installer clears the old `/etc/omarchy.conf` development-path model in
favor of the installed runtime. Developers who intentionally want live-checkout
behavior can opt back in with `omarchy dev link <checkout>`; that isolated
override now lives in `/etc/blarchy-dev.conf`.
