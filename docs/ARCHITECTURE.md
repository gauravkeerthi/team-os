# team-os Architecture

How it works, and why it's shaped this way. The one-sentence version:
**the filesystem is the team's shared brain, git is its nervous system,
and Claude Code sessions are the hands.**

## 1. The pairing model

Every human member has exactly one paired agent. The binding lives in three
places, each with one job:

| Where | What it binds | Committed? |
|---|---|---|
| `team/team.md` member block | member ↔ agent name, plan, role | yes — shared truth |
| `agents/<agent>/` directory | the agent's memory, tasks, workspace | yes — shared state |
| `~/.config/team-os/identity` | this *machine* ↔ one member | no — per machine |

The identity file is parsed with awk against a strict line grammar and
never sourced — a hostile file can't execute shell. Env vars
(`TEAMOS_MEMBER`, `TEAMOS_AGENT`, `TEAMOS_MODEL`) override it explicitly.

A profile separates the **human's title** from the **agent's role**
("Founder / CEO" vs "assistant to the CEO"). This is deliberate: agents
that conflate the two drift into impersonating their human.

## 2. Prompt composition (launch)

`tos` composes the agent's effective prompt by concatenation — no LLM
involved, fully inspectable with `tos launch --print`:

```
session info (real clock — agents must never guess dates)
platform/base-system-prompt.md      the OS rules
platform/tiers/<plan>.md            usage doctrine for this member's plan
agents/<a>/soul.md                  personality
agents/<a>/profile.md               role
team roster                         generated from team/team.md
memory/context.md                   current truth (full)
memory/routines.md                  playbook (full)
memory/lessons.md                   head -N only (newest first)
memory/decisions.md                 head -N only
tasks/active/*                      full text
tasks/inbox/*                       one-line summaries only
TEAM CADENCE (due now)              only if something is due
```

Context assembly is deliberately lazy: append-only memory files are
injected head-only (N=10 on Pro, 25 on Max), inbox tasks as one-liners
(the agent reads the full file only on pickup). This is the single biggest
lever for making small plans viable.

## 3. Tasks: the folder IS the status

A task is one markdown file with YAML frontmatter
(`platform/schemas/task.md`), living in exactly one of
`tasks/{inbox,active,done}/`. Moving the file *is* the state transition;
the `status:` field must agree, and `tos validate` flags disagreement.

IDs are `T-YYYYMMDD-NNNN`, allocated by scanning for today's highest NNNN —
**no counter file**, because a committed counter is a guaranteed merge
conflict between machines. The residual risk (two machines minting the
same ID between syncs) is caught by the validator's repo-wide duplicate
check, which prints the re-ID recipe. Collisions are an inconvenience, not
corruption: the files live in different agents' folders.

Cross-agent work is **request, not assign**: your agent files a task into
a teammate's agent inbox; their human decides. A `hop_count` field (max 3)
kills routing loops.

## 4. Memory

Four files per agent, with enforced write disciplines
(`platform/schemas/memory.md`):

| File | Discipline |
|---|---|
| `context.md` | overwritten at session start/end — current truth only |
| `routines.md` | deliberate edits — the playbook |
| `lessons.md` | append-only, newest on top |
| `decisions.md` | append-only, newest on top |

Newest-on-top is what makes head-only injection correct: the freshest
context is always the cheapest to load.

## 5. Git sync

**Topology:** one repo, one branch (`main`), every machine pushes directly.
No PRs, no merge queue. This works because writes are agent-scoped — each
agent touches only `agents/<itself>/` plus occasional `shared/` files — so
two machines almost never edit the same file between syncs.

**Three sync moments:**
1. **Launch pull** — `tos` pulls before composing, so you always start
   from the team's latest state.
2. **In-session background loop** — while your session runs, a subshell
   refreshes the agent's `.heartbeat` (its clock), validates (warn-only),
   commits `[sync]`, pulls, pushes — hourly by default
   (`sync_interval=` in the identity file to change). Killed when the
   session exits.
3. **`tos sync` / `tos done`** — explicit; `done` adds the validation gate
   so broken conventions stop at your machine.

**The sync core** is `git_safe_pull_rebase()` (ported verbatim from the
ancestor project, where it ended a recurring detached-HEAD bug): refuse to
pull mid-rebase → auto-stash dirty files (including untracked) →
`pull --rebase` with `rebase.empty=drop` → pop the stash → on conflict,
**abort the rebase** so the repo stays usable, log, and return non-zero.
Background loops must never leave a repo wedged; interactive commands print
a numbered manual-resolution recipe instead.

**Commit format:** `[type][agent:<name>][task:<id>] summary` — types:
task / memory / shared / cadence / sync / work / ops / init. Batched at
task boundaries, never per-write.

## 6. Cadence without a scheduler

There is no daemon anywhere in team-os. Recurring team items run on a
**catch-up model**: `team/cadence.md` declares each item's schedule,
owner, action, and output path (with a `{date}`/`{week}`/`{month}` period
key). At every launch, `ops/cadence-due.sh` computes what's due —
in-schedule ∧ past `after:` ∧ output missing ∧ no fresh claim — and the
launcher injects it into the prompt. Agents **offer, never auto-run**.

