set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "$SCRIPT_DIR/.env"; set +a

: "${OUTPUT_FOLDER:?Set OUTPUT_FOLDER in .env}"
: "${ENABLE_YOUTUBE_SYNC:?Set ENABLE_YOUTUBE_SYNC in .env}"
: "${ENABLE_SOUNDCLOUD_SYNC:?Set ENABLE_SOUNDCLOUD_SYNC in .env}"
: "${ENABLE_SPOTIFY_LIKED_SYNC:?Set ENABLE_SPOTIFY_LIKED_SYNC in .env}"

[[ "$ENABLE_SPOTIFY_LIKED_SYNC" == "true" ]] && ./spotify-likes-sync.sh
[[ "$ENABLE_SOUNDCLOUD_SYNC" == "true" ]] && ./soundcloud-likes-sync.sh
[[ "$ENABLE_YOUTUBE_SYNC" == "true" ]] && ./youtube-sync.sh

[[ "$ENABLE_IPOD_SYNC" == "true" ]] && rsync -av "$OUTPUT_FOLDER"/ "$IPOD_OUT"/