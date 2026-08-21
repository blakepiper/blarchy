#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

packages="$ROOT/install/packages"

for package_name in \
  alacritty firefox gimp nautilus nodejs npm nwg-dock-hyprland python \
  oh-my-pi-bin python-pip spotify steam vscodium-bin; do
  grep -Fxq "$package_name" "$packages" || fail "personal package manifest includes $package_name"
done
pass "personal package manifest includes every package-managed default"

for package_name in chromium docker docker-buildx docker-compose foot lazydocker ufw-docker; do
  if grep -Fxq "$package_name" "$packages"; then
    fail "personal package manifest excludes $package_name"
  fi
done
pass "personal package manifest excludes removed package defaults"

while IFS= read -r desktop_file; do
  [[ ! -e $ROOT/applications/$desktop_file ]] || fail "removed launcher is absent" "$desktop_file"
done <<'DESKTOPS'
Basecamp.desktop
ChatGPT.desktop
Discord.desktop
Docker.desktop
Google Contacts.desktop
Google Maps.desktop
Google Messages.desktop
Google Photos.desktop
HEY.desktop
WhatsApp.desktop
X.desktop
YouTube.desktop
Zoom.desktop
foot.desktop
DESKTOPS
pass "removed applications have no shipped launcher entries"

if rg -q '(^|[|<])foot([|>)]|$)|foot\.desktop' "$ROOT/bin/omarchy-install-terminal"; then
  fail "Foot is not offered by the terminal installer"
fi
pass "Foot is absent from terminal defaults and installation choices"

jq -e '
  .policies.Extensions.Install == ["https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"] and
  (.policies.Extensions.Locked // [] | length) == 0
' "$ROOT/default/firefox/policies.json" >/dev/null ||
  fail "Firefox policy installs removable uBlock Origin"
grep -Fq 'default/firefox/policies.json' "$ROOT/install/standalone/system.sh" ||
  fail "standalone system install deploys Firefox policy"
pass "fresh Firefox installs receive uBlock Origin without an extension lock"

grep -Fxq 'Alacritty.desktop' "$ROOT/default/xdg-terminal-exec/hyprland-xdg-terminals.list" ||
  fail "xdg-terminal-exec defaults to Alacritty"
grep -Fxq 'x-scheme-handler/http=firefox.desktop' "$ROOT/default/applications/mimeapps.list" ||
  fail "HTTP MIME default is Firefox"
grep -Fxq 'inode/directory=org.gnome.Nautilus.desktop' "$ROOT/default/applications/mimeapps.list" ||
  fail "directory MIME default is Nautilus"
grep -Fxq 'text/plain=codium.desktop' "$ROOT/default/applications/mimeapps.list" ||
  fail "text MIME default is VSCodium"
pass "personal application defaults use Firefox, Alacritty, Nautilus, and VSCodium"

grep -Fq 'Pending system updates' "$ROOT/shell/plugins/bar/widgets/SystemUpdate.qml" ||
  fail "top-bar update indicator describes ordinary package updates"
pass "the bar describes ordinary package updates"

grep -Fxq 'omarchy-mise-install codex' "$ROOT/install/user/mise.sh" || fail "Codex has a mise installation path"
grep -Fxq 'omarchy-mise-install claude' "$ROOT/install/user/mise.sh" || fail "Claude Code has a mise installation path"
pass "Codex and Claude Code use the existing idempotent mise wrappers"

grep -Fxq 'oh-my-pi-bin' "$packages" || fail "Oh My Pi is installed from its native binary package"
pass "Oh My Pi uses its native binary package"

if grep -Fq 'mise use -g node' "$ROOT/install/user/mise-work.sh"; then
  fail "Node.js is not replaced by a mise-managed version"
fi
pass "Node.js and npm remain owned by Arch packages"

grep -Fq 'nwg-dock-hyprland -d -p bottom -a center' "$ROOT/config/hypr/autostart.lua" ||
  fail "the desktop autostarts the bottom-center autohide dock"
for pin in firefox org.gnome.Nautilus gimp Alacritty Spotify steam; do
  grep -Fxq "$pin" "$ROOT/install/user/dock.sh" || fail "dock pins $pin"
done
pass "the dock is autohidden and seeds the requested pins"

grep -Fq 'omarchy-shell notifications showHistory' "$ROOT/shell/plugins/bar/indicators/Dnd.qml" ||
  fail "notification indicator opens notification history"
pass "notification indicator exposes history while retaining a DND control"

grep -Fq "'yay -Syu'" "$ROOT/shell/plugins/bar/widgets/SystemUpdate.qml" ||
  fail "top-bar system update action invokes yay directly"
grep -Fq "'yay -Syu'" "$ROOT/default/omarchy/omarchy-menu.jsonc" ||
  fail "desktop menu invokes yay directly"
pass "normal updates use standard Arch and AUR behavior"
