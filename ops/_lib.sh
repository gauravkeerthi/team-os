#!/usr/bin/env bash
#
# _lib.sh — Shared bash helpers for team-os ops/*.sh.
#
# Sourced by every ops script at the top:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
#
# Callers are expected to already have `set -euo pipefail` enabled. This
# library intentionally does not set it — that stays an explicit choice at
# the top of each script so behavior is obvious from reading it.
#
# Contents:
#   ok / warn / err / die             — consistent colored output
#   repo_root / now_utc               — basics
#   load_identity / require_identity  — ~/.config/team-os/identity (parsed
#                                       with awk, never sourced)
#   team_setting / team_members / team_member_field / member_agent /
#     agent_member / is_maintainer    — team/team.md parsers
#   cadence_items / cadence_field     — team/cadence.md parsers
#   md_frontmatter_field              — read one key from a file's YAML header
#   tier_model / tier_memory_lines    — plan-tier lookups
#   git_rebase_in_progress /
#     git_safe_pull_rebase            — the sync core. Ported verbatim from
#                                       workforce-os, where it ended the
#                                       recurring detached-HEAD auto-sync bug.
#                                       Do not "simplify".
#   has_remote / commit_pull_push     — the one true sync sequence
#   update_heartbeat                  — agent clock file for long sessions
#   escape_sed                        — literal-safe sed replacement strings

