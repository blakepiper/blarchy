# Require password-based SDDM logins. The ISO may seed an autologin file before
# BLARCHY setup runs, so install a later config that explicitly disables it.
install -D -m 0644 "$OMARCHY_PATH/etc/sddm.conf.d/20-login.conf" \
  /etc/sddm.conf.d/99-blarchy-login.conf

# Prevent password-based SDDM logins from creating an encrypted login keyring
# that conflicts with Omarchy's default keyring behavior.
if [[ -f /etc/pam.d/sddm ]]; then
  sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
  sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
fi
