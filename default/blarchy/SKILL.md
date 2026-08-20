---
name: blarchy
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/hypr/, ~/.config/omarchy/, or
  ~/.config/alacritty/.
  Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps, borders,
  blur, opacity, omarchy-shell, bar, terminal config, themes, background,
  night light, idle, lock screen, screenshots, reminders, layer rules, workspace
  settings, display config, and user-facing blarchy or retained omarchy commands.
  Excludes BLARCHY
  source development through `omarchy dev link` workflows.
---

# BLARCHY Desktop Skill

Manage an installed BLARCHY desktop: Blake's Arch + Hyprland Environment.
BLARCHY is a configuration and desktop layer on Arch Linux, not a separate
distribution. It retains the `omarchy` command and config namespaces for
upstream compatibility.

This skill is for end-user customization on installed systems.
It is not for contributing to BLARCHY source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/hypr/` (window rules, animations, keybindings, monitors, etc.)
- Editing `~/.config/omarchy/shell.json` (status bar layout, widgets)
- Editing the Alacritty terminal config
- Editing ANY file in `~/.config/omarchy/`
- Window behavior, animations, opacity, blur, gaps, borders
- Layer rules, workspace settings, display/monitor configuration
- Themes, backgrounds, fonts, appearance changes
- User-facing `omarchy` commands (`omarchy theme ...`, `omarchy refresh ...`, `omarchy restart ...`, etc.)
- Screenshots, screen recording, reminders, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for BLARCHY development tasks** (editing the BLARCHY source tree, creating migrations, or running `omarchy dev ...` workflows).

## Critical Safety Rules

When invoking a privileged command directly from a graphical context, use
`pkexec` so BLARCHY can show an authorization prompt with command context. Do
not wrap commands that already manage privilege elevation themselves.

**For end-user customization tasks, NEVER modify anything in `/usr/local/share/blarchy/`** - but READING is safe and encouraged.

On a standalone install this path contains BLARCHY's installed runtime snapshot.
Any direct changes will be:

- Lost on the next `blarchy update` or installer rerun
- Outside your user configuration and source checkout
- Bypass BLARCHY's source and user-configuration layers

```
/usr/local/share/blarchy/ # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Source scripts (symlinked to PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
├── shell/                  # BLARCHY shell source and defaults
├── migrations/             # Update migrations
└── install/                # Installation scripts
```

**Reading `/usr/local/share/blarchy/` is SAFE and useful** - do it freely to:
- Understand how omarchy commands work: `omarchy theme set --help` or `cat $(which omarchy-theme-set)`
- See default configs before customizing: `cat "$OMARCHY_PATH/config/omarchy/shell.json"`
- Check stock theme files to copy for customization
- Reference default hyprland settings: `cat /usr/local/share/blarchy/default/hypr/*`

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/omarchy/themes/<custom-name>/` - Custom themes (must be real directories)
- `~/.config/omarchy/hooks/` - Custom automation hooks

If the request is to develop BLARCHY itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## Repository Sync Rule

When an end-user customization also requires a corresponding change in the
BLARCHY repository—such as a default, installer, migration, script, or asset
that should survive reinstall/update—make that source change as part of the
same task. After validation, automatically commit and push it to the
configured repository remote. Stage only files related to the task, preserve
unrelated worktree changes, and report the commit and push result. If the
remote or push is unavailable, leave the validated commit in place and report
the blocker.

## Privilege Escalation

For an interactive script or command run in a visible terminal, use `sudo` for
privileged work. BLARCHY may grant passwordless `sudo` access to particular
commands, and the terminal is the appropriate place to request a password
when one is needed.

Use `pkexec` only when the caller cannot interact with a terminal or cannot
enter a password there, such as a command launched by an agent or a graphical
background process. Do not replace `sudo` with `pkexec` merely because a
command changes system state.

## System Architecture

BLARCHY is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux** | Base OS | `/etc/`, `~/.config/` |
| **Hyprland** | Wayland compositor/WM | `~/.config/hypr/` |
| **BLARCHY shell** | Status bar + notifications (Quickshell) | `~/.config/omarchy/shell.json` |
| **Launcher** | Quickshell launcher | `~/.config/omarchy/shell.json` |
| **Alacritty** | Default terminal | `~/.config/alacritty/` |
| **BLARCHY OSD** | On-screen display | Quickshell plugin |

## Command Discovery

BLARCHY retains a single `omarchy` CLI that dispatches to all `omarchy-*`
binaries via `omarchy <group> <action>`. Always prefer this form — it is a
stable compatibility API. The underlying binaries remain safe to inspect.

```bash
# List every documented command and its summary
omarchy commands

# Show the commands inside a group
omarchy theme --help
omarchy refresh --help
omarchy restart --help

# Show help for a specific command (does not execute it)
omarchy theme set --help

# Machine-readable listing (binary, route, summary, args, aliases)
omarchy commands --json

# Read a command's source to understand it
cat $(which omarchy-theme-set)
```

### Command Groups

Run `omarchy --help` for the full list. The most common groups:

| Group | Purpose | Example |
|-------|---------|---------|
| `omarchy refresh` | Reset config to defaults (backs up first) | `omarchy refresh shell` |
| `omarchy restart` | Restart a service/app | `omarchy restart shell` |
| `omarchy toggle` | Toggle feature on/off | `omarchy toggle nightlight` |
| `omarchy theme` | Theme management | `omarchy theme set <name>` |
| `omarchy bar` | Bar layout and widgets | `omarchy bar move omarchy.clock --section right` |
| `omarchy plugin` | Manage/clone shell plugins | `omarchy plugin clone omarchy.clock` |
| `omarchy hook` | Install automation hooks | `omarchy hook install theme-set <script>` |
| `omarchy install` | Install optional software / setup integrations | `omarchy install --help` |
| `omarchy launch` | Launch apps | `omarchy launch browser` |
| `omarchy capture` | Screenshots and recordings | `omarchy capture screenshot` |
| `omarchy reminder` | Desktop notification reminders | `omarchy reminder 15 "Pickup Jack"` |
| `omarchy pkg` | Internal package helper retained for scripts | `omarchy pkg add <pkg>` |
| `omarchy setup` | Interactive setup wizards | `omarchy setup security fingerprint` |
| `yay` | Arch and AUR system updates | `yay -Syu` |

## Configuration Locations

### Hyprland (Window Manager)

BLARCHY configures Hyprland in Lua. User files are loaded after BLARCHY's
defaults, so overrides go here:

```
~/.config/hypr/
├── hyprland.lua       # Main config (loads BLARCHY defaults, then user files)
├── bindings.lua       # Keybindings
├── monitors.lua       # Display configuration
├── input.lua          # Keyboard/mouse settings
├── looknfeel.lua      # Appearance (gaps, borders, animations)
├── autostart.lua      # Startup applications
└── hyprsunset.conf    # Night light / blue light filter
```

**Key behaviors:**
- Hyprland auto-reloads on config save (no restart needed for most changes)
- Use `hyprctl reload` to force reload
- After ANY Hyprland config change, validate with `hyprctl reload` followed by `hyprctl configerrors`
- If `hyprctl configerrors` reports errors, address them and rerun validation until clean or until a real blocker is identified
- Use `omarchy refresh hyprland` to reset to defaults

### BLARCHY shell (Status Bar + Notifications)

The bar, notification daemon, settings panel, and assorted overlays all run
inside a single long-running Quickshell process (`omarchy-shell`).

```
~/.config/omarchy/shell.json             # User overrides: bar, plugins, idle
~/.config/omarchy/plugins/<plugin-id>/   # User-owned shell plugins
$OMARCHY_PATH/config/omarchy/shell.json  # Canonical defaults
```

The shell hot-reloads `shell.json` on save — no restart needed for layout
changes. `idle.screensaver` and `idle.lock` are seconds since user idle began.

To customize a built-in bar widget, never edit `$OMARCHY_PATH/shell/plugins/`.
Clone it into the user plugin directory instead:

```bash
omarchy plugin clone omarchy.workspaces
# Edit ~/.config/omarchy/plugins/local.workspaces/; saved changes reload automatically.
```

**Commands:** `omarchy restart shell`, `omarchy refresh shell`

### Terminals

```
~/.config/alacritty/alacritty.toml
```

**Command:** `omarchy restart terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `~/.config/fastfetch/config.jsonc` |
| lazygit | `~/.config/lazygit/config.yml` |
| starship | `~/.config/starship.toml` |
| git | `~/.config/git/config` |

## Safe Customization Patterns

### Pattern 1: Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/hypr/bindings.lua

# 2. Backup before changes
cp ~/.config/hypr/bindings.lua ~/.config/hypr/bindings.lua.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Hyprland: auto-reloads on save, but MUST validate with `hyprctl reload` and `hyprctl configerrors`
# - BLARCHY shell: shell.json hot-reloads; use `omarchy-shell shell rescanPlugins` for plugin/widget code changes
# - Launcher: restart with `omarchy restart shell`
# - Terminals: MUST restart with `omarchy restart terminal`
```

### Pattern 2: Make a new theme

1. Create a directory under ~/.config/omarchy/themes.
2. See how an existing theme is done via /usr/local/share/blarchy/themes/catppuccin.
3. Download a matching background (or several) from the internet and put them in ~/.config/omarchy/themes/[name-of-new-theme]
4. When done with the theme, run `omarchy theme set "Name of new theme"`

### Pattern 3: Use Hooks for Automation

Hooks live in `~/.config/omarchy/hooks/<name>.d/` — one directory per event,
holding any number of independent scripts. Install with
`omarchy hook install <name> <script>` (copies the script in and makes it
executable):

```
~/.config/omarchy/hooks/
├── battery-low.d/          # Low battery (percentage in $1)
├── font-set.d/             # After font change (font name in $1)
├── post-boot.d/            # After the desktop starts
├── post-update.d/          # Compatibility hooks; not run by yay
├── pre-refresh-pacman.d/   # Runs only with explicit `omarchy refresh pacman`
└── theme-set.d/            # After theme change (theme slug in $1)
```

Example hook script:
```bash
#!/bin/bash
THEME_NAME=$1
echo "Theme changed to: $THEME_NAME"
# Add custom actions here
```

## Terminal Steam game launchers

When a user asks for a direct terminal command that launches a Steam game, use
the shared `omarchy launch steam-game` helper and create a thin, user-owned
wrapper command. Do not hardcode a Steam library path, a Steam executable path,
or a specific game name in the shared helper.

The wrapper should use the user's chosen command name and the game's numeric
Steam AppID:

```bash
#!/bin/bash
exec omarchy launch steam-game <steam-app-id>
```

Install the wrapper at `~/.local/bin/<command-name>` and make it executable.
Confirm that `~/.local/bin` is on the user's PATH; add the shell integration
only if it is missing.

The shared helper starts Steam with `steam -applaunch <steam-app-id>` in a
detached session. On Hyprland it records the active window before launching,
checks that the window belongs to the invoking shell's process tree, and then
closes that exact terminal through the current Lua dispatcher. If the command
is run outside Hyprland or the originating window cannot be identified, it must
still launch the game without closing an unrelated window.

Validate a generated wrapper with `bash -n`, verify `command -v <command-name>`
in a fresh shell, and run the command from the intended terminal/workspace.

### Pattern 4: Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
omarchy refresh shell
omarchy refresh hyprland

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from $OMARCHY_PATH/config/
# 3. Restarts the component
```

## Common Tasks

### Themes

```bash
omarchy theme list              # Show available themes
omarchy theme current           # Show current theme
omarchy theme set <name>        # Apply theme ("Tokyo Night" and "tokyo-night" both work)
omarchy theme bg next           # Cycle background
omarchy theme install <url>     # Install from git repo
```

### Keybindings

Edit `~/.config/hypr/bindings.lua`. Format:
```lua
o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")
o.bind("SUPER + B", "Browser", { launch = "firefox" })  -- launch wraps with uwsm-app
```

View current bindings: `omarchy menu keybindings --print`

**IMPORTANT: When re-binding an existing key:**

1. First check existing bindings: `omarchy menu keybindings --print`
2. If the key is already bound, you MUST call `hl.unbind(...)` BEFORE the new `o.bind(...)`
3. Inform the user what the key was previously bound to

Example - rebinding SUPER+F (which opens Files by default):
```lua
-- Unbind existing SUPER+F (was: Files)
hl.unbind("SUPER + F")
-- New binding for file manager
o.bind("SUPER + F", "File manager", { launch = "nautilus" })
```

Always tell the user: "Note: SUPER+F was previously bound to Files. I've added an unbind to override it."

### Display/Monitors

Edit `~/.config/hypr/monitors.lua`. Format:
```lua
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "1920x0", scale = 1 })
```

List monitors and supported modes: `hyprctl monitors all`

### Window Rules

**CRITICAL: Hyprland window rules syntax changes frequently between versions.**

Before writing any window rules, consult the installed Hyprland version and
current official documentation at https://wiki.hypr.land/Configuring/Window-Rules/.
Do not rely on memorized window-rule syntax; it changes between versions.

Window rules go in `~/.config/hypr/hyprland.lua` or a required Lua module.
Prefer BLARCHY's retained `o.window(match, rules)` helper — see examples in
`$OMARCHY_PATH/default/hypr/windows.lua`.

### Fonts

```bash
omarchy font list               # Available fonts
omarchy font current            # Current font
omarchy font set <name>         # Change font
```

### System

```bash
yay -Syu                       # Full Arch and AUR package update
omarchy version                 # Show the retained source version
omarchy debug --no-sudo --print # Debug info (ALWAYS use these flags)
omarchy system lock             # Lock screen
omarchy system shutdown         # Shutdown
omarchy system reboot           # Reboot
```

**IMPORTANT:** Always run `omarchy debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
omarchy debug --no-sudo --print

# Reset specific config to defaults
omarchy refresh <app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. `omarchy refresh config hypr/hyprland.lua` will refresh ~/.config/hypr/hyprland.lua
omarchy refresh config <config-file>

# Full reinstall of configs (nuclear option)
omarchy reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a retained BLARCHY `omarchy` command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `/usr/local/share/blarchy/`
3. **Is it a theme customization?** Create a NEW custom theme directory
4. **Is it automation?** Use `omarchy hook install` and the hook `.d` directories
5. **Is it a normal package install?** Use `yay -S <pkgs...>` so official and
   AUR packages follow normal Arch behavior. Use `omarchy pkg` only when
   maintaining a BLARCHY script that needs its package abstraction.
6. **Is it built-in shell/plugin code?** Clone it with `omarchy plugin clone`; never edit the packaged copy
7. **Unsure if command exists?** Run `omarchy commands` (or `omarchy <group> --help` for one group)

### Reminder Requests

When the user asks to set a reminder, use `omarchy reminder <minutes> [message]` directly. Convert natural language durations to minutes and title-case short reminder labels when appropriate.

```bash
omarchy reminder 15 "Pickup Jack"
omarchy reminder 60 "Check laundry"
omarchy reminder show
omarchy reminder clear
```

## Out of Scope

This skill intentionally does not cover BLARCHY source development. Do not use this skill for:
- Editing files in `/usr/local/share/blarchy/` (`bin/`, `config/`, `default/`, `shell/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `omarchy dev ...` commands

## Example Requests

- "Change my theme to catppuccin" -> `omarchy theme set catppuccin`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, call `hl.unbind` if needed, then `o.bind` in `~/.config/hypr/bindings.lua`
- "Configure my external monitor" -> Edit `~/.config/hypr/monitors.lua`
- "Make the window gaps smaller" -> Edit `~/.config/hypr/looknfeel.lua`
- "Set up night light to turn on at sunset" -> `omarchy toggle nightlight` or edit `~/.config/hypr/hyprsunset.conf`
- "Set a reminder to pickup jack in 15 minutes" -> `omarchy reminder 15 "Pickup Jack"`
- "Show my reminders" -> `omarchy reminder show`
- "Clear all reminders" -> `omarchy reminder clear`
- "Customize the catppuccin theme colors" -> Create `~/.config/omarchy/themes/catppuccin-custom/` by copying from stock, then edit
- "Run a script every time I change themes" -> Install it with `omarchy hook install theme-set <script>`
- "Change how workspace labels are rendered" -> Clone `omarchy.workspaces`, which switches the bar to `local.workspaces`, then edit the clone
- "Lock after ten minutes" -> Set `idle.lock` to `600` in `~/.config/omarchy/shell.json`
- "Reset shell/bar to defaults" -> `omarchy refresh shell`
