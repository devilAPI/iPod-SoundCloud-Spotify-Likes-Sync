#!/usr/bin/env bash
set -euo pipefail

# Script-Ordner finden (egal von wo du es startest)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# .env laden, falls vorhanden
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/.env"
  set +a
else
  echo "Fehler: $SCRIPT_DIR/.env nicht gefunden"
  exit 1
fi

# ====== Konfiguration (als ENV setzen, siehe unten) ======
: "${SPOTIFY_CLIENT_ID:?}"
: "${SPOTIFY_CLIENT_SECRET:?}"
: "${SPOTIFY_REFRESH_TOKEN:?}"

PLAYLIST_NAME="${SPOTIFY_PLAYLIST_NAME:-Liked Songs (Mirror)}"

api() {
  curl -sS -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" "$@"
}

# 1) Access Token per Refresh holen
TOKEN_JSON="$(curl -sS -X POST https://accounts.spotify.com/api/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=$SPOTIFY_REFRESH_TOKEN&client_id=$SPOTIFY_CLIENT_ID&client_secret=$SPOTIFY_CLIENT_SECRET")"

ACCESS_TOKEN="$(jq -r '.access_token // empty' <<<"$TOKEN_JSON")"
if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Konnte access_token nicht holen. Antwort:"
  echo "$TOKEN_JSON" | jq .
  exit 1
fi

# 2) User-ID holen
ME_JSON="$(api https://api.spotify.com/v1/me)"
USER_ID="$(jq -r '.id' <<<"$ME_JSON")"

# 3) Playlist finden oder erstellen
#    (wir suchen in deinen Playlists nach dem Namen; bei vielen Playlists wird gepaged)
PLAYLIST_ID=""
NEXT="https://api.spotify.com/v1/me/playlists?limit=50"
while [[ -n "$NEXT" && "$NEXT" != "null" ]]; do
  PAGE="$(api "$NEXT")"
  PLAYLIST_ID="$(jq -r --arg name "$PLAYLIST_NAME" '.items[] | select(.name==$name) | .id' <<<"$PAGE" | head -n1 || true)"
  [[ -n "$PLAYLIST_ID" ]] && break
  NEXT="$(jq -r '.next' <<<"$PAGE")"
done

if [[ -z "$PLAYLIST_ID" ]]; then
  CREATE_JSON="$(api -X POST "https://api.spotify.com/v1/users/$USER_ID/playlists" \
    -d "$(jq -n --arg name "$PLAYLIST_NAME" --argjson pub "$PLAYLIST_PUBLIC" '{name:$name, public:$pub}')")"
  PLAYLIST_ID="$(jq -r '.id' <<<"$CREATE_JSON")"
  echo "Playlist erstellt: $PLAYLIST_ID"
else
  echo "Playlist gefunden: $PLAYLIST_ID"
fi

# 4) Alle Liked Songs (URIs) holen
LIKED_URIS=()
NEXT="https://api.spotify.com/v1/me/tracks?limit=50"
while [[ -n "$NEXT" && "$NEXT" != "null" ]]; do
  PAGE="$(api "$NEXT")"
  mapfile -t URIS < <(jq -r '.items[].track.uri' <<<"$PAGE")
  for u in "${URIS[@]}"; do
    [[ "$u" == "null" || -z "$u" ]] && continue
    LIKED_URIS+=("$u")
  done
  NEXT="$(jq -r '.next' <<<"$PAGE")"
done

TOTAL="${#LIKED_URIS[@]}"
echo "Liked Songs: $TOTAL"

# 5) Playlist spiegeln:
#    - Replace mit ersten 100
#    - Add restliche in 100er batches
to_json_array() { printf '%s\n' "$@" | jq -R . | jq -s .; }

if [[ "$TOTAL" -eq 0 ]]; then
  # Playlist leeren
  api -X PUT "https://api.spotify.com/v1/playlists/$PLAYLIST_ID/tracks" \
    -d '{"uris":[]}' >/dev/null
  echo "Playlist geleert (keine Liked Songs)."
  exit 0
fi

FIRST=("${LIKED_URIS[@]:0:100}")
FIRST_JSON="$(to_json_array "${FIRST[@]}")"

api -X PUT "https://api.spotify.com/v1/playlists/$PLAYLIST_ID/tracks" \
  -d "$(jq -n --argjson uris "$FIRST_JSON" '{uris:$uris}')" >/dev/null
echo "Replace: ${#FIRST[@]}"

# Rest adden
i=100
while [[ $i -lt $TOTAL ]]; do
  BATCH=("${LIKED_URIS[@]:i:100}")
  BATCH_JSON="$(to_json_array "${BATCH[@]}")"
  api -X POST "https://api.spotify.com/v1/playlists/$PLAYLIST_ID/tracks" \
    -d "$(jq -n --argjson uris "$BATCH_JSON" '{uris:$uris}')" >/dev/null
  echo "Add: ${#BATCH[@]}"
  i=$((i+100))
done

echo "Fertig. Playlist: https://open.spotify.com/playlist/$PLAYLIST_ID"
echo "Starte Download..."
mkdir -p "$OUTPUT_FOLDER/Spotify"
spotiflac-cli d https://open.spotify.com/playlist/$PLAYLIST_ID -o $OUTPUT_FOLDER/Spotify