# Guard against double-sourcing.
if [[ -n "${__TEAMOS_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
__TEAMOS_LIB_LOADED=1

# -----------------------------------------------------------------------------
# Color output helpers.
# -----------------------------------------------------------------------------
__TOS_RED='\033[0;31m'
__TOS_GRN='\033[0;32m'
__TOS_YEL='\033[0;33m'
__TOS_NC='\033[0m'

ok()   { printf "${__TOS_GRN}[ OK ]${__TOS_NC} %s\n" "$*"; }
warn() { printf "${__TOS_YEL}[WARN]${__TOS_NC} %s\n" "$*"; }
err()  { printf "${__TOS_RED}[FAIL]${__TOS_NC} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# -----------------------------------------------------------------------------
# repo_root — absolute path of the team-os repo root, resolved relative to
# this library file's location. Works regardless of the caller's CWD.
# -----------------------------------------------------------------------------
repo_root() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # _lib.sh lives in ops/, so the repo root is one level up.
  (cd "${lib_dir}/.." && pwd)
}

now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# -----------------------------------------------------------------------------
# load_identity — populate TEAMOS_MEMBER, TEAMOS_AGENT (and optional
# TEAMOS_MODEL, TEAMOS_SYNC_INTERVAL overrides) from ~/.config/team-os/identity
# if they are not already set in the environment. An already-set env var
# always wins (explicit override).
#
# Parse the file with awk rather than sourcing it, so a hostile identity file
# cannot execute shell. Each non-blank, non-comment line MUST match
# ^[a-z_][a-z0-9_]*=.+$ — anything else is a fatal error.
# -----------------------------------------------------------------------------
load_identity() {
  local id_file="${HOME}/.config/team-os/identity"
  [[ -f "${id_file}" ]] || return 0  # silent no-op if missing

  local lineno=0
  local bad_lines=""
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    lineno=$((lineno + 1))
    if [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if ! [[ "${line}" =~ ^[a-z_][a-z0-9_]*=.+$ ]]; then
      bad_lines="${bad_lines}${lineno}: ${line}\n"
    fi
  done < "${id_file}"

  if [[ -n "${bad_lines}" ]]; then
    printf "${__TOS_RED}[FAIL]${__TOS_NC} malformed %s:\n" "${id_file}" >&2
    printf "%b" "${bad_lines}" >&2
    exit 1
  fi

  local _member _agent _model _interval
  _member="$(awk -F= '/^member=/{sub(/^member=/,""); print; exit}' "${id_file}")"
  _agent="$(awk -F= '/^agent=/{sub(/^agent=/,""); print; exit}' "${id_file}")"
  _model="$(awk -F= '/^model=/{sub(/^model=/,""); print; exit}' "${id_file}")"
  _interval="$(awk -F= '/^sync_interval=/{sub(/^sync_interval=/,""); print; exit}' "${id_file}")"

  if [[ -z "${TEAMOS_MEMBER:-}" && -n "${_member}" ]]; then
    export TEAMOS_MEMBER="${_member}"
  fi
  if [[ -z "${TEAMOS_AGENT:-}" && -n "${_agent}" ]]; then
    export TEAMOS_AGENT="${_agent}"
  fi
  if [[ -z "${TEAMOS_MODEL:-}" && -n "${_model}" ]]; then
    export TEAMOS_MODEL="${_model}"
  fi
  if [[ -z "${TEAMOS_SYNC_INTERVAL:-}" && -n "${_interval}" ]]; then
    export TEAMOS_SYNC_INTERVAL="${_interval}"
  fi
}

# -----------------------------------------------------------------------------
# require_identity — die unless this machine knows who it is. Call after
# load_identity from scripts that need a member/agent identity to function.
# -----------------------------------------------------------------------------
require_identity() {
  if [[ -z "${TEAMOS_MEMBER:-}" || -z "${TEAMOS_AGENT:-}" ]]; then
    die "no identity on this machine. Run ops/onboard.sh first (or export TEAMOS_MEMBER and TEAMOS_AGENT)."
  fi
}

# -----------------------------------------------------------------------------
# team/team.md parsers. The grammar is deliberately narrow (see the file's
# header comment and tos validate): frontmatter `key: value` lines between
# two `---` fences, then one `### member: <id>` block per person with
# `- key: value` bullets. Everything is line-anchored, so example blocks
# inside `> ` blockquotes never match.
# -----------------------------------------------------------------------------
team_file()    { echo "$(repo_root)/team/team.md"; }
cadence_file() { echo "$(repo_root)/team/cadence.md"; }

# team_setting <key> — read a frontmatter value from team/team.md.
team_setting() {
  local key="${1:?key required}"
  local f
  f="$(team_file)"
  [[ -f "${f}" ]] || { echo ""; return 0; }
  awk -v key="${key}" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---"   { exit }
    in_fm && index($0, key ":") == 1 {
      sub(/^[a-z_]+:[[:space:]]*/, ""); print; exit
    }
  ' "${f}"
}

# team_members — echo member ids, one per line, in file order.
team_members() {
  local f
  f="$(team_file)"
  [[ -f "${f}" ]] || return 0
  awk '/^### member: /{print $3}' "${f}"
}

# team_member_field <member-id> <key> — echo one bullet value from that
# member's block ("" if absent).
team_member_field() {
  local member="${1:?member id required}"
  local key="${2:?key required}"
  local f
  f="$(team_file)"
  [[ -f "${f}" ]] || { echo ""; return 0; }
  awk -v id="${member}" -v key="${key}" '
    /^### member: / { in_block = ($3 == id); next }
    /^### /         { if (in_block) exit }
    in_block && index($0, "- " key ":") == 1 {
      sub(/^- [a-z_]+:[[:space:]]*/, ""); print; exit
    }
  ' "${f}"
}

member_agent() { team_member_field "${1:?member id required}" agent; }

# agent_member <agent-name> — reverse lookup ("" if no member owns it).
agent_member() {
  local agent="${1:?agent name required}"
  local m
  for m in $(team_members); do
    if [[ "$(team_member_field "${m}" agent)" == "${agent}" ]]; then
      echo "${m}"
      return 0
    fi
  done
  echo ""
}

# is_maintainer <member-id> — exit 0 iff that member's role is maintainer.
is_maintainer() {
  [[ "$(team_member_field "${1:?member id required}" role)" == "maintainer" ]]
}

# -----------------------------------------------------------------------------
# team/cadence.md parsers — same shape as the member parsers.
# -----------------------------------------------------------------------------
cadence_items() {
  local f
  f="$(cadence_file)"
  [[ -f "${f}" ]] || return 0
  awk '/^### cadence: /{print $3}' "${f}"
}

cadence_field() {
  local item="${1:?cadence item required}"
  local key="${2:?key required}"
  local f
  f="$(cadence_file)"
  [[ -f "${f}" ]] || { echo ""; return 0; }
  awk -v id="${item}" -v key="${key}" '
    /^### cadence: / { in_block = ($3 == id); next }
    /^### /          { if (in_block) exit }
    in_block && index($0, "- " key ":") == 1 {
      sub(/^- [a-z_]+:[[:space:]]*/, ""); print; exit
    }
  ' "${f}"
}

# -----------------------------------------------------------------------------
# md_frontmatter_field <file> <key> — read one `key: value` line from a
# markdown file's YAML frontmatter (first --- ... --- block). Tolerates a
# leading HTML-comment sentinel line before the frontmatter (the onboarding
# sentinel), because task/context files may carry one.
# -----------------------------------------------------------------------------
md_frontmatter_field() {
  local file="${1:?file required}"
  local key="${2:?key required}"
  [[ -f "${file}" ]] || { echo ""; return 0; }
  awk -v key="${key}" '
    !started && /^<!--/ { next }           # skip sentinel/comment lines up top
    !started && $0 == "---" { started = 1; in_fm = 1; next }
    !started && NF == 0 { next }
    !started { exit }                       # no frontmatter at all
    in_fm && $0 == "---" { exit }
    in_fm && index($0, key ":") == 1 {
      sub(/^[a-zA-Z_]+:[[:space:]]*/, ""); print; exit
    }
  ' "${file}"
}

# -----------------------------------------------------------------------------
# Plan-tier lookups. The tier table lives here (and only here) so launch,
# compose-prompt, and status all agree.
# -----------------------------------------------------------------------------
tier_model() {
  case "${1:-}" in
    pro)             echo "sonnet" ;;
    max-5x|max-20x)  echo "opus" ;;
    *)               echo "sonnet" ;;   # unknown tier: cheapest safe default
  esac
}

