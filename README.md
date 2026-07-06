# team-os

**A file-based operating system for a small team of humans and their paired
Claude agents.** Every person gets an agent with real memory. Every agent
coordinates through markdown files carried by git. No server, no database,
no message bus, no web UI — and no API keys: it runs on the Claude
subscription each member already has.

[![validate](https://github.com/PLACEHOLDER-ORG/team-os/actions/workflows/validate.yml/badge.svg)](https://github.com/PLACEHOLDER-ORG/team-os/actions/workflows/validate.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## What you get

- **A paired agent per person** — with a personality (`soul.md`), a role
  (`profile.md`), four structured memory files, a task queue, and a private
  workspace. Launched with one command: `tos`.
- **Coordination through files, synced by git.** To ask a teammate's agent
  for something, your agent files a markdown task into their inbox folder
  and pushes. Their next launch pulls it. The folder a task sits in IS its
  status: `inbox/ → active/ → done/`.
- **Team cadence without a scheduler.** Recurring items (standup digest,
  weekly retro) are declared in one file; whoever launches first while an
  item is due gets offered it. Races are settled by a git push — the remote
  is the lock arbiter. No always-on machine anywhere.
- **Subscription-credit native.** Each member declares their Claude plan
  (`pro`, `max-5x`, `max-20x`) in the team config. The launcher picks the
  session model, trims the injected context, and the agent's prompt carries
  tier-specific usage doctrine. Claude Pro is a first-class citizen.
- **A small bash CLI** (`tos`) for everything mechanical — status, sync,
  task filing, validation — so you never spend Claude usage on things git
  can do for free.

## How it fits together

```
team-os/                    (your team's private copy — the repo IS the workspace)
├── team/
│   ├── team.md             # THE config: members, agents, plans, roles
│   └── cadence.md          # recurring team items (catch-up model)
├── agents/
│   ├── _template/          # copied for each new member
│   └── <agent>/            # soul, profile, memory×4, tasks/{inbox,active,done}, workspace, logs
├── shared/                 # incoming/ (drafts) → knowledge/ (promoted) · handoffs · projects · cadence
├── platform/               # the OS: base prompt, tier doctrine, schemas, conventions
├── ops/                    # the tos CLI (pure bash)
└── .claude/                # permission model + seven shared skills
```

One repo, one branch, everyone pushes. Each agent writes only under its own
`agents/<name>/`, so conflicts are structurally rare; the battle-tested
auto-stash/rebase/abort sync core handles the rest.

## Design principles

1. **Everything inspectable via files.** `ls` is your dashboard; `git log`
   is your audit trail.
2. **Conventions over configuration.** One template, one folder shape, one
   config file.
3. **Minimize hidden state.** No daemon, no database, nothing running when
   nobody's working.
4. **Visible failure.** Scripts fail loudly; agents block tasks instead of
   guessing.
5. **Respect the meter.** Session credits are finite — the platform spends
   them on judgment, never on mechanics.

## Daily use

| Command | What it does |
|---|---|
| `tos` | Pull latest, show what's waiting, launch your agent on your tier's model |
| `tos task --title "..." --to <member>` | File a task into a teammate's agent inbox |
| `tos sync` | Commit + pull + push (safe any time) |
| `tos done` | Validate conventions, then commit + pull + push (end of session) |
| `tos status` | Read-only dashboard — costs zero Claude usage |
| `tos doctor` | Diagnose this machine's setup, with exact fix commands |

Inside a session: `/today` to orient, `/close` to wrap up. Five more
skills ship in the box (`/context-save`, `/context-restore`,
`/standup-prep`, `/retro`, `/reflect`).

## Get started

**[QUICKSTART.md](QUICKSTART.md)** takes a founder from "Use this template"
to two humans with two syncing agents in about fifteen minutes.

Requirements: git, bash ≥ 3.2 (macOS/Linux; Windows via WSL or Git Bash),
[Claude Code](https://claude.com/claude-code), and a Claude subscription
per member (Pro is enough). No API keys, no other accounts.

## Reading

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how and why it works
- [docs/EXTENDING.md](docs/EXTENDING.md) — skills, cadence items, adding
  your own MCP integrations
- [docs/SCHEDULING.md](docs/SCHEDULING.md) — opt-in wall-clock cadence runner
- [docs/UPGRADING.md](docs/UPGRADING.md) — pulling platform updates
- [shared/GOVERNANCE.md](shared/GOVERNANCE.md) — who promotes what

## Not in scope (deliberately)

No web dashboard. No vector database. No real-time agent chat. No
autonomous headless agents. No integrations in core — the extension point
is documented, the dependencies are not shipped. Wall-clock scheduling is
**opt-in**, not core: the default cadence is pull-based (surfaced at
launch), and teams that want timed firing add the headless runner in
[docs/SCHEDULING.md](docs/SCHEDULING.md) — still no API keys, no daemon
beyond a stock OS timer.

## Lineage & license

team-os is the open, generic extraction of a private system ("workforce-os")
that ran a real 7-person company on markdown + git + Claude Code. MIT
licensed — see [LICENSE](LICENSE).
