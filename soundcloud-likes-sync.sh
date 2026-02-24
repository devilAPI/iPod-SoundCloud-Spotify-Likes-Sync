#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "$SCRIPT_DIR/.env"; set +a

: "${SOUNDCLOUD_LIKES_URL:?Set SOUNDCLOUD_LIKES_URL in .env}"
: "${OUTPUT_FOLDER:?Set OUTPUT_FOLDER in .env}"

mkdir -p "$OUTPUT_FOLDER/SoundCloud"
cd "$OUTPUT_FOLDER/SoundCloud"

yt-dlp \
  --format "bestaudio/best" \
  --extract-audio \
  --audio-quality 0 \
  --embed-metadata \
  --embed-thumbnail \
  --convert-thumbnails jpg \
  --download-archive soundcloud_likes.archive \
  --ignore-errors \
  --no-overwrites \
  --continue \
  --restrict-filenames \
  -o "%(uploader)s - %(title)s [%(id)s].%(ext)s" \
  "$SOUNDCLOUD_LIKES_URL"