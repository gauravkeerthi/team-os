#!/usr/bin/env bash
#
# test-e2e.sh — Two-member simulation over a local bare remote. Proves the
# whole coordination loop with zero network and zero Claude usage:
#
#   setup -> onboard(A) -> add-member -> onboard(B on a second clone) ->
#   cross-member task -> prompt composition -> cadence claim race ->
#   dirty-tree pull resilience -> duplicate-ID detection -> done -> update
#
# Run from a pristine template checkout (CI does). Everything happens in a
# temp dir; the source tree is never modified. KEEP=1 to keep the sandbox.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"

if [[ "$(cd "${ROOT}" && team_setting team)" != "YOUR-TEAM-NAME" ]]; then
  die "test-e2e.sh must run from a pristine template checkout (team.md is already configured here)"
fi

S="$(mktemp -d "${TMPDIR:-/tmp}/teamos-e2e.XXXXXX")"
if [[ "${KEEP:-0}" != "1" ]]; then
  # shellcheck disable=SC2064
  trap "rm -rf '${S}'" EXIT
else
  echo "sandbox: ${S} (kept)"
fi

FAILED=0
pass() { ok "$*"; }
fail() { err "$*"; FAILED=$((FAILED + 1)); }
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "${desc}"; else fail "${desc}"; fi
}

copy_tree() { # copy_tree <dest> — working tree minus .git (portable, no rsync)
  local dest="$1"
  mkdir -p "${dest}"
  (cd "${ROOT}" && git ls-files -z | tar --null -T - -cf -) | (cd "${dest}" && tar -xf -)
}

git_id() { git -C "$1" config user.name "e2e" && git -C "$1" config user.email "e2e@test.invalid"; }

HOME_A="${S}/home-a"; HOME_B="${S}/home-b"
mkdir -p "${HOME_A}" "${HOME_B}"
A="${S}/a"; B="${S}/b"

# --- 0. Seed a bare origin with the pristine template ---------------------------
git init --bare --quiet "${S}/origin.git"
copy_tree "${S}/seed"
(
  cd "${S}/seed"
  git init -b main --quiet
  git_id .
  git add -A
  git commit --quiet -m "[init][agent:-] import team-os template"
  git remote add origin "${S}/origin.git"
  git push --quiet -u origin main
)
pass "seeded bare origin with the template"

# --- 1. Machine A: founder ---------------------------------------------------------
git clone --quiet "${S}/origin.git" "${A}"
git_id "${A}"
(
  cd "${A}"
  HOME="${HOME_A}" ./ops/setup.sh --team "Acme Robotics" --tz UTC \
    --member alice --name "Alice Wong" --agent ajax \
    --email alice@e2e.test --plan max-5x --yes >/dev/null
  HOME="${HOME_A}" ./ops/onboard.sh --member alice --yes --no-alias >/dev/null
  git push --quiet
  HOME="${HOME_A}" ./ops/add-member.sh bob "Bob Iyer" piper pro --email bob@e2e.test >/dev/null
  HOME="${HOME_A}" ./ops/sync.sh >/dev/null
)
check "A: setup + onboard + add-member + sync" test -d "${A}/agents/piper"
check "A: identity file written" grep -q '^member=alice$' "${HOME_A}/.config/team-os/identity"
check "A: validate clean" env HOME="${HOME_A}" "${A}/ops/validate.sh" --quiet

# --- 2. Machine B: teammate -----------------------------------------------------------
git clone --quiet "${S}/origin.git" "${B}"
git_id "${B}"
(
  cd "${B}"
  HOME="${HOME_B}" ./ops/onboard.sh --member bob --yes --no-alias >/dev/null
)
check "B: clone sees bob's agent (created on A)" test -d "${B}/agents/piper"
check "B: identity bound to bob/piper" grep -q '^agent=piper$' "${HOME_B}/.config/team-os/identity"

