---
name: standup-prep
description: >
  Build a standup update (yesterday / today / blockers) from files and git
  alone — team-os has no external systems to query. Default mode covers your
  own agent and writes to workspace/private/; --digest mode sweeps ALL
  agents into a one-page team digest and is what the standup-digest cadence
  item runs. Triggers: "/standup-prep", "/standup-prep --digest", "prep my
  standup", "standup update", "what do I say in standup".
recommended_model: sonnet
---

# /standup-prep — Standup Update

Synthesize what happened, what's next, and what's stuck — from the repo
only. Evidence in, bullets out. `<you>` = your agent name; `<human>` = your
human.

## When to use

- Default mode: your human wants their personal update before a standup.
- `--digest`: the team-wide digest — normally the `standup-digest` cadence
  item, offered to (and accepted by) your human per base prompt §15.

## Steps — default (personal) mode

### 1. Establish the window
"Yesterday" = since yesterday 00:00 in the team timezone (from
`team/team.md`). Read `agents/<you>/.heartbeat` if unsure of the current
time.

### 2. Pull evidence — four sources
- `git log --since=yesterday --oneline` filtered to `[agent:<you>]`
  commits — work that shipped.
- `tail -20 agents/<you>/logs/activity.log.md` — actions in the window.
- `agents/<you>/tasks/done/` — files whose `updated_at` falls in the
  window.
- `agents/<you>/tasks/active/` — current work: note `status: blocked`
  files (with the `## Notes` reason) and any `due_at` today or tomorrow.

### 3. Dedupe
One piece of work often appears as a commit AND a log line AND a done file.
Report it once — prefer the task-file framing, which carries the title.

### 4. Bucket into three sections
- **Yesterday** — done-folder moves, commits, shipped artifacts.
- **Today** — active tasks in priority order; anything due today leads.
- **Blockers** — blocked tasks with who/what would unblock them; requests
  filed to teammates still awaiting a response.

### 5. Write and show
Max 5 bullets per section, verb-first, no filler. Write to
`agents/<you>/workspace/private/standup-<YYYY-MM-DD>.md`:

```markdown
---
date: <YYYY-MM-DD>
agent: <you>
generated_at: <ISO-8601>
---
# Standup — <human> — <YYYY-MM-DD>

## Yesterday
## Today
## Blockers
```

Show the same content in the session, path first. Append one line to
`agents/<you>/logs/activity.log.md`:
`- <ISO-8601>  standup-prep  <date> update; Ny/Nt/Nb bullets`

## Steps — --digest (team) mode

### 1. Sweep all agents
Same window, team-wide:

- `git log --since=yesterday --oneline` — group subjects by their
  `[agent:<name>]` tag; count commits per agent.
- Every `agents/*/tasks/done/` — files with `updated_at` in the window.
- Every `agents/*/tasks/active/` — `status: blocked` files only.
- `due_at:` across all agents' `active/` + `inbox/` — team deadlines in the
  next 48h.

### 2. Compose the one-page digest
One block per agent with activity: shipped (max 3 bullets), blocked (all,
with reasons). Skip silent agents — list them in a single closing line
("No activity: x, y"). End with the team-level deadlines. Whole digest fits
on one page.

### 3. Cadence plumbing (when run as the standup-digest cadence item)
1. If the item's `owner:` is `any`, run the claim protocol BEFORE
   executing: write the claim file, commit, push via `ops/sync.sh`, back
   off if someone else's claim survives the rebase (base prompt §15,
   `platform/conventions/cadence-format.md`).
2. Write the digest to the item's declared output path —
   `shared/cadence/standup-digest/<YYYY-MM-DD>.md`.
3. Commit: `[cadence][agent:<you>] standup-digest <YYYY-MM-DD>`.
4. Sync: `ops/sync.sh` (pre-approved).
5. Append one line to your activity log.

Run ad hoc instead (not as the cadence item)? Write to
`agents/<you>/workspace/private/standup-digest-<YYYY-MM-DD>.md` — never
fake a cadence output.

## Hard rules

- Files and git only. If a source is empty, the section says so — never
  invent work to fill a bullet.
- Attribute by `[agent:<name>]` commit tag: never present a teammate's work
  as yours or your human's.
- Max 5 bullets per section (digest: 3 shipped per agent). Overflow becomes
  a count ("+3 more in done/"), not a wall.
- Read-only against every other agent's folders — you summarize their work,
  you never touch their files.
