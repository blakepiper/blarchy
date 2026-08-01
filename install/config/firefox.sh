# Firefox is a base package in BLARCHY, so deploy policy during system setup
# rather than relying on the optional browser installer.
install -d -m 0755 /usr/lib/firefox/distribution
install -m 0644 "$OMARCHY_PATH/default/firefox/policies.json" \
  /usr/lib/firefox/distribution/policies.json
