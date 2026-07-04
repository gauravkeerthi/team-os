# Task Schema

Every task is a single markdown file with YAML frontmatter.

## Filename

```
T-YYYYMMDD-NNNN.md
```

- `YYYYMMDD` = creation date (UTC).
- `NNNN` = zero-padded per-day sequence number.
- IDs are assigned by `ops/task.sh` (scan-based — see
  `platform/conventions/task-id.md`). Do not hand-pick IDs.

## Frontmatter fields (required unless noted)

| Field | Type | Notes |
|---|---|---|
| `id` | string | Must match filename |
| `title` | string | One-line imperative title |
| `requester` | string | Member id or agent name that requested this |
| `assigned_to` | string | Agent name currently responsible |
| `status` | enum | `inbox`, `active`, `done`, `blocked`, `cancelled` |
| `priority` | enum | `low`, `normal`, `high`, `urgent` |
| `created_at` | ISO-8601 | UTC |
| `updated_at` | ISO-8601 | UTC, bumped on every mutation |
| `due_at` | ISO-8601 | Optional |
| `inputs` | list of paths | Optional. Files the agent should read first |
| `expected_output` | object | Optional. `{type, location}` — where the output must land |
| `depends_on` | list of task IDs | Optional |
| `tags` | list of strings | Optional |
| `hop_count` | integer | Optional. Times this task has been routed between agents. Max 3 — agents must refuse tasks with `hop_count >= 3` (routing-loop guard) |

## Body sections

```markdown
## Description
<what needs to happen, in prose>

## Acceptance Criteria
- [ ] bullet 1
- [ ] bullet 2

## Notes
<free-form agent working notes — append only>

## Activity
- <ISO-8601>  <actor>  <one-line event>
```

## Lifecycle

```
inbox/  ──►  active/  ──►  done/
             │
             └─► (status: blocked) — stays in active/ with frontmatter flag
             └─► (status: cancelled) — moves to done/
```

Status transitions are enacted by **physically moving the file** between
folders AND updating the `status` field. Both must agree — `ops/validate.sh`
flags disagreements.

## Example

```markdown
---
id: T-20260706-0001
title: Review the Q3 planning draft
requester: alice
assigned_to: piper
status: inbox
priority: high
created_at: 2026-07-06T02:15:00Z
updated_at: 2026-07-06T02:15:00Z
due_at: 2026-07-08T09:00:00Z
inputs:
  - shared/incoming/q3-planning-draft.md
expected_output:
  type: markdown
  location: shared/handoffs/q3-draft-review.md
tags: [review, planning]
---

## Description
Read the Q3 draft and mark up risks, gaps, and anything that contradicts
the current roadmap.

## Acceptance Criteria
- [ ] Every section commented
- [ ] Top-3 risks called out explicitly

## Notes

## Activity
- 2026-07-06T02:15:00Z  alice  created via task.sh
```