# How many lines of lessons.md / decisions.md the composed prompt includes.
tier_memory_lines() {
  case "${1:-}" in
    pro) echo "10" ;;
    *)   echo "25" ;;
  esac
}

# -----------------------------------------------------------------------------
# git_rebase_in_progress
#
# Returns 0 (true) if a rebase is currently in progress in the repo at CWD.
# -----------------------------------------------------------------------------
git_rebase_in_progress() {
  local git_dir
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  [[ -d "${git_dir}/rebase-merge" || -d "${git_dir}/rebase-apply" ]]
}

# -----------------------------------------------------------------------------
# git_safe_pull_rebase [log_file]
#
# Pull with rebase, but detect and recover from conflicts instead of silently
# leaving the repo in a broken rebase state. If a conflict occurs:
#   1. Abort the rebase (return to pre-pull state)
#   2. Log a warning to the optional log_file
#   3. Return non-zero so the caller knows the pull failed
#
# Ported verbatim from workforce-os, where the bare `git pull --rebase || true`
# pattern caused a recurring detached-HEAD bug in the background sync loop.
# Operates on the repo at CWD.
# -----------------------------------------------------------------------------
git_safe_pull_rebase() {
  local log_file="${1:-}"

  # Refuse to pull if already in a broken rebase state.
  if git_rebase_in_progress; then
    warn "git rebase already in progress — refusing to pull (abort the rebase first)"
    return 1
  fi

  # Stash any dirty working-tree files before pulling. Agents write logs
  # between syncs, leaving unstaged changes that block `git pull --rebase`.
  # Stash preserves those changes and lets the pull proceed.
  local did_stash=0
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    if ! git stash push --quiet --include-untracked -m "git_safe_pull_rebase auto-stash" 2>/dev/null; then
      warn "git stash failed — cannot pull with dirty working tree"
      if [[ -n "${log_file}" ]]; then
        printf "%s [sync] stash failed before pull — dirty working tree, skipping pull\n" \
          "$(now_utc)" >> "${log_file}" 2>/dev/null || true
      fi
      return 1
    fi
    did_stash=1
  fi

  local pull_ok=0
  if git -c rebase.empty=drop pull --rebase --quiet 2>/dev/null; then
    pull_ok=1
  fi

  # Pop the stash regardless of pull outcome so working-tree changes
  # are not silently lost. If pop conflicts (unlikely for log files),
  # the stash stays — `git stash list` will show it.
  if [[ "${did_stash}" -eq 1 ]]; then
    git stash pop --quiet 2>/dev/null || warn "git stash pop had conflicts — check 'git stash list'"
  fi

  if [[ "${pull_ok}" -eq 1 ]]; then
    return 0
  fi

  # Pull --rebase failed. If it left a rebase in progress, abort it so
  # the repo stays usable. The alternative — leaving it stuck — causes
  # a background sync loop to commit on a detached HEAD indefinitely.
  if git_rebase_in_progress; then
    warn "git pull --rebase hit a conflict — aborting rebase to keep repo usable"
    git rebase --abort 2>/dev/null || true
    if [[ -n "${log_file}" ]]; then
      printf "%s [sync] pull --rebase conflicted and was auto-aborted — manual sync needed\n" \
        "$(now_utc)" >> "${log_file}" 2>/dev/null || true
    fi
  else
    warn "git pull --rebase failed (non-conflict error — no remote, network down, or auth)"
  fi
  return 1
}

