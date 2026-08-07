#!/bin/bash
set -e
cd "$(dirname "$0")"

# The domain comes from config.json so that this and server.js cannot disagree about which
# certificate is being fetched. node is already a dependency, so no jq needed.
DOMAIN=$(node -p "require('./config.json').domain")

echo "Renewing certificate for $DOMAIN"

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials cloudflare.ini \
  -d "$DOMAIN" \
  --config-dir ./certs \
  --work-dir ./certs \
  --logs-dir ./certs \
  --key-type ecdsa