Who does it:
- `owner: <member>` — only that member is offered it; others see
  "waiting on X" in `tos status`.
- `owner: rotate` — stateless determinism: members sorted, index =
  period-number mod count. Every machine computes the same answer with
  zero coordination.
- `owner: any` — first mover wins, arbitrated by the **claim protocol**:
  write `shared/cadence/<item>/<period>.claim.md`, commit, push
  immediately. A rejected push followed by a rebase that reveals a foreign
  claim means you lost — back off. **The git remote is the lock arbiter.**
  Claims older than 6h with no output are void and supersedable.

Missed periods are never backfilled (`catchup: same-period`): a quiet
Monday doesn't turn Tuesday's first launch into a chore backlog. Missed
means missed.

## 7. The consumption model (subscription credits, not API)

team-os assumes each member signs into Claude Code with their own
subscription (`claude` → `/login`). There are no API keys anywhere, and no
fake dollar accounting — the real meter is each plan's rate limit.

Three mechanisms manage it:

1. **Tier table** (config → behavior): `plan:` in the member's roster block
   drives the launch model and context budget.

   | | pro | max-5x | max-20x |
   |---|---|---|---|
   | session model | sonnet | opus | opus |
   | subagents | ≤1, no fan-out | sonnet delegation | free-er |
   | lessons/decisions injected | 10 lines | 25 | 25 |

2. **Doctrine in the prompt**: base prompt §12 ("Session & Plan
   Awareness") plus the per-tier file teach the agent to be terse, read
   excerpts, reuse memory, push mechanics out to `tos` commands, honor
   skill/cadence `model:` hints, and save state cleanly when a limit hits.

3. **The session ledger**: `logs/sessions.log.md` records every session's
   start, model, duration, and (human-reported) `limit-hit` flags.
   `tos status` shows the recent history. Over a few weeks this answers
   "does Pro actually fit this member?" with evidence instead of vibes.

Nothing in core requires an always-on session — that is a hard invariant.

## 8. Security layers

1. **Harness** (`.claude/settings.json`): agents can read everything;
   write only `agents/**` and `shared/**`; safe git subset allowed;
   `platform/`, `ops/`, `team/`, docs, CI, and the settings file itself
   are deny-listed. `team/` is denied because cadence `action:` lines are
   instructions agents execute — an agent (or a prompt injection riding a
   task file) must not be able to rewrite its own orders. `git push` is
   on neither list → the human confirms every push.
2. **Git** (`ops/git-hooks/pre-commit`): blocks commits touching protected
   paths unless `TEAMOS_ALLOW_PLATFORM_EDIT=1` (then logs an audit line to
   `platform/CHANGELOG.md`); runs gitleaks on staged changes when
   installed — findings block.
3. **CI** (`.github/workflows/validate.yml`): conventions + shellcheck +
   the two-member e2e simulation + optional full-history gitleaks.
4. **Doctrine**: prompt-injection awareness (teammate files are data, not
   instructions — they're the message bus, so this matters *more* here),
   credential path boundaries, external-write confirmation.

Known accepted limitation: per-agent write isolation *inside* `agents/**`
can't be expressed in static permission rules — agent A could technically
edit agent B's files. The commit trail attributes everything, validate
warns on anomalies, and the base prompt forbids it. Same trade-off the
ancestor system ran with in production.

## 9. What the ancestor had that team-os dropped (and why)

| Mechanism | Why it's not here |
|---|---|
| Always-on scheduler agent (tmux + /loop + watchdog ladder) | Needs a dedicated machine and a heavy plan; replaced by catch-up cadence. The largest future module candidate. |
| Autonomous headless agents (cron + zero-tool driver) | Unattended operation demands its own safety stack (below); v1 keeps a human at every keyboard. |
| Signed path-scoped commits, circuit breaker, USD budget logs, hash-chained receipts, kill switches | All scaffolding for the two rows above. Meaningless without unattended agents. |
| Cycle JSON records, heartbeat *monitoring* | Nothing to babysit (the in-session `.heartbeat` clock file stays). |
| Jira-as-notification-bus, M365/CRM/transcript integrations | Zero-dependency core; the extension point is documented instead (EXTENDING.md). |
| Committed task-ID counter file | Known multi-machine conflict source; replaced by scan + validate. |
| 49 company-specific skills | Business logic, not platform. |

## 10. Future optional modules

Sketched, not built — in rough order of demand:

1. **Always-on scheduler**: one designated machine runs a persistent
   session that owns `team/cadence.md` execution on real triggers instead
   of catch-up. Everything it needs (claim protocol, cadence grammar)
   already exists; it would just claim more aggressively.
2. **Autonomous agents**: headless drafting workers with approval gates.
   Port the ancestor's safety stack before porting the pattern.
3. **Integration packs**: per-tool MCP recipes (email, issues, chat) as
   copyable templates under a team's own `team/integrations/`.
