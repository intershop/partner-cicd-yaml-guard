#!/usr/bin/env bash
# Run yamllint in Docker against a configurable folder using the selected config.
set +e
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
IMAGE="${YAML_GUARD_IMAGE:-intershophub/yaml-guard:1.0.0}"
TEST_FOLDER="${REPO_ROOT}/clusters"
LINT_CONFIG="${SCRIPT_DIR}/.yamllint"

usage() {
  cat <<EOF
Usage: $0 [--image IMAGE] [--test-folder FOLDER] [--config FILE]

Options:
  --image IMAGE             Docker image (default: ${IMAGE})
  --test-folder FOLDER      Folder to check (default: ${TEST_FOLDER})
  --config FILE             yamllint config (default: ${LINT_CONFIG})
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
    --config)
      if (($# < 2)); then
        echo "ERROR: --config requires a value." >&2
        exit 2
      fi
      LINT_CONFIG="$2"
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
# Convert TEST_FOLDER to an absolute path.
TEST_FOLDER="$(cd -- "${TEST_FOLDER}" && pwd)"

if [[ ! -f "${LINT_CONFIG}" ]]; then
  echo "ERROR: YAML validation configuration not found: ${LINT_CONFIG}" >&2
  exit 2
fi
# Convert LINT_CONFIG to an absolute path.
LINT_CONFIG="$(cd -- "$(dirname -- "${LINT_CONFIG}")" && pwd)/$(basename -- "${LINT_CONFIG}")"

# Convert paths to Docker-compatible format on Windows (Cygwin/MSYS).
DOCKER_TEST_FOLDER="$(docker_path "$TEST_FOLDER")"
DOCKER_LINT_CONFIG="$(docker_path "$LINT_CONFIG")"

# Run yamllint in Docker using the converted paths.
MSYS_NO_PATHCONV=1 docker run --rm \
  --mount "type=bind,source=${DOCKER_TEST_FOLDER},target=/workspace/test-folder,readonly" \
  --mount "type=bind,source=${DOCKER_LINT_CONFIG},target=/config/.yamllint,readonly" \
  "${IMAGE}" \
  yamllint --config-file /config/.yamllint /workspace/test-folder
