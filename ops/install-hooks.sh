#!/usr/bin/env bash
#
# install-hooks.sh — Point git at the committed hooks (protected-path guard
# + secret scan). Idempotent; run by setup.sh and onboard.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"

chmod +x ops/git-hooks/pre-commit 2>/dev/null || true
git config core.hooksPath ops/git-hooks
ok "git hooks installed (core.hooksPath = ops/git-hooks)"

if ! command -v gitleaks >/dev/null 2>&1; then
  warn "gitleaks not installed — the pre-commit secret scan will be skipped (brew install gitleaks)"
fi
