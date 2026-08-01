# Retained ISO/package setup path. BLARCHY's supported standalone installer
# deploys the same policy under /etc/firefox/policies instead.
install -d -m 0755 /usr/lib/firefox/distribution
install -m 0644 "$OMARCHY_PATH/default/firefox/policies.json" \
  /usr/lib/firefox/distribution/policies.json
