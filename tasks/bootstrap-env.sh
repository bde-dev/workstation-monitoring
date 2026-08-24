#!/bin/bash
#MISE description="Ensure .env holds each required key not already provided (via .env or shell env)"
set -euo pipefail

ENV_FILE=".env"
# CLIENT_SECRET (Azure SP) is the one value you supply — export it or fill it in
# .env. CF_ACCESS_* are pulled from Key Vault by `mise run pull-secrets`.
KEYS=(CLIENT_SECRET CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET)

[ -f "$ENV_FILE" ] || : > "$ENV_FILE"

# WORKSTATION_NAME defaults to the hostname unless already provided (shell or .env).
if ! grep -q "^WORKSTATION_NAME=" "$ENV_FILE" && [ -z "$(printenv WORKSTATION_NAME 2>/dev/null || true)" ]; then
  printf 'WORKSTATION_NAME=%s\n' "$(hostname)" >> "$ENV_FILE"
fi

added=0
for key in "${KEYS[@]}"; do
  grep -q "^${key}=" "$ENV_FILE" && continue
  [ -n "$(printenv "$key" 2>/dev/null || true)" ] && continue
  printf '%s=\n' "$key" >> "$ENV_FILE"
  added=$((added + 1))
done

echo "✓ .env ready ($added empty key(s) added; existing and shell-provided keys left untouched)"
echo "  CLIENT_SECRET is the only value you supply — export it, or fill it in .env."
echo "  CF_ACCESS_* are filled by:  mise run pull-secrets"
