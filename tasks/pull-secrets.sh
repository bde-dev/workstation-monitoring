#!/bin/bash
#MISE description="Log in to Azure (service principal) and pull the Cloudflare Access token from Key Vault into .env"
set -euo pipefail

: "${AZURE_TENANT_ID:?set in mise.toml [env]}"
: "${AKV_VAULT_NAME:?set in mise.toml [env]}"
: "${CLIENT_ID:?set in mise.toml [env]}"
: "${CLIENT_SECRET:?export CLIENT_SECRET or set it in .env}"

ENV_FILE=".env"

echo "Logging in to Azure with the service principal..."
az login --service-principal \
  --username "$CLIENT_ID" \
  --password "$CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" \
  --output none
echo "✓ az authenticated"

upsert() {
  local key=$1 val=$2
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    grep -v "^${key}=" "$ENV_FILE" >"$ENV_FILE.tmp"
    mv "$ENV_FILE.tmp" "$ENV_FILE"
  fi
  printf '%s=%s\n' "$key" "$val" >>"$ENV_FILE"
}

pull() {
  local kv_name=$1 env_var=$2 val
  # Fails loud under `set -e` if the secret is absent from the vault — .env is left
  # unchanged for that key rather than populated with an empty value.
  val=$(az keyvault secret show --vault-name "$AKV_VAULT_NAME" --name "$kv_name" --query value -o tsv)
  upsert "$env_var" "$val"
  echo "✓ $env_var  ← $kv_name"
}

pull workstation-otel-cf-access-client-id     CF_ACCESS_CLIENT_ID
pull workstation-otel-cf-access-client-secret CF_ACCESS_CLIENT_SECRET

echo ""
echo "✅ Pulled the Cloudflare Access token from Key Vault '$AKV_VAULT_NAME' into $ENV_FILE."
echo "   Start the collector with:  docker compose up -d"
