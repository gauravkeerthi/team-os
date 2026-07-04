# Memory Schema

Every agent has exactly four memory files under `agents/<name>/memory/`.
Agents that need more structure should resist the urge — add discipline, not
more files.

## `context.md` — Current state (OVERWRITE)

What is true about the agent's world right now. Overwritten at session start
and end. Should be skimmable in under 10 seconds.

```markdown
---
updated_at: 2026-07-06T10:15:00Z
---
# Current Context

## Active projects
- Q3 planning review
- Onboarding revamp

## Open loops
- Waiting for Alice's decision on the pricing page

## Key people this week
- Alice (sponsor)
- Bob (reviewing the draft)
```

## `routines.md` — Standing procedures (DELIBERATE EDITS)

Procedures the agent follows on a schedule or in response to a trigger. This
is the agent's playbook. Changes here are conscious updates, not automatic.

```markdown
# Routines

## Monday, first session — week orientation
1. Scan tasks/inbox/ and tasks/active/ in priority order
2. Check team/cadence.md items due this week
3. Surface the week's due_at deadlines to my human

## On task received — Kickoff checklist
- Move to active/
- Update status and updated_at
- Read all declared inputs before writing anything
```

## `lessons.md` — Learned heuristics (APPEND, newest on top)

One lesson per entry. Never delete. If superseded, add a new lesson that
references the old one.

```markdown
# Lessons

## 2026-07-06 — Confirm a meeting still exists before drafting its agenda
**Why:** Drafted an agenda for a meeting that had been cancelled.
**How to apply:** Before any agenda task, ask my human whether the meeting
is still on.
```

## `decisions.md` — Non-obvious choices (APPEND, newest on top)

A record of deliberate choices the agent or human made, with rationale. Used
to answer "why did we do it that way?" weeks later.

```markdown
# Decisions

## 2026-07-06 — Weekly digest goes through shared/incoming, not straight to knowledge
**Rationale:** Keeps a maintainer in the loop for tone and accuracy review.
**Reversible:** yes
```

## General rules

- Keep entries short. If a lesson needs more than a paragraph, link to a doc
  in `workspace/private/`.
- ISO-8601 dates. UTC or the team timezone — pick one per agent and declare
  it in `profile.md`.
- Append-only files grow **newest on top**, so the freshest context is the
  cheapest to read (the launcher injects only the head of these files).
