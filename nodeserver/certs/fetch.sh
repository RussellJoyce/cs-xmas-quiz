#!/bin/sh
set -e
cd "$(dirname "$0")"

# Manual DNS challenge, for when the Cloudflare plugin is not available.
# The domain comes from config.json, same as renew-cert.sh and server.js.
DOMAIN=$(node -p "require('../config.json').domain")

echo "Fetching certificate for $DOMAIN"

certbot certonly --manual --register-unsafely-without-email \
  --logs-dir . --config-dir . --work-dir . \
  --preferred-challenges dns -d "$DOMAIN"
