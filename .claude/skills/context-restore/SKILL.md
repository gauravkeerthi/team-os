---
name: context-restore
description: >
  Resume from the most recent /context-save snapshot. Finds the newest file
  in workspace/private/context/, reads it alongside memory/context.md,
  verifies the git state it describes still matches reality (warns on
  drift), summarizes where you left off in under 10 lines, and proposes the
  first next step. Triggers: "/context-restore", "resume", "where was I",
  "pick up where I left off", "restore context".
recommended_model: sonnet
---

# /context-restore — Resume Working State

Load the last saved snapshot and put the human back exactly where they left
off. Read and summarize only — no code changes, no task moves. `<you>` =
your agent name.

## When to use

- Start of a session that continues earlier work (often right after
  `/today` flags a fresh snapshot).
- After a rate-limit hit cut the previous session short.
- Any "where was I?" moment.

## Steps

### 1. Find the newest snapshot

```bash
ls agents/<you>/workspace/private/context/ | sort | tail -1
```

Filenames are `<YYYY-MM-DD>-<slug>.md`, so name-sort IS chronological —
never use filesystem mtime. If the human names a specific date or slug,
load that file instead of the newest.

If the directory is empty or missing, say: "No saved snapshots — run
`/context-save` at the end of a session to create one." Then stop.

### 2. Read snapshot + context.md
Read the snapshot and `agents/<you>/memory/context.md`. If context.md's
Open loops disagree with the snapshot (context.md was updated later),
context.md wins — flag the difference rather than papering over it.

### 3. Verify git state — warn on drift
Compare the snapshot's recorded state against reality:

```bash
git branch --show-current
git status --porcelain
git log --oneline -5
```

Warn — never silently proceed — if:

- The current branch differs from the snapshot's branch.
- Files the snapshot listed as uncommitted are now missing, committed, or
  further changed.
- New commits landed after the snapshot (check `[agent:<name>]` tags in the
  new subjects — a teammate's agent may have continued the work).

Drift is information, not an error: state what changed and how it affects
the saved next steps.

### 4. Summarize — under 10 lines
"Here's where you left off":

- What was in flight (task ids + one-line state each)
- Decisions already made (so they don't get re-litigated)
- Drift warnings, if any
- Open questions still unanswered

### 5. Propose the first next step
Take next step 1 from the snapshot, adjusted for any drift, and offer it:

> "Pick up here?"

Wait for the human — do not start the work unprompted.

## Hard rules

- Read-only: this skill changes nothing on disk (not even the activity log
  — logging belongs to the work that follows, not the lookup).
- "Most recent" = filename sort. Filenames are stable; mtime is not.
- Never skip the git verification — resuming against drifted state wastes
  the session the snapshot was meant to save.
- Summary stays under 10 lines. The snapshot exists so the human doesn't
  re-read the whole story.
