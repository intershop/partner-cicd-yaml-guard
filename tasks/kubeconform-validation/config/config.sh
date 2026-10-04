#!/usr/bin/env bash
set -uo pipefail

TEST_FOLDER="${TEST_FOLDER:-/workspace/test-folder}"
status=0
directories=()
declare -A seen_directories=()

for tool in kustomize kubeconform; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool is not installed in the validation image." >&2
    exit 127
  fi
done

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

tmp_dir="$(mktemp -d)" || {
  echo "ERROR: Could not create a temporary directory." >&2
  exit 1
}
trap 'rm -rf -- "$tmp_dir"' EXIT

schema_args=(-schema-location default)
if [[ -n "${KUBECONFORM_SCHEMA_LOCATION:-}" ]]; then
  schema_args+=(-schema-location "$KUBECONFORM_SCHEMA_LOCATION")
fi

index=0
for directory in "${directories[@]}"; do
  index=$((index + 1))
  rendered="${tmp_dir}/rendered-${index}.yaml"
  build_output="${tmp_dir}/kustomize-${index}.log"
  validation_output="${tmp_dir}/kubeconform-${index}.log"

  if ! kustomize build "$directory" >"$rendered" 2>"$build_output"; then
    if grep -Fq 'kustomization.yaml is empty' "$build_output" "$rendered"; then
      echo "Skipping intentionally parked (no active resources): $directory"
    else
      echo "Kustomize render failed before kubeconform for: $directory" >&2
      cat "$build_output" >&2
      cat "$rendered" >&2
      status=1
    fi
    continue
  fi

  if kubeconform \
    -summary \
    -strict \
    "${schema_args[@]}" \
    "$rendered" >"$validation_output" 2>&1; then
    cat "$validation_output"
  else
    echo "Kubeconform validation failed for: $directory" >&2
    cat "$validation_output" >&2
    status=1
  fi
done

exit "$status"
