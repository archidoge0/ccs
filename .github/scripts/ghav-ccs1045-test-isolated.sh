#!/usr/bin/env bash
# Test-process isolation for the fixed CCS #1045 source. This preserves all 325
# original test files while containing a Bun mock.module leak between files.
set -u -o pipefail

cd "$(dirname "$0")/../.." 2>/dev/null || true
# In the hosted workflow this script is installed at .github/scripts/, so the
# preceding cd returns to the repository root. Check the expected task tree.
test -f package.json && test -d tests/unit || exit 2

mapfile -t all_files < <(find tests/unit tests/integration tests/npm -type f \( -name '*.test.*' -o -name '*.spec.*' \) | LC_ALL=C sort)
manifest_sha=$(printf '%s\n' "${all_files[@]}" | sha256sum | awk '{print $1}')
echo "TEST_MANIFEST_COUNT=${#all_files[@]}"
echo "TEST_MANIFEST_SHA256=$manifest_sha"
if [[ ${#all_files[@]} -ne 325 || $manifest_sha != b742a68abee831bc2d74f70c93db23b5abdfda7bb05a46a397dcd6838bf8ba0d ]]; then
  echo 'Fixed task test-file manifest changed' >&2
  exit 2
fi

isolated=(
  tests/unit/web-server/cliproxy-stats-routes-model-update.test.ts
  tests/unit/web-server/cliproxy-stats-routes-install.test.ts
  tests/unit/cliproxy/version-checker-stale-cache.test.ts
)
bulk=()
for file in "${all_files[@]}"; do
  case "$file" in
    "${isolated[0]}"|"${isolated[1]}"|"${isolated[2]}") ;;
    *) bulk+=("$file") ;;
  esac
done
if [[ ${#bulk[@]} -ne 322 ]]; then
  echo 'Test groups do not cover exactly 325 files' >&2
  exit 2
fi

failed=0
run_group() {
  local name=$1 status
  shift
  echo "TEST_GROUP_BEGIN=$name FILES=$#"
  bun test "$@"
  status=$?
  echo "TEST_GROUP_END=$name EXIT=$status"
  if [[ $status -ne 0 ]]; then failed=1; fi
}

run_group bulk "${bulk[@]}"
run_group model_update "${isolated[0]}"
run_group install "${isolated[1]}"
run_group version_cache "${isolated[2]}"
echo "TEST_ALL_GROUPS_EXIT=$failed"
exit "$failed"
