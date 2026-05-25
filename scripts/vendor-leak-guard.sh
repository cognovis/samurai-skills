#!/usr/bin/env bash
# Fail if public skill surfaces contain Cognovis project or PVS vendor names.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "--list" ]]; then
  LIST_ONLY=1
else
  LIST_ONLY=0
fi

# Health Samurai and Aidbox terms are owned content in this repository. The
# blocked list covers downstream project names and third-party PVS/vendor terms
# that must not leak into reusable public skills.
TERMS=(
  $'\x63\x68\x61\x72\x6c\x79'
  $'\x73\x6f\x6c\x75\x74\x69\x6f'
  $'\x73\x6f\x6c\x75\x63\x69\x6f'
  $'\x6d\x69\x72\x61'
  $'\x70\x6f\x6c\x61\x72\x69\x73'
  $'\x6b\x72\x61\x62\x6c\x6c\x69\x6e\x6b'
  $'\x77\x69\x6e\x61\x63\x73'
  $'\x6d\x65\x64\x61\x74\x69\x78\x78'
  $'\x64\x61\x6d\x70\x73\x6f\x66\x74'
  $'\x65\x76\x69\x64\x65\x6e\x74'
  $'\x74\x6f\x6d\x65\x64\x6f'
  $'\x65\x70\x69\x6b\x75\x72'
  $'\x78[-._ ]?\x69\x73\x79\x6e\x65\x74'
  $'\x78\x69\x73\x79\x6e\x65\x74'
  $'\x69\x73\x79\x6e\x65\x74'
)

PATTERN="$(IFS='|'; echo "${TERMS[*]}")"
PATTERN="(^|[^[:alnum:]_])(${PATTERN})([^[:alnum:]_]|$)"

PATHS=(
  README.md
  CLAUDE.md
  template
  plugins
  .claude-plugin
)

TRACKED_PATHS=()
while IFS= read -r -d '' path; do
  if [[ -f "$path" ]]; then
    TRACKED_PATHS+=("$path")
  fi
done < <(git ls-files -z -- "${PATHS[@]}")

FILTERED_PATHS=()
for path in "${TRACKED_PATHS[@]}"; do
  case "$path" in
    scripts/vendor-leak-guard.sh|.github/workflows/*) ;;
    *) FILTERED_PATHS+=("$path") ;;
  esac
done
TRACKED_PATHS=("${FILTERED_PATHS[@]}")

if [[ "$LIST_ONLY" -eq 1 ]]; then
  printf '%s\n' "${TRACKED_PATHS[@]}"
  exit 0
fi

if [[ "${#TRACKED_PATHS[@]}" -eq 0 ]]; then
  echo "vendor-leak-guard: skipped, no tracked public skill surfaces found."
  exit 0
fi

if command -v rg >/dev/null 2>&1; then
  MATCHES="$(rg -n -i "$PATTERN" "${TRACKED_PATHS[@]}" || true)"
else
  MATCHES="$(grep -I -n -i -E "$PATTERN" "${TRACKED_PATHS[@]}" || true)"
fi

if [[ -n "$MATCHES" ]]; then
  echo "vendor-leak-guard: FAIL - project or vendor-specific term found."
  echo
  echo "$MATCHES"
  echo
  echo "Use neutral wording in reusable Samurai skills. Keep downstream product,"
  echo "adapter, or PVS-specific details in the consuming project repository."
  exit 1
fi

echo "vendor-leak-guard: OK - no project or vendor-specific strings found."