# --- 3. Cross-member task: A files -> B receives -----------------------------------------
(
  cd "${A}"
  HOME="${HOME_A}" ./ops/task.sh --title "Review the Q3 draft" --to bob \
    --priority high --description "Draft at shared/incoming/q3-draft.md" >/dev/null
  HOME="${HOME_A}" ./ops/sync.sh >/dev/null
)
( cd "${B}" && HOME="${HOME_B}" ./ops/sync.sh >/dev/null )
TASK_FILE="$(ls "${B}"/agents/piper/tasks/inbox/T-*.md 2>/dev/null | head -n 1 || true)"
check "task arrived in piper's inbox on B" test -n "${TASK_FILE}"
check "B: prompt includes the task summary" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/compose-prompt.sh piper | grep -q 'Review the Q3 draft'"
check "B: prompt uses the pro tier" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/compose-prompt.sh piper | grep -q 'PLAN TIER (pro)'"
check "B: pro tier trims memory to head -10" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/compose-prompt.sh piper | grep -q 'head -10'"
check "A: launch --print composes for ajax (max-5x)" \
  bash -c "cd '${A}' && HOME='${HOME_A}' ./ops/launch.sh --print | grep -q 'PLAN TIER (max-5x)'"

# --- 4. Cadence claim race ---------------------------------------------------------------
(
  cd "${A}"
  cat >> team/cadence.md <<'EOF'

### cadence: daily-note
- schedule: daily
- after: 00:00
- owner: any
- action: /standup-prep --digest
- output: shared/cadence/daily-note/{date}.md
- model: sonnet

### cadence: stale-note
- schedule: daily
- after: 00:00
- owner: any
- action: /standup-prep --digest
- output: shared/cadence/stale-note/{date}.md
- model: sonnet
EOF
  HOME="${HOME_A}" ./ops/sync.sh >/dev/null
)
( cd "${B}" && HOME="${HOME_B}" ./ops/sync.sh >/dev/null )
PERIOD="$(date -u +%F)"   # team tz is UTC in this sim
check "cadence item due for A" \
  bash -c "cd '${A}' && HOME='${HOME_A}' ./ops/cadence-due.sh --for alice | grep -q daily-note"
check "cadence item due for B" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/cadence-due.sh --for bob | grep -q daily-note"

# Both claim; A commits (as documented) and pushes first, winning.
(
  cd "${A}"
  mkdir -p shared/cadence/daily-note
  printf 'member: alice\nagent: ajax\nclaimed_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "shared/cadence/daily-note/${PERIOD}.claim.md"
  git add -A && git commit --quiet -m "[cadence][agent:ajax] claim daily-note ${PERIOD}"
  HOME="${HOME_A}" ./ops/sync.sh >/dev/null
)
(
  cd "${B}"
  mkdir -p shared/cadence/daily-note
  printf 'member: bob\nagent: piper\nclaimed_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "shared/cadence/daily-note/${PERIOD}.claim.md"
  git add -A && git commit --quiet -m "[cadence][agent:piper] claim daily-note ${PERIOD}"
)
if (cd "${B}" && git push --quiet 2>/dev/null); then
  fail "B's racing push should have been rejected"
else
  pass "B's racing push rejected (A won)"
fi
check "B: back-off via pull --rebase -X ours succeeds" \
  bash -c "cd '${B}' && git -c rebase.empty=drop pull --rebase --quiet -X ours"
check "B: surviving claim belongs to alice" \
  grep -q '^member: alice$' "${B}/shared/cadence/daily-note/${PERIOD}.claim.md"
check "B: no stray unpushed claim commit" \
  bash -c "test -z \"\$(cd '${B}' && git log --oneline origin/main..HEAD)\""
check "B: cadence no longer offered (fresh foreign claim)" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/cadence-due.sh --for bob | grep -vq daily-note || true; cd '${B}' && HOME='${HOME_B}' ./ops/cadence-due.sh --for bob | { ! grep -q daily-note; }"

