#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "$SCRIPT_DIR/.env"; set +a

: "${OUTPUT_FOLDER:?Set OUTPUT_FOLDER in .env}"
: "${ENABLE_YOUTUBE_SYNC:?Set ENABLE_YOUTUBE_SYNC in .env}"
: "${ENABLE_SOUNDCLOUD_SYNC:?Set ENABLE_SOUNDCLOUD_SYNC in .env}"
: "${ENABLE_SPOTIFY_LIKED_SYNC:?Set ENABLE_SPOTIFY_LIKED_SYNC in .env}"

[[ "${ENABLE_SPOTIFY_LIKED_SYNC:-false}" == "true" ]] && echo "Starting Spotify Sync..." && "$SCRIPT_DIR/spotify-likes-sync.sh"
[[ "${ENABLE_SOUNDCLOUD_SYNC:-false}" == "true" ]] && echo "Starting SoundCloud Sync..." && "$SCRIPT_DIR/soundcloud-likes-sync.sh"
[[ "${ENABLE_YOUTUBE_SYNC:-false}" == "true" ]] && echo "Starting YouTube Sync..." && "$SCRIPT_DIR/youtube-sync.sh"

[[ "${ENABLE_IPOD_SYNC:-false}" == "true" ]] && echo "Starting iPod Sync..." && rsync -a --ignore-existing --info=stats2,progress2 "$OUTPUT_FOLDER"/ "$IPOD_OUT"/

# ---- Remote Sync (SFTP via lftp mirror) ----
if [[ "${ENABLE_SFTP_SYNC:-false}" == "true" ]]; then
  echo "Starting SFTP Sync (lftp)..."
  : "${SFTP_HOST:?Set SFTP_HOST in .env}"
  : "${SFTP_USER:?Set SFTP_USER in .env}"
  : "${SFTP_PASS:?Set SFTP_PASS in .env}"
  : "${SFTP_DIR:?Set SFTP_DIR in .env}"

  SFTP_PORT="${SFTP_PORT:-22}"

  # optional: delete (Mirror)
  LFTP_DELETE=()
  if [[ "${SFTP_DELETE:-false}" == "true" ]]; then
    LFTP_DELETE+=(--delete)
  fi

  # Ensure output folder exists
  [[ -d "$OUTPUT_FOLDER" ]] || { echo "OUTPUT_FOLDER does not exist: $OUTPUT_FOLDER" >&2; exit 1; }

  # Normalize paths
  LOCAL_DIR="${OUTPUT_FOLDER%/}"
  REMOTE_DIR="${SFTP_DIR%/}"

  # Notes:
  # - mirror -R uploads (reverse)
  # - --only-newer avoids re-uploading unchanged files (based on timestamps)
  # - --parallel can speed up many small files (optional)
  lftp -u "$SFTP_USER","$SFTP_PASS" -p "$SFTP_PORT" "sftp://$SFTP_HOST" <<EOF
set sftp:auto-confirm yes
set net:max-retries 2
set net:reconnect-interval-base 2
set cmd:fail-exit true
mirror -R --verbose --only-newer ${LFTP_DELETE[*]} "$LOCAL_DIR" "$REMOTE_DIR"
bye
EOF
fi