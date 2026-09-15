# Topbar menus

The menus extend Seafoam Dusk: charcoal (#171c1b), muted secondary text
(#8fa9a0), and seafoam (#9fe3c4) for important values and selected controls.
The existing Waybar and GTK layer-shell implementation remain the foundation.

## Directions considered

- Compact control tiles: [Eww control center](https://www.reddit.com/r/unixporn/comments/vs46w3/).
  Group related controls and keep secondary actions visually quiet.
- Larger touch controls: [Material-inspired Eww](https://www.reddit.com/r/unixporn/comments/ygn0s5/).
  Strong grouping, but oversized tiles would overwhelm this desktop's slim bar.
- Subdued forest palette: [Everforest desktop](https://www.reddit.com/r/unixporn/comments/1ngy8xi/).
  Keep the low-contrast surfaces and restrained accent treatment in our own palette.

## Selected design

Compact charcoal panels with 18px insets, 12px corners, small section labels,
and explicit hover, keyboard-focus, and selected states. Refresh and close
actions are quiet. Error messages appear when needed without a permanent
instruction footer.

Sound uses a seafoam slider with a visible handle and device rows with readable
port names above their hardware descriptions. Battery gives the percentage
priority, adds a charge track, and places power profiles in one horizontal row.
Active profiles retain normal contrast rather than appearing disabled.

Validation: repository smoke suite and a native GTK offscreen rendering with
the current machine's audio and battery data. Full desktop acceptance remains
the disposable Arch VM workflow described in AGENTS.md.
