#!/usr/bin/env bash
#
# promote.sh — Maintainer-only: promote a draft to shared/knowledge/.
#
# Usage:
#   ops/promote.sh <source> <dest-under-shared/knowledge> <task-id>
#
# Example:
#   ops/promote.sh shared/incoming/weekly-digest-2026-W28.md \
#                  shared/knowledge/weekly-digest-2026-W28.md T-20260706-0003
#
# Promotion is a MOVE (git preserves history), and it writes a
# <dest>.promoted-by sidecar that `tos validate` checks (author must be a
# maintainer in team/team.md). See shared/GOVERNANCE.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity
require_identity

ROOT="$(repo_root)"
cd "${ROOT}"

SRC="${1:-}"
DEST="${2:-}"
TASK_ID="${3:-}"

[[ -n "${SRC}" && -n "${DEST}" && -n "${TASK_ID}" ]] || \
  die "usage: promote.sh <source> <dest-under-shared/knowledge> <task-id>"

is_maintainer "${TEAMOS_MEMBER}" || \
  die "'${TEAMOS_MEMBER}' is not a maintainer in team/team.md — promotion refused"

[[ -f "${SRC}" ]] || die "source not found: ${SRC}"

case "${DEST}" in
  shared/knowledge/*) : ;;
  *) die "destination must be under shared/knowledge/ (got: ${DEST})" ;;
esac
[[ ! -e "${DEST}" ]] || die "destination already exists: ${DEST} (archive it first)"

[[ "${TASK_ID}" =~ ^T-[0-9]{8}-[0-9]{4}$ ]] || \
  die "task id '${TASK_ID}' does not match T-YYYYMMDD-NNNN"

mkdir -p "$(dirname "${DEST}")"
git mv "${SRC}" "${DEST}" 2>/dev/null || { mv "${SRC}" "${DEST}"; git add "${SRC}" "${DEST}" 2>/dev/null || true; }

{
  echo "promoted_by: ${TEAMOS_MEMBER}"
  echo "promoted_at: $(now_utc)"
  echo "task: ${TASK_ID}"
} > "${DEST}.promoted-by"

git add "${DEST}" "${DEST}.promoted-by"
git commit --quiet -m "[shared][agent:${TEAMOS_AGENT}][task:${TASK_ID}] promoted $(basename "${DEST}")"

ok "promoted ${SRC} -> ${DEST}"
echo "  Run 'tos sync' to publish."
