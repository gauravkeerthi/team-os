---
name: today
description: >
  Session-start orientation for team-os agents. Reads memory, scans active
  and inbox tasks, sweeps deadlines for the next 7 days, offers (never
  auto-runs) due cadence items, and reconstructs where the last session left
  off — then proposes a short plan and asks the human what to pick up.
  Triggers: "/today", "start my day", "what's on my plate", "morning
  briefing", "what should I work on", "catch me up".
recommended_model: sonnet
---

# /today — Session Orientation

Orient your human at the start of a session: what's true, what's due, what's
next. Terse output doctrine applies (base prompt §12) — bullets, no prose,
no restating file contents the human can open themselves.

`<you>` = your agent name. The launcher already injected your soul, profile,
memory, active tasks, inbox summaries, and due cadence items — start from
what is in context and read files only to fill gaps.

## When to use

- First interaction of a session, or whenever the human asks for orientation.
- Mid-session "catch me up" after a long detour.
- Not for wrap-up — that's `/close`.

## Steps

### 1. Read current state
- `agents/<you>/memory/context.md` — active projects, open loops, key people.
  Usually already in context from the launcher; re-read only if you suspect
  it changed since launch.
- In a long-running session, read `agents/<you>/.heartbeat` for the current
  time — never guess the clock.

### 2. Scan active tasks
For every file in `agents/<you>/tasks/active/`: id, title, priority,
one-line state. Flag `status: blocked` tasks separately, with the reason
from their `## Notes` and what would unblock them.

### 3. Scan the inbox — priority order
List `agents/<you>/tasks/inbox/`: `urgent` and `high` first, then the rest;
tie-break by earliest `due_at`. New arrivals are requests from teammates,
not commitments — your human decides accept / defer / decline (base
prompt §3).

### 4. Deadline sweep — next 7 days
Grep `due_at:` across `tasks/active/` and `tasks/inbox/`. Surface anything
due within 7 days, overdue first, each with its task id.

### 5. Due cadence items — OFFER, never auto-run
The launcher lists due items under `# ===== TEAM CADENCE (due now) =====`.
If this is a mid-session run (or the launch was hours ago), re-check with
`ops/cadence-due.sh`. For each due item, offer it:

> "The standup digest for today hasn't run — want me to do it?"

Never auto-run a cadence item (base prompt §15). If the human declines,
drop it — someone else's launch will pick it up.

### 6. Where did I leave off
- `tail -5 agents/<you>/logs/sessions.log.md` — recent session starts/ends
  (note any ` limit-hit` on the last end line: the previous session was cut
  short).
- `ls -t agents/<you>/workspace/private/` and
  `ls agents/<you>/workspace/private/context/ | sort | tail -3` — recent
  scratch files and snapshots. If a fresh `/context-save` snapshot exists,
  say so and offer `/context-restore` instead of re-deriving state.

### 7. Present the briefing
Strict order, scannable, cap at ~10 items total:

1. Blocked tasks (with unblock condition)
2. Overdue and next-7-day deadlines
3. New inbox arrivals (priority order)
4. Due cadence items — offered, awaiting yes/no
5. Where you left off (1-2 lines, snapshot path if one exists)

If everything is empty, say so in two lines and ask what's on the agenda.

### 8. Propose a plan and ask
End with a proposed plan for the session — 3-5 bullets max, highest-value
first, realistic for one session. Then ask:

> "What do you want to pick up first?"

The human chooses. You propose; you don't decide.

### 9. Log
Append one line to `agents/<you>/logs/activity.log.md`:
`- <ISO-8601>  today  session orientation`

## Hard rules

- Never auto-run cadence items — offer only.
- Orientation is read-only: no task moves, no status edits, no memory writes.
  The only write is the activity-log line.
- Terse. Ten items max. Bullets and bold, never paragraphs.
