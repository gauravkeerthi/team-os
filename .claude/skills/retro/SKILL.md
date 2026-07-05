---
name: retro
description: >
  Weekly team retrospective built from repo evidence only — done tasks,
  decisions, shared/ activity, commit volume, and cadence hit-rate across
  all agents. Produces Wins / Misses / Decisions made / Patterns / Proposed
  actions, where every action is an offer to file a task via ops/task.sh
  (request, not assign). Default window: last 7 days; accepts --since
  YYYY-MM-DD. Runs as the weekly-retro cadence item. Triggers: "/retro",
  "team retro", "what did we ship this week", "weekly retrospective".
recommended_model: sonnet
---

# /retro — Weekly Team Retrospective

What did the team actually do this week? The repo is the witness — every
claim in the retro must trace to a task file, a memory entry, or a commit.
Distinct from `/reflect` (personal check-in) and `/standup-prep` (daily).
`<you>` = your agent name.

## When to use

- The `weekly-retro` cadence item is due and your human accepted it.
- Anyone wants a look back over the team's week, any time.

## Steps

### 1. Set the window
Default: the last 7 days, ending now (read `agents/<you>/.heartbeat` if
unsure of the date). Override: `/retro --since YYYY-MM-DD` runs from that
date at 00:00 to now. State the window at the top of the output.

### 2. Gather evidence — five sources, all agents
- **Done tasks:** every `agents/*/tasks/done/*.md` with `updated_at` in the
  window — id, title, agent, requester.
- **Decisions:** entries dated in the window at the top of each
  `agents/*/memory/decisions.md` (newest-on-top makes this a cheap head
  read).
- **Shared activity:**
  `git log --since=<start> --oneline -- shared/incoming shared/knowledge shared/handoffs`
  — what moved toward the team.
- **Commit volume:** `git log --since=<start> --oneline`, counted per
  `[agent:<name>]` tag. A signal of where energy went — not a scoreboard.
- **Cadence hit-rate:** for each item in `team/cadence.md`, compare
  expected periods in the window against outputs actually present in
  `shared/cadence/<item>/` — present vs missed, per item.

### 3. Synthesize five sections
Anchor every line in evidence (task id, path, or commit). Never pad.

- **Wins** — shipped or closed work that mattered. 3-6 bullets: what, who,
  why it matters. If the week was thin, say so — a short honest retro beats
  an inflated one.
- **Misses** — expected but didn't happen: tasks blocked all week, past-due
  `due_at`s, missed cadence outputs. Name the miss and the apparent cause;
  no blame.
- **Decisions made** — from decisions.md entries: the decision, whose
  memory it lives in, reversible or not.
- **Patterns** — 2-4 observations only a week-level view reveals ("three
  agents blocked on the same missing input", "shared/incoming grew but
  nothing was promoted"). Highest-value section; every pattern cites its
  data.
- **Proposed actions** — for each: what + suggested owner + the evidence
  behind it. Each action is an OFFER to file a task via
  `ops/task.sh --title "..." --to <agent>`. Filing into a teammate's inbox
  is a request, not an assignment (base prompt §3) — their human decides.

### 4. Write the output
**As the weekly-retro cadence item:**

1. If `owner: any`, run the claim protocol first — claim file, commit, push
   via `ops/sync.sh`, back off if beaten (base prompt §15).
2. Write to the item's declared output path —
   `shared/cadence/weekly-retro/<GGGG-Www>.md` (ISO week).
3. Commit: `[cadence][agent:<you>] weekly-retro <GGGG-Www>`.
4. Sync: `ops/sync.sh` (pre-approved). Log in your activity log.

**Ad hoc:** write to `agents/<you>/workspace/private/retro-<YYYY-MM-DD>.md`
instead — never fake a cadence output.

If last week's retro exists in `shared/cadence/weekly-retro/`, open with a
two-line trend note (done count and miss count vs last week).

### 5. Present and file approved actions
Show the retro, path first. Then walk the proposed actions one at a time —
approve / edit / drop. File only the approved ones with `ops/task.sh`, sync
so they actually arrive, and log each filing.

## Hard rules

- Repo evidence only. No "what probably happened", no invented wins, no
  padded misses. Empty sources = a short retro that says so.
- Actions are requests: never file a task without your human's approval,
  and never present a filed task as committed work.
- Read-only against other agents' folders — you cite their files, you never
  edit them.
- One page. Patterns over lists; specifics over adjectives.