# -----------------------------------------------------------------------------
# has_remote — true if an 'origin' remote is configured.
# -----------------------------------------------------------------------------
has_remote() {
  git -C "$(repo_root)" remote get-url origin >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# commit_pull_push <commit-message> [log_file]
#
# The one true sync sequence shared by sync.sh, done.sh, and the background
# loop: stage everything, commit if anything is staged, pull safely, push if
# a remote exists. Returns non-zero if the pull conflicted or the push
# failed — callers decide how loud to be.
# -----------------------------------------------------------------------------
commit_pull_push() {
  local msg="${1:?commit message required}"
  local log_file="${2:-}"
  local root
  root="$(repo_root)"

  git -C "${root}" add -A
  if ! git -C "${root}" diff --cached --quiet 2>/dev/null; then
    git -C "${root}" commit --quiet -m "${msg}"
  fi

  if ! has_remote; then
    warn "no git remote configured — committed locally only (add one with: git remote add origin <url>)"
    return 0
  fi

  local rc=0
  (cd "${root}" && git_safe_pull_rebase "${log_file}") || rc=1
  if [[ "${rc}" -eq 0 ]]; then
    if ! git -C "${root}" push --quiet 2>/dev/null; then
      warn "git push failed — changes are committed locally and will push on the next sync"
      rc=1
    fi
  fi
  return "${rc}"
}

# -----------------------------------------------------------------------------
# update_heartbeat <agent>
#
# Write agents/<agent>/.heartbeat with the current clock. The background sync
# loop refreshes it hourly; agents read it for the current time during long
# sessions instead of guessing. Gitignored.
# -----------------------------------------------------------------------------
update_heartbeat() {
  local _uh_agent="${1:?agent name required}"
  local _uh_file
  _uh_file="$(repo_root)/agents/${_uh_agent}/.heartbeat"
  mkdir -p "$(dirname "${_uh_file}")"
  {
    echo "utc: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "local: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "tz: $(date +%Z)"
    echo "day: $(date '+%A')"
  } > "${_uh_file}"
}

# -----------------------------------------------------------------------------
# escape_sed <string> — escape a value for use in a sed s/.../VALUE/ RHS.
# -----------------------------------------------------------------------------
escape_sed() {
  printf '%s' "${1:-}" | sed -e 's/[&/\]/\\&/g'
}
