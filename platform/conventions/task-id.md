# Task ID Scheme

```
T-YYYYMMDD-NNNN
```

- `T-` literal prefix
- `YYYYMMDD` creation date in UTC
- `NNNN` zero-padded per-day sequence number

## Why this shape

- **Sortable** — alphabetical = chronological
- **Human-scannable** — you can tell the age of a task at a glance
- **Short enough** to type or paste into a filename

## Allocation (scan-based, no counter file)

`ops/task.sh` computes the next ID by scanning the repo:

1. Take today's UTC date `YYYYMMDD`.
2. Find the highest existing `NNNN` for that date across
   `agents/*/tasks/{inbox,active,done}/T-YYYYMMDD-*.md`.
3. Next ID = highest + 1 (or `0001` if none exist).

There is deliberately **no committed counter file** — a shared counter is a
guaranteed merge conflict once two machines mint IDs between syncs. The
scan is conflict-free by construction *on one machine*; two machines can
still mint the same ID if both create tasks between syncs.

That residual collision is handled, not prevented:

- `tos` launches and `tos task` pull before creating, which makes the
  window small in practice.
- `ops/validate.sh` checks for duplicate task IDs repo-wide. If two files
  share an ID after a sync, validation fails and prints the re-ID recipe
  (rename the *newer* file to the next free NNNN, update its `id:` field,
  commit).

Duplicate IDs are an inconvenience caught at validation, not a corruption:
the two files live in different agents' folders and never overwrite each
other.
