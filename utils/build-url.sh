#!/usr/bin/env bash
set -euo pipefail

# Script-Ordner bestimmen
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# .env laden
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
else
  echo "Fehler: .env nicht gefunden"
  exit 1
fi

: "${SPOTIFY_CLIENT_ID:?SPOTIFY_CLIENT_ID fehlt}"
: "${SPOTIFY_REDIRECT_URI:?SPOTIFY_REDIRECT_URI fehlt}"
: "${SPOTIFY_SCOPES:?SPOTIFY_SCOPES fehlt}"

AUTH_URL="https://accounts.spotify.com/authorize?response_type=code&client_id=$SPOTIFY_CLIENT_ID&scope=$(printf %s "$SPOTIFY_SCOPES" | jq -sRr @uri)&redirect_uri=$(printf %s "$SPOTIFY_REDIRECT_URI" | jq -sRr @uri)"

echo
echo "Öffne diese URL im Browser:"
echo
echo "$AUTH_URL"
echo