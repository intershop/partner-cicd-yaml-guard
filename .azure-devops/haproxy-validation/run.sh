#!/usr/bin/env bash
# Run HAProxy validation against a configurable folder.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
IMAGE="${HAPROXY_VALIDATION_IMAGE:-intershophub/yaml-guard:1.0.0}"
TEST_FOLDER="${REPO_ROOT}"
VALIDATION_SCRIPT="${SCRIPT_DIR}/config/config.py"

usage() {
  cat <<EOF
Usage: $0 [--image IMAGE] [--test-folder FOLDER]

Options:
  --image IMAGE             Python 3 Docker image (default: ${IMAGE})
  --test-folder FOLDER      Folder to check (default: ${TEST_FOLDER})
  -h, --help                Show this help
EOF
}

docker_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

while (($# > 0)); do
  case "$1" in
    --image)
      if (($# < 2)); then
        echo "ERROR: --image requires a value." >&2
        exit 2
      fi
      IMAGE="$2"
      shift 2
      ;;
    --test-folder)
      if (($# < 2)); then
        echo "ERROR: --test-folder requires a value." >&2
        exit 2
      fi
      TEST_FOLDER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is not available. Install and start Docker to run this check locally." >&2
  exit 127
fi

if [[ ! -d "${TEST_FOLDER}" ]]; then
  echo "ERROR: Test folder not found: ${TEST_FOLDER}" >&2
  exit 2
fi
TEST_FOLDER="$(cd -- "${TEST_FOLDER}" && pwd)"

if [[ ! -f "${VALIDATION_SCRIPT}" ]]; then
  echo "ERROR: HAProxy validation script not found: ${VALIDATION_SCRIPT}" >&2
  exit 2
fi

DOCKER_TEST_FOLDER="$(docker_path "$TEST_FOLDER")"
DOCKER_VALIDATION_SCRIPT="$(docker_path "$VALIDATION_SCRIPT")"

MSYS_NO_PATHCONV=1 docker run --rm \
  --mount "type=bind,source=${DOCKER_TEST_FOLDER},target=/workspace,readonly" \
  --mount "type=bind,source=${DOCKER_VALIDATION_SCRIPT},target=/config/config.py,readonly" \
  --workdir /workspace \
  --entrypoint python3 \
  "${IMAGE}" \
  /config/config.py --root /workspace
