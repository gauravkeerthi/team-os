#!/usr/bin/env bash
#
# cron-install.sh — Install (or remove) the OS timer that drives the
# headless cadence runner ops/cron-run.sh.
#
#   Linux/WSL : a crontab line
#   macOS     : a LaunchAgent (~/Library/LaunchAgents)
#
# Usage:
#   ops/cron-install.sh [--interval <minutes>]   install (default 15 min)
#   ops/cron-install.sh --uninstall
#   ops/cron-install.sh --status
#
# Idempotent. The job runs as YOU (this machine's member), so it fires the
# cadence items you own / are rotated / can claim. Before installing, make
# sure `claude` is signed in on this machine (or a token is set — see
# ops/cron-run.sh header).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
RUNNER="${ROOT}/ops/cron-run.sh"
LABEL="com.team-os.cron"
INTERVAL=15
ACTION="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)  INTERVAL="${2:-15}"; shift 2 ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --status)    ACTION="status"; shift ;;
    --help|-h)   sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

[[ "${INTERVAL}" =~ ^[0-9]+$ && "${INTERVAL}" -ge 1 ]] || die "--interval must be a positive integer (minutes)"

OS="$(uname -s)"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
CRON_TAG="# team-os cadence runner (${ROOT})"

# ---------------------------------------------------------------- macOS (launchd)
mac_install() {
  mkdir -p "${HOME}/Library/LaunchAgents"
  local seconds=$(( INTERVAL * 60 ))
  cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${RUNNER}</string>
  </array>
  <key>WorkingDirectory</key><string>${ROOT}</string>
  <key>StartInterval</key><integer>${seconds}</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>${HOME}/.config/team-os/cron.out.log</string>
  <key>StandardErrorPath</key><string>${HOME}/.config/team-os/cron.err.log</string>
</dict>
</plist>
EOF
  launchctl unload "${PLIST}" 2>/dev/null || true
  launchctl load "${PLIST}"
  ok "installed LaunchAgent ${LABEL} (every ${INTERVAL} min)"
  echo "  plist: ${PLIST}"
  echo "  logs:  ~/.config/team-os/cron.log (runner) + cron.{out,err}.log (launchd)"
}
mac_uninstall() {
  if [[ -f "${PLIST}" ]]; then
    launchctl unload "${PLIST}" 2>/dev/null || true
    rm -f "${PLIST}"
    ok "removed LaunchAgent ${LABEL}"
  else
    warn "no LaunchAgent at ${PLIST}"
  fi
}
mac_status() {
  if [[ -f "${PLIST}" ]]; then
    ok "LaunchAgent installed: ${PLIST}"
    launchctl list 2>/dev/null | grep "${LABEL}" || echo "  (loaded state unknown — try: launchctl list | grep ${LABEL})"
  else
    echo "not installed (no ${PLIST})"
  fi
}

# ------------------------------------------------------------------ Linux (cron)
cron_line() { echo "*/${INTERVAL} * * * * cd ${ROOT} && /bin/bash ops/cron-run.sh >> \$HOME/.config/team-os/cron.out.log 2>&1 ${CRON_TAG}"; }
linux_install() {
  command -v crontab >/dev/null 2>&1 || die "crontab not found — install cron, or run ops/cron-run.sh from your own scheduler"
  local current; current="$(crontab -l 2>/dev/null || true)"
  local cleaned; cleaned="$(printf '%s\n' "${current}" | grep -vF "${CRON_TAG}" || true)"
  { printf '%s\n' "${cleaned}" | sed '/^$/d'; cron_line; } | crontab -
  ok "installed crontab entry (every ${INTERVAL} min)"
  echo "  view:  crontab -l"
  echo "  logs:  ~/.config/team-os/cron.log"
}
linux_uninstall() {
  command -v crontab >/dev/null 2>&1 || die "crontab not found"
  local current; current="$(crontab -l 2>/dev/null || true)"
  if printf '%s\n' "${current}" | grep -qF "${CRON_TAG}"; then
    printf '%s\n' "${current}" | grep -vF "${CRON_TAG}" | sed '/^$/d' | crontab -
    ok "removed team-os crontab entry"
  else
    warn "no team-os crontab entry found"
  fi
}
linux_status() {
  command -v crontab >/dev/null 2>&1 || { echo "crontab not found"; return; }
  if crontab -l 2>/dev/null | grep -qF "${CRON_TAG}"; then
    ok "crontab entry installed:"; crontab -l 2>/dev/null | grep -F "${CRON_TAG}" | sed 's/^/  /'
  else
    echo "not installed"
  fi
}

mkdir -p "${HOME}/.config/team-os"
[[ -x "${RUNNER}" ]] || chmod +x "${RUNNER}" 2>/dev/null || true

case "${OS}:${ACTION}" in
  Darwin:install)   mac_install ;;
  Darwin:uninstall) mac_uninstall ;;
  Darwin:status)    mac_status ;;
  *:install)        linux_install ;;
  *:uninstall)      linux_uninstall ;;
  *:status)         linux_status ;;
esac

if [[ "${ACTION}" == "install" ]]; then
  echo
  echo "Test it now without waiting for the timer:  tos cron-run --list"
  echo "Then a real run:                            tos cron-run"
fi
