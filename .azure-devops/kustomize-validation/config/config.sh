#!/usr/bin/env bash
set -uo pipefail

TEST_FOLDER="${TEST_FOLDER:-/workspace/test-folder}"
status=0
directories=()
declare -A seen_directories=()
built_count=0
skipped_count=0

if ! command -v kustomize >/dev/null 2>&1; then
  echo "ERROR: kustomize is not installed in the validation image." >&2
  exit 127
fi

if [[ ! -d "$TEST_FOLDER" ]]; then
  echo "ERROR: Test folder not found: $TEST_FOLDER" >&2
  exit 2
fi

while IFS= read -r -d '' file; do
  directory="${file%/*}"
  if [[ -z "${seen_directories[$directory]+present}" ]]; then
    seen_directories["$directory"]=1
    directories+=("$directory")
  fi
done < <(find "$TEST_FOLDER" -type f \( \
  -name 'kustomization.yaml' -o \
  -name 'kustomization.yml' -o \
  -name 'Kustomization' \
\) -print0)

if (( ${#directories[@]} == 0 )); then
  echo "ERROR: No Kustomization files found in: $TEST_FOLDER" >&2
  exit 2
fi

for directory in "${directories[@]}"; do
  output_file="$(mktemp)" || {
    echo "ERROR: Could not create a temporary output file." >&2
    exit 1
  }

  printf 'Building Kustomization: %s\n' "$directory"
  if kustomize build "$directory" >"$output_file" 2>&1; then
    built_count=$((built_count + 1))
  elif grep -Fq 'kustomization.yaml is empty' "$output_file"; then
    echo "Skipping intentionally parked (no active resources): $directory"
    skipped_count=$((skipped_count + 1))
  else
    echo "Kustomize validation failed for: $directory" >&2
    cat "$output_file" >&2
    status=1
  fi

  rm -f "$output_file"
done

if (( status == 0 )); then
  printf 'Successfully built %d Kustomization(s); skipped %d intentionally parked.\n' \
    "$built_count" "$skipped_count"
fi

exit "$status"
