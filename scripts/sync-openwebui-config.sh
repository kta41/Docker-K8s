#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${OPENWEBUI_ENV_FILE:-$ROOT_DIR/.env}"

usage() {
  cat >&2 <<'EOF'
Usage: sync-openwebui-config.sh [--dry-run] [--env-file PATH] CONFIG_REPOSITORY

Environment:
  OPENWEBUI_URL       Open WebUI base URL, including the scheme
  OPENWEBUI_API_KEY   Administrative API key
EOF
  exit 2
}

dry_run=false
while (($#)); do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --env-file)
      (($# >= 2)) || usage
      ENV_FILE=$2
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done
[[ $# -eq 1 ]] || usage
config_repo=$1

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${OPENWEBUI_URL:?OPENWEBUI_URL is required}"
: "${OPENWEBUI_API_KEY:?OPENWEBUI_API_KEY is required}"

command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
[[ -d "$config_repo/models" ]] || {
  echo "Missing models directory: $config_repo/models" >&2
  exit 1
}

payload="$(
  CONFIG_REPO="$config_repo" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["CONFIG_REPO"]) / "models"
models = []
for path in sorted(root.glob("*.json")):
    with path.open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise SystemExit(f"{path}: expected a JSON object")
    if not value.get("id"):
        raise SystemExit(f"{path}: missing required model id")
    models.append(value)
print(json.dumps({"models": models}, ensure_ascii=False, separators=(",", ":")))
PY
)"

if [[ "$dry_run" == true ]]; then
  python3 -m json.tool <<<"$payload" >/dev/null
  echo "Validated ${#payload} bytes; no changes sent."
  exit 0
fi

curl --fail-with-body --silent --show-error \
  --request POST \
  --header "Authorization: Bearer ${OPENWEBUI_API_KEY}" \
  --header "Content-Type: application/json" \
  --data "$payload" \
  "${OPENWEBUI_URL%/}/api/v1/models/sync"

printf '\nOpen WebUI models reconciled from %s\n' "$config_repo"
