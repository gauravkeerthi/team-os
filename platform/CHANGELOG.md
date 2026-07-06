# Platform Changelog

Two kinds of entries land here:

1. **Upstream releases** — what changed in each `platform/VERSION` bump
   (pulled in via `tos update`).
2. **Local platform edits** — whenever someone commits a change to a
   protected path (`platform/`, `ops/`, `.claude/settings.json`, …) with
   `TEAMOS_ALLOW_PLATFORM_EDIT=1`, the pre-commit hook appends an audit
   line below. Local edits will show up in `tos update` diffs; see
   `docs/UPGRADING.md`.

## 0.2.0 — optional wall-clock scheduling

- Added the opt-in headless cadence runner (`ops/cron-run.sh`) and its
  installer (`ops/cron-install.sh`, launchd/cron), plus `tos cron-run` /
  `tos cron-install`. A host OS timer fires due cadence items via headless
  `claude -p` on subscription credits — no persistent session, no MCP.
  Reuses the existing cadence-due engine, claim protocol, and tier model
  selection. See `docs/SCHEDULING.md`. Core stays pull-based; this is
  additive and off by default.

## 0.1.0 — initial release

- First public version of team-os: paired agents, markdown+git
  coordination, catch-up cadence, plan-tier consumption management,
  `tos` CLI, seven shared skills.

<!-- local platform-edit audit lines are appended below -->
