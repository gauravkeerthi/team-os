# Git Commit Format

team-os is git-backed. Commits should be **batched** (one commit per agent
session or per task transition), never per-write.

## Format

```
[<type>][agent:<name>][task:<id>] <short summary>
```

### Types

| Type | Use for |
|---|---|
| `task` | Task state transitions (inbox/active/done, status changes) |
| `memory` | Updates to memory/*.md |
| `shared` | Writes under shared/ (incoming, knowledge, handoffs) |
| `cadence` | Cadence claims and cadence outputs |
| `sync` | Mid-session and background sync commits |
| `work` | End-of-session sync commits produced by `tos done` |
| `ops` | Changes to platform/, ops/, .claude/ (maintainers only) |
| `init` | Team bootstrapped or new member added |

### Examples

```
[task][agent:piper][task:T-20260706-0001] picked up Q3 review, moved to active
[memory][agent:ajax][task:-] +lesson about confirming meetings before agenda drafts
[shared][agent:piper][task:T-20260706-0001] review posted to shared/handoffs/
[cadence][agent:ajax] claim standup-digest 2026-07-06
[sync][agent:ajax] background sync
[work][agent:piper] session sync
[init][agent:-] team-os configured for Acme Robotics
```

If the commit spans agents or isn't task-scoped, use `[agent:-]` and
`[task:-]`.

## Anti-patterns

- Don't commit every file write. Batch at task boundaries.
- Don't commit `workspace/private/` scratch junk you don't need later —
  clean it up first.
- Don't commit secrets, credentials, or bulk-pasted external content
  (web pages, exported threads). Summarize and link; don't dump.
