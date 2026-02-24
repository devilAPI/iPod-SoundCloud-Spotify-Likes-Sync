#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "$SCRIPT_DIR/.env"; set +a

: "${YOUTUBE_PLAYLIST_URL:?Set YOUTUBE_PLAYLIST_URL in .env}"
: "${OUTPUT_FOLDER:?Set OUTPUT_FOLDER in .env}"

mkdir -p "$OUTPUT_FOLDER/YouTube"
cd "$OUTPUT_FOLDER/YouTube"

yt-dlp \
  --format "bestaudio/best" \
  --extract-audio \
  --audio-quality 0 \
  --embed-metadata \
  --embed-thumbnail \
  --convert-thumbnails jpg \
  --download-archive youtube_playlist.archive \
  --ignore-errors \
  --no-overwrites \
  --continue \
  --restrict-filenames \
  -o "%(uploader)s - %(title)s [%(id)s].%(ext)s" \
  "$YOUTUBE_PLAYLIST_URL"