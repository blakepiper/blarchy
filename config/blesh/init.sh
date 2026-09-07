# Faint inline suggestions from history and completion, without a background.
blehook/eval-after-load complete 'bleopt complete_auto_complete=1 complete_auto_history=1'
ble-face -s auto_complete fg=242,bg=none

# Scoped for ~/.local/bin/dev: while it's actively setting up a prettymux
# workspace it touches this marker, letting freshly spawned panes auto-run
# their pasted command. ble.sh's paste widget only ever inserts pasted text
# (see ble/widget/bracketed-paste.proc upstream) - rebinding a key has no
# effect on paste-delivered content, since it never goes through the normal
# per-key dispatch. The paste_begin widget itself has to be swapped for one
# that also runs the line once the paste finishes inserting. Ignored if
# stale so a crashed dev run can't leave this on permanently.
_dev_marker=/run/user/$(id -u)/dev-script-active
if [[ -e $_dev_marker ]]; then
  _dev_marker_age=$(( $(date +%s) - $(stat -c %Y "$_dev_marker" 2>/dev/null || echo 0) ))
  if (( _dev_marker_age >= 0 && _dev_marker_age < 30 )); then
    function ble/widget/dev-auto-paste {
      ble/widget/bracketed-paste
      _ble_edit_bracketed_paste_proc=ble/widget/dev-auto-paste.proc
    }
    function ble/widget/dev-auto-paste.proc {
      # prettymux-open --exec sends the command as ONE paste, then a
      # SEPARATE second paste containing only a bare newline (char code 10)
      # as its own "press enter" signal. Without this guard, the first
      # paste correctly runs the command, then the second paste re-fires
      # this same widget and submits an empty line right after - a stray
      # blank prompt in every pane dev touches.
      local only_newline=1 c
      for c in "$@"; do
        if [[ $c != 10 && $c != 13 ]]; then
          only_newline=0
          break
        fi
      done
      (( only_newline )) && (( $# )) && return 0
      ble/widget/bracketed-paste.proc "$@"
      ble/widget/accept-line
    }
    ble-bind -f paste_begin dev-auto-paste
  fi
fi
unset _dev_marker _dev_marker_age