# Stale claim: a claim COMMITTED >6h ago with no output is void and
# supersedable. Age is the commit time, so a fresh checkout on B must still
# see it as stale. Backdate the claim commit on A, push, pull to B.
(
  cd "${A}"
  mkdir -p shared/cadence/stale-note
  printf 'member: alice\nagent: ajax\nclaimed_at: %s\n' "2000-01-01T00:00:00Z" \
    > "shared/cadence/stale-note/${PERIOD}.claim.md"
  git add -A
  GIT_AUTHOR_DATE="@$(( $(date +%s) - 25200 )) +0000" \
  GIT_COMMITTER_DATE="@$(( $(date +%s) - 25200 )) +0000" \
    git commit --quiet -m "[cadence][agent:ajax] claim stale-note ${PERIOD}"
  git push --quiet
)
( cd "${B}" && git -c rebase.empty=drop pull --rebase --quiet )
check "B: stale claim (committed 7h ago) is supersedable, not offered-as-claimed" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/cadence-due.sh --for bob | grep -q stale-note"
check "B: fresh claim still blocks while stale one is offered (no false-stale)" \
  bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/cadence-due.sh --for bob | { ! grep -q daily-note; }"

# --- 5. Dirty-tree pull resilience (the auto-stash path) -------------------------------------
( cd "${A}" && echo "note $(date -u +%s)" >> agents/ajax/logs/activity.log.md && HOME="${HOME_A}" ./ops/sync.sh >/dev/null )
(
  cd "${B}"
  printf -- "- dirty uncommitted line\n" >> agents/piper/logs/activity.log.md
)
check "B: git_safe_pull_rebase with dirty tree succeeds" \
  bash -c "cd '${B}' && source ops/_lib.sh && git_safe_pull_rebase"
check "B: dirty line survived the stash/pop" \
  grep -q 'dirty uncommitted line' "${B}/agents/piper/logs/activity.log.md"
check "B: remote commit arrived while dirty" \
  bash -c "cd '${B}' && git log --oneline -5 | grep -q 'manual sync'"

# --- 6. Duplicate task ID detection ------------------------------------------------------------
DUP_BASE="$(basename "${TASK_FILE}")"
cp "${TASK_FILE}" "${B}/agents/ajax/tasks/inbox/${DUP_BASE}"
if (cd "${B}" && HOME="${HOME_B}" ./ops/validate.sh --quiet >/dev/null 2>&1); then
  fail "validate should reject a duplicate task ID"
else
  pass "validate rejects duplicate task IDs"
fi
rm "${B}/agents/ajax/tasks/inbox/${DUP_BASE}"

# --- 7. tos done green on both machines ----------------------------------------------------------
check "A: tos done green" bash -c "cd '${A}' && HOME='${HOME_A}' ./ops/done.sh"
check "B: tos done green" bash -c "cd '${B}' && HOME='${HOME_B}' ./ops/done.sh"

# --- 8. Platform update flow ----------------------------------------------------------------------
git init --bare --quiet "${S}/upstream.git"
(
  cd "${S}/seed"
  git remote add up "${S}/upstream.git"
  git push --quiet up main
  printf '0.1.1\n' > platform/VERSION
  git add platform/VERSION
  git commit --quiet -m "release 0.1.1"
  git push --quiet up main
)
check "update dry-run sees the version bump" \
  bash -c "cd '${A}' && HOME='${HOME_A}' ./ops/update.sh --url '${S}/upstream.git' | grep -q 'v0.1.0 -> upstream v0.1.1'"
check "update --apply lands v0.1.1" \
  bash -c "cd '${A}' && HOME='${HOME_A}' ./ops/update.sh --url '${S}/upstream.git' --apply >/dev/null && grep -q '0.1.1' platform/VERSION"

# --- Summary -----------------------------------------------------------------------------------------
echo
if [[ "${FAILED}" -eq 0 ]]; then
  ok "e2e: all checks passed"
else
  err "e2e: ${FAILED} check(s) failed"
  exit 1
fi
