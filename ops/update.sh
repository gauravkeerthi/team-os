#!/usr/bin/env bash
#
# update.sh — Pull platform updates from the upstream team-os template into
# your team's copy.
#
# Usage:
#   ops/update.sh            # dry run: show what upstream would change
#   ops/update.sh --apply    # apply: check out upstream-owned paths + commit
#   ops/update.sh --url <git-url>   # override the upstream URL for this run
#
# Ownership split (see docs/UPGRADING.md): upstream owns the platform;
# your team owns its data. Applying never touches team/, agents/, shared/,
# or private skills.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

# Paths the upstream template owns. Everything else is yours.
OWNED_PATHS="platform ops docs .github .claude/settings.json README.md QUICKSTART.md LICENSE .gitattributes"
# Shipped skills are upstream-owned too; team-added shared skills and
# .claude/skills/private/ are not listed, so they are never touched.
OWNED_SKILLS=".claude/skills/today .claude/skills/close .claude/skills/context-save .claude/skills/context-restore .claude/skills/standup-prep .claude/skills/retro .claude/skills/reflect"

APPLY=0
URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --url)   URL="${2:-}"; shift 2 ;;
    -h|--help) sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

[[ -n "${URL}" ]] || URL="$(team_setting upstream)"
[[ -n "${URL}" ]] || die "no upstream URL — set 'upstream:' in team/team.md frontmatter or pass --url"
case "${URL}" in
  *PLACEHOLDER*) die "team/team.md upstream is still the placeholder — point it at the real template repo (or pass --url)" ;;
esac

REMOTE="teamos-upstream"
if git remote get-url "${REMOTE}" >/dev/null 2>&1; then
  git remote set-url "${REMOTE}" "${URL}"
else
  git remote add "${REMOTE}" "${URL}"
fi

echo "fetching ${URL} ..."
GIT_TERMINAL_PROMPT=0 git fetch --quiet "${REMOTE}" main || die "could not fetch upstream (network? URL?)"

LOCAL_VER="$(head -n 1 platform/VERSION 2>/dev/null || echo '?')"
UPSTREAM_VER="$(git show "${REMOTE}/main:platform/VERSION" 2>/dev/null | head -n 1 || echo '?')"
echo "platform version: local v${LOCAL_VER} -> upstream v${UPSTREAM_VER}"

# shellcheck disable=SC2086
CHANGED="$(git diff --name-only HEAD "${REMOTE}/main" -- ${OWNED_PATHS} ${OWNED_SKILLS} 2>/dev/null || true)"

if [[ -z "${CHANGED}" ]]; then
  ok "already up to date with upstream"
  exit 0
fi

echo
echo "upstream-owned files that differ:"
printf '%s\n' "${CHANGED}" | sed 's/^/  /'
echo
warn "NOTE: any LOCAL edits you made to these paths (they'd be listed in"
warn "platform/CHANGELOG.md) will be overwritten by --apply. Re-apply them after."

if [[ "${APPLY}" -eq 0 ]]; then
  echo
  echo "dry run only. Apply with: tos update --apply"
  exit 0
fi

# --- Apply -----------------------------------------------------------------------
[[ -z "$(git status --porcelain)" ]] || \
  die "working tree not clean — run 'tos done' (or commit/stash) before updating"

# Only check out owned paths that actually exist upstream — a checkout of a
# missing pathspec is a hard error, and upstream is allowed to add/remove
# owned paths between releases.
PRESENT=""
for p in ${OWNED_PATHS} ${OWNED_SKILLS}; do
  if git cat-file -e "${REMOTE}/main:${p}" 2>/dev/null; then
    PRESENT="${PRESENT} ${p}"
  fi
done
[[ -n "${PRESENT// /}" ]] || die "upstream has none of the owned paths — wrong --url?"

# shellcheck disable=SC2086
git checkout "${REMOTE}/main" -- ${PRESENT}

chmod +x ops/*.sh ops/git-hooks/pre-commit 2>/dev/null || true

if [[ -z "$(git status --porcelain)" ]]; then
  ok "nothing to commit after checkout (content identical)"
  exit 0
fi

git add -A
TEAMOS_ALLOW_PLATFORM_EDIT=1 git commit --quiet \
  -m "[ops][agent:-] platform update v${LOCAL_VER} -> v${UPSTREAM_VER}"
ok "updated to platform v${UPSTREAM_VER} (committed). Run 'tos sync' to publish to your team."
echo "  Release notes: platform/CHANGELOG.md"
