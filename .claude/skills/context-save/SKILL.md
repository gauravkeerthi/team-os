---
name: context-save
description: >
  Save working state so a future session can resume without re-deriving
  anything. Writes a one-page snapshot — git state, tasks in flight,
  decisions made, concrete next steps, open questions — to
  workspace/private/context/ and points memory/context.md's Open loops at
  it. Runs automatically as the last model action of /close. Triggers:
  "/context-save", "save progress", "save state", "save my work",
  "checkpoint this".
recommended_model: sonnet
---

# /context-save — Save Working State

Capture where the work stands so `/context-restore` can pick it up cold.
This skill records state only — it never changes code, tasks, or anything
beyond the snapshot and one section of context.md. `<you>` = your agent
name.

## When to use

- Automatically at session end — `/close` invokes it (base prompt §17).
- Before a risky or long step you might not come back from.
- The moment you hit a rate limit mid-task (§12): save, state exactly where
  you stopped, stop.

## Steps

### 1. Gather git state

```bash
git branch --show-current
git status --porcelain
git log --oneline -10
```

### 2. Write the snapshot
Path: `agents/<you>/workspace/private/context/<YYYY-MM-DD>-<slug>.md`.
`<slug>` = 2-4 lowercase kebab-case words naming the work (e.g.
`q3-review-draft`). Read `agents/<you>/.heartbeat` if today's date is
uncertain. Same day + same work = overwrite the existing snapshot (latest
truth wins); a different piece of work gets its own slug.

Format — the whole file stays under a page:

```markdown
---
saved_at: <ISO-8601>
agent: <you>
branch: <branch>
---
# Snapshot — <slug>

## Git state
- Branch: <branch>
- Uncommitted: <paths from --porcelain, or "clean">
- Recent commits: <top 3, one line each>

## In flight
- <task-id> — <one-line state: what's done, what's mid-air>

## Decisions this session
- <decision + one-line why>

## Next steps
1. <concrete and resumable — a cold reader could start here>

## Open questions for the human
- <anything that needs a human answer before work can continue>
```

Non-obvious decisions also belong in `memory/decisions.md` (newest on top)
— the snapshot line is a pointer, not the record.

### 3. Point context.md at the snapshot
Update the `## Open loops` section of `agents/<you>/memory/context.md` to
reference the snapshot, e.g.:
`- Mid-task on T-20260705-0002 — see workspace/private/context/2026-07-05-q3-review-draft.md`.
Bump `updated_at`. Touch nothing else in the file.

### 4. Confirm
One line back to the human: snapshot path, branch, N uncommitted files,
"resume with /context-restore".

## Hard rules

- State capture only — never modify code, task files, or memory beyond
  context.md's Open loops section.
- Next steps must be executable cold. "Continue the draft" is not a next
  step; "draft section 3 of shared/handoffs/q3-review.md — outline is at
  the top of that file" is.
- Under a page. A snapshot nobody can skim is a snapshot nobody reads.
- Include the branch and uncommitted files every time — drift detection in
  /context-restore depends on them.
