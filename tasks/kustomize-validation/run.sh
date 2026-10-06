#!/usr/bin/env bash
# Recursively run kustomize build in Docker for every Kustomization in a folder.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="${BUILD_REPOSITORY_LOCALPATH:-${BUILD_SOURCESDIRECTORY:-$PWD}}"
IMAGE="${YAML_GUARD_IMAGE:-intershophub/yaml-guard:1.0.0}"
TEST_FOLDER="${SOURCE_ROOT}/flux-ops/clusters"
CONFIG_SCRIPT="${SCRIPT_DIR}/config/config.sh"

usage() {
  cat <<EOF
Usage: $0 [--image IMAGE] [--test-folder FOLDER]

Options:
  --image IMAGE             Docker image (default: ${IMAGE})
  --test-folder FOLDER      Folder to check (default: ${TEST_FOLDER})
  -h, --help                Show this help
EOF
}

# Convert paths to Docker-compatible format on Windows (Cygwin/MSYS).
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
if [[ ! -f "${CONFIG_SCRIPT}" ]]; then
  echo "ERROR: Kustomize validation config not found: ${CONFIG_SCRIPT}" >&2
  exit 2
fi
# Convert TEST_FOLDER to an absolute path.
TEST_FOLDER="$(cd -- "${TEST_FOLDER}" && pwd)"
CONFIG_SCRIPT="$(cd -- "$(dirname -- "${CONFIG_SCRIPT}")" && pwd)/$(basename -- "${CONFIG_SCRIPT}")"

# Convert paths to Docker-compatible format on Windows (Cygwin/MSYS).
DOCKER_TEST_FOLDER="$(docker_path "$TEST_FOLDER")"
DOCKER_CONFIG_SCRIPT="$(docker_path "$CONFIG_SCRIPT")"

MSYS_NO_PATHCONV=1 docker run --rm \
  --mount "type=bind,source=${DOCKER_TEST_FOLDER},target=/workspace/test-folder,readonly" \
  --mount "type=bind,source=${DOCKER_CONFIG_SCRIPT},target=/config/config.sh,readonly" \
  --workdir /workspace/test-folder \
  --env TEST_FOLDER=/workspace/test-folder \
  --entrypoint bash \
  "${IMAGE}" \
  -c 'set -o pipefail; tr -d "\r" < /config/config.sh | bash'
