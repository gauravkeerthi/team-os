# Cadence Format

`team/cadence.md` defines the team's recurring items. There is no scheduler
daemon: `ops/cadence-due.sh` evaluates this file at every launch (and in
`tos status`), and due items are surfaced to whichever human launches next.
This file is **edited by humans only** (it is on the agent deny list,
because `action:` lines are instructions agents execute).

## File shape

```markdown
---
catchup: same-period
---
# Team Cadence

### cadence: standup-digest
- schedule: weekdays
- after: 09:00
- owner: any
- action: /standup-prep --digest
- output: shared/cadence/standup-digest/{date}.md
- model: sonnet

### cadence: weekly-retro
- schedule: weekly:fri
- after: 15:00
- owner: rotate
- action: /retro
- output: shared/cadence/weekly-retro/{week}.md
- model: sonnet
```

## Fields

| Key | Values | Meaning |
|---|---|---|
| `schedule` | `daily` \| `weekdays` \| `weekly:<mon..sun>` \| `monthly:<1-28>` | When the item recurs |
| `after` | `HH:MM` (24h, team timezone from `team/team.md`) | Item is not due before this local time |
| `owner` | `any` \| `<member-id>` \| `rotate` | Who runs it (see below) |
| `action` | a skill invocation or short instruction | What the executing agent runs |
| `output` | repo path containing a period key | Where the result must land |
| `model` | `sonnet` \| `opus` \| `haiku` | Cost hint — executing agent honors it per base prompt §12 |

## Period keys

Exactly one period key must appear in `output:`; it defines the item's
period and its "already done?" check:

| Key | Renders as | Period |
|---|---|---|
| `{date}` | `YYYY-MM-DD` | one calendar day |
| `{week}` | `GGGG-Www` (ISO week, e.g. `2026-W28`) | one ISO week |
| `{month}` | `YYYY-MM` | one calendar month |

## Due logic

An item is **DUE** iff all of:

1. Today matches `schedule` (in the team timezone).
2. Local time is past `after:` (if set).
3. The rendered `output` path does not exist.
4. No fresh claim file exists (see below).

`catchup: same-period` (the only supported policy in v1) means an item is
only ever surfaced **within its own period**. A Tuesday launch never
backfills Monday's `{date}` item; a new week never re-opens last week's
retro. Missed means missed — by design, so a quiet week doesn't greet
Monday's first launch with a wall of stale chores.

## Ownership

- `owner: <member-id>` — surfaced only when that member launches. Everyone
  else sees "waiting on <member>" in `tos status`.
- `owner: rotate` — deterministic and stateless: sort member ids
  alphabetically; index = (period number) mod (member count), where the
  period number is the day-of-year for `{date}` items, the ISO week number
  for `{week}` items, and the month number for `{month}` items. Every
  machine computes the same owner with zero coordination.
- `owner: any` — first mover runs it, arbitrated by the **claim protocol**.

## Claim protocol (`owner: any`)

The git remote is the lock arbiter — no daemon, no server:

1. Before executing, write
   `shared/cadence/<item>/<period>.claim.md` containing member id, agent
   name, and an ISO timestamp.
2. Commit (`[cadence][agent:<name>] claim <item> <period>`) and **push
   immediately**.
3. If the push is rejected: rebase (`ops/sync.sh` does this safely). If a
   claim by someone else now exists, **back off** — they won the race. If
   your claim survived the rebase, proceed.
4. Execute the `action:`, write the `output:` file, commit, sync.

**Stale claims:** a claim older than 6 hours with no output file is void.
The next claimer may supersede it — note the supersession inside the new
claim file. Claim files are small and kept; they double as the audit trail
of who ran what.
