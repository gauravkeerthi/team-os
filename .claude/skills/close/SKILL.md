---
name: close
description: >
  Session wrap-up ritual for team-os agents. Reconciles every task file
  against reality, rewrites memory/context.md as current truth, appends new
  lessons and decisions, logs the session, notes a rate-limit hit in the
  session ledger if one happened, runs /context-save as the final model
  action, and hands the closing commit to the human's `tos done`. Triggers:
  "/close", "wrap up", "end session", "session done", "let's close out".
recommended_model: sonnet
---

# /close — Session Wrap-Up

End the session so the filesystem IS the handoff. There is no hidden state
in team-os — if it isn't on disk when the session ends, it never happened.
`<you>` = your agent name.

## When to use

- The human said `/close`, "wrap up", "end session", or is about to leave.
- You sense the session nearing the plan's rate limit (base prompt §12) —
  suggest closing at a natural boundary rather than mid-task.

## Steps

### 1. Reconcile tasks
Walk every file in `agents/<you>/tasks/active/`:

- **Finished this session** → move to `tasks/done/`, set `status: done`,
  bump `updated_at`, append an `## Activity` line, and confirm the output
  landed where `expected_output.location` says it must.
- **Blocked** → leave in `active/`, set `status: blocked`, record why in
  `## Notes` (what's missing, who can unblock).
- **Untouched** → leave alone; don't bump timestamps you didn't earn.

Folder and `status:` must agree on every file — `ops/validate.sh` (run by
`tos done`) flags disagreements.

### 2. Update memory/context.md — overwrite style
Rewrite `agents/<you>/memory/context.md` to be true RIGHT NOW: active
projects, open loops, key people this week. Bump `updated_at` in the
frontmatter. Write it for a reader with zero memory of today — the next
session trusts this file blind.

### 3. Append lessons and decisions
Newest on top, formats from `platform/schemas/memory.md`:

- `memory/lessons.md` — one entry per lesson learned:
  `## YYYY-MM-DD — <lesson>` + **Why** + **How to apply**.
- `memory/decisions.md` — one entry per non-obvious choice:
  `## YYYY-MM-DD — <decision>` + **Rationale** + **Reversible:** yes/no.
- `memory/routines.md` — edit only if a standing procedure genuinely
  changed. Routines are deliberate, not per-session.

Never edit past entries — supersede with a new one that references the old.
No lessons or decisions this session? Skip — don't manufacture entries.

### 4. Log the session
Append one line to `agents/<you>/logs/activity.log.md`:
`- <ISO-8601>  session-close  <one-line summary of what the session produced>`

### 5. Rate-limit note (only if it happened)
If the human mentioned hitting their plan's rate limit this session, append
` limit-hit` to the most recent `- <ISO> end (~Nm)` line in
`agents/<you>/logs/sessions.log.md`. If no end line exists yet (launch.sh
writes it when the session process actually exits), add a note line
instead: `- <ISO> note limit-hit`.

### 6. Run /context-save
Invoke `/context-save` as the final model action of the session (base
prompt §17). It writes the resumable snapshot and points context.md's Open
loops at it. No permission needed — it is part of the standard close-out.
Skip only if the human explicitly says "don't bother saving".

### 7. Hand off to the human
Show a terse summary: tasks moved (with ids), memory files touched, lessons
or decisions added, snapshot path. Then remind:

> "Run `tos done` — it validates, commits, and pushes."

`tos done` is the human's command; do not run it yourself.

## Hard rules

- **Never skip the context.md update.** A stale context.md poisons every
  future session.
- **Never leave a task file whose folder and `status:` disagree.**
- Persist everything to disk — never show an update only in chat.
- `lessons.md` and `decisions.md` are append-only, newest on top.
- Scale the ritual to the session: a five-minute session needs the task
  check, the context.md check, the log line, and the snapshot — not an
  essay. But it always needs those.
