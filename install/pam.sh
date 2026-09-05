# Optional keyring hooks supplement, never replace, the installed PAM stack.
# shellcheck shell=bash

blarchy_configure_keyring_pam() {
  local pam_dir="$1"
  local entry service type options
  for entry in 'greetd auth' 'greetd session auto_start' 'passwd password'; do
    read -r service type options <<<"$entry"
    if [[ ! -f $pam_dir/$service ]]; then
      echo "Error: missing PAM configuration: $pam_dir/$service" >&2
      return 1
    fi
    if ! grep -qE "^[[:space:]]*-?${type}[[:space:]].*pam_gnome_keyring\\.so([[:space:]]|$)" "$pam_dir/$service"; then
      printf '\n%s optional pam_gnome_keyring.so%s\n' "$type" "${options:+ $options}" >>"$pam_dir/$service"
    fi
  done
}
