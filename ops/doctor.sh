#!/usr/bin/env bash
#
# doctor.sh — Diagnose this machine's team-os setup and print exact fix
# commands. Exit non-zero if anything hard-required is broken.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

PROBLEMS=0
hard_fail() { err "$1"; [[ -n "${2:-}" ]] && echo "        fix: $2"; PROBLEMS=$((PROBLEMS + 1)); }
soft_warn() { warn "$1"; [[ -n "${2:-}" ]] && echo "        fix: $2"; }

echo "== tos doctor =="
echo

# --- Toolchain -----------------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -ge 3 ]]; then
  ok "bash ${BASH_VERSION}"
else
  hard_fail "bash too old (${BASH_VERSION})" "install bash >= 3.2"
fi

if command -v git >/dev/null 2>&1; then
  GIT_VER="$(git --version | awk '{print $3}')"
  ok "git ${GIT_VER}"
else
  hard_fail "git not found" "install git"
fi

command -v awk >/dev/null 2>&1 && ok "awk present" || hard_fail "awk not found" "install awk (part of any POSIX toolset)"

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI: $(claude --version 2>/dev/null | head -n 1 || echo 'present')"
  if [[ -f "${HOME}/.claude.json" || -d "${HOME}/.claude" ]]; then
    ok "claude appears configured on this machine"
  else
    soft_warn "claude has never been run here" "run: claude   (then /login with your Claude subscription, then /exit)"
  fi
else
  hard_fail "claude CLI not found" "install Claude Code: https://claude.com/claude-code (npm install -g @anthropic-ai/claude-code)"
fi

if command -v gitleaks >/dev/null 2>&1; then
  ok "gitleaks present (pre-commit secret scan active)"
else
  soft_warn "gitleaks not installed — secret scan is skipped" "brew install gitleaks"
fi

echo
# --- Repo ------------------------------------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "inside a git repo (branch $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?'))"
else
  hard_fail "not a git repo" "clone your team's copy of team-os"
fi

if has_remote; then
  ok "origin remote: $(git remote get-url origin)"
  if GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
    ok "remote reachable"
  else
    soft_warn "remote not reachable right now (network/auth?)" "check: GIT_TERMINAL_PROMPT=0 git ls-remote origin"
  fi
else
  soft_warn "no origin remote — sync is local-only" "git remote add origin <url> && git push -u origin main"
fi

HOOKS_PATH="$(git config core.hooksPath 2>/dev/null || echo '')"
if [[ "${HOOKS_PATH}" == "ops/git-hooks" ]]; then
  ok "git hooks installed"
else
  soft_warn "git hooks not installed (protected-path guard + secret scan inactive)" "./ops/install-hooks.sh"
fi

echo
# --- Identity -----------------------------------------------------------------------
ID_FILE="${HOME}/.config/team-os/identity"
if [[ -f "${ID_FILE}" ]]; then
  ok "identity file: ${ID_FILE}"
  if [[ -n "${TEAMOS_MEMBER:-}" && -n "${TEAMOS_AGENT:-}" ]]; then
    FOUND=0
    for m in $(team_members); do [[ "${m}" == "${TEAMOS_MEMBER}" ]] && FOUND=1; done
    if [[ "${FOUND}" -eq 1 ]]; then
      ok "member '${TEAMOS_MEMBER}' exists in team/team.md"
      ROSTER_AGENT="$(member_agent "${TEAMOS_MEMBER}")"
      if [[ "${ROSTER_AGENT}" == "${TEAMOS_AGENT}" ]]; then
        ok "identity agent matches roster (${TEAMOS_AGENT})"
      else
        hard_fail "identity says agent '${TEAMOS_AGENT}' but team.md says '${ROSTER_AGENT}'" "re-run ./ops/onboard.sh --member ${TEAMOS_MEMBER}"
      fi
      if [[ -d "agents/${TEAMOS_AGENT}" ]]; then
        ok "agent directory agents/${TEAMOS_AGENT}/ exists"
      else
        hard_fail "agents/${TEAMOS_AGENT}/ missing" "git pull (or ask a maintainer to run 'tos add-member')"
      fi
    else
      hard_fail "member '${TEAMOS_MEMBER}' not found in team/team.md" "re-run ./ops/onboard.sh and pick a listed member"
    fi
  else
    hard_fail "identity file is missing member= or agent=" "re-run ./ops/onboard.sh"
  fi
else
  hard_fail "no identity on this machine" "./ops/onboard.sh"
fi

TZ_VAL="$(team_setting timezone)"
if [[ -n "${TZ_VAL}" && -f "/usr/share/zoneinfo/${TZ_VAL}" ]]; then
  ok "team timezone '${TZ_VAL}' is valid"
elif [[ -n "${TZ_VAL}" ]]; then
  soft_warn "team timezone '${TZ_VAL}' not in /usr/share/zoneinfo" "check the spelling in team/team.md"
fi

echo
# --- Conventions ----------------------------------------------------------------------
if "${SCRIPT_DIR}/validate.sh" --quiet >/dev/null 2>&1; then
  ok "tos validate: clean"
else
  hard_fail "tos validate has errors" "run: tos validate"
fi

echo
if [[ "${PROBLEMS}" -eq 0 ]]; then
  ok "doctor: no blocking problems"
else
  err "doctor: ${PROBLEMS} blocking problem(s) — fixes above"
  exit 1
fi
