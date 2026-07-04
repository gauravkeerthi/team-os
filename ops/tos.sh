#!/usr/bin/env bash
#
# tos.sh — The team-os CLI dispatcher. Installed as the `tos` shell alias by
# ops/onboard.sh. Bare `tos` launches your agent.
#
# Subcommands:
#   tos                  launch your paired agent (same as `tos launch`)
#   tos launch [--print] launch, or just print the composed prompt
#   tos setup            one-time team bootstrap (founder, once per team)
#   tos add-member ...   add a teammate + create their agent (maintainer)
#   tos onboard          bind this machine to a member (per machine)
#   tos task ...         file a task into an agent's inbox
#   tos sync             commit + pull --rebase + push (safe anytime)
#   tos done             validate, then commit + pull + push (end of session)
#   tos status           read-only dashboard (no Claude usage)
#   tos validate         check every convention (CI runs this too)
#   tos doctor           diagnose this machine's setup
#   tos promote ...      maintainer: promote a draft to shared/knowledge
#   tos update           pull platform updates from the upstream template
#   tos help             this text

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '6,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

SUB="${1:-launch}"
[[ $# -gt 0 ]] && shift

case "${SUB}" in
  launch)      exec "${SCRIPT_DIR}/launch.sh" "$@" ;;
  setup)       exec "${SCRIPT_DIR}/setup.sh" "$@" ;;
  add-member)  exec "${SCRIPT_DIR}/add-member.sh" "$@" ;;
  onboard)     exec "${SCRIPT_DIR}/onboard.sh" "$@" ;;
  task)        exec "${SCRIPT_DIR}/task.sh" "$@" ;;
  sync)        exec "${SCRIPT_DIR}/sync.sh" "$@" ;;
  done)        exec "${SCRIPT_DIR}/done.sh" "$@" ;;
  status)      exec "${SCRIPT_DIR}/status.sh" "$@" ;;
  validate)    exec "${SCRIPT_DIR}/validate.sh" "$@" ;;
  doctor)      exec "${SCRIPT_DIR}/doctor.sh" "$@" ;;
  promote)     exec "${SCRIPT_DIR}/promote.sh" "$@" ;;
  update)      exec "${SCRIPT_DIR}/update.sh" "$@" ;;
  cadence)     exec "${SCRIPT_DIR}/cadence-due.sh" "$@" ;;
  help|-h|--help) usage ;;
  *)
    printf 'tos: unknown subcommand "%s"\n\n' "${SUB}" >&2
    usage >&2
    exit 1
    ;;
esac
