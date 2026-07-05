---
name: reflect
description: >
  Personal biweekly check-in — a gentle mirror on the last two weeks: where
  the time went, what moved, what didn't and why, and whether next week's
  plan matches stated priorities. Walks four questions one at a time, then
  writes a short reflection note and captures any lessons that surfaced.
  Triggers: "/reflect", "am I working on the right things", "where did my
  time go", "biweekly check-in", "am I focusing on the right things".
recommended_model: sonnet
---

# /reflect — Personal Check-In

A mirror, not a performance review. The aim is one honest adjustment, not a
scorecard. Evidence comes from the repo; judgment stays with the human.
`<you>` = your agent name; `<human>` = your human.

## When to use

- Every two weeks or so, when your human wants to step back.
- After a stretch that felt busy but didn't feel productive.
- Not for team weeks (`/retro`) or daily orientation (`/today`).

## Steps

### 1. Gather evidence — quietly, before asking anything
Window: the last 14 days (read `agents/<you>/.heartbeat` for today's date).

- `agents/<you>/logs/sessions.log.md` — how many sessions, roughly how long
  (sum the `(~Nm)` end lines), and any ` limit-hit` markers.
- `agents/<you>/logs/activity.log.md` — what actually got done, per the
  audit trail.
- Throughput: `tasks/done/` files updated in the window vs what sits in
  `tasks/active/` — and how long the active ones have sat (`updated_at`
  age).
- `agents/<you>/memory/context.md` — the stated priorities and active
  projects this period should be measured against.

Distill a 5-line evidence summary. If context.md states no priorities,
note it — that absence may be the real finding.

### 2. Walk the four questions — one at a time
Ask, wait for the answer, reflect it back in a line, then move on. Never
batch the questions. Offer your evidence as a starting point, not a
verdict.

1. **Where did the time go?** Show the session count/hours and the shape of
   the activity log. "Does this match how it felt?"
2. **What moved?** The done tasks and shipped artifacts. Let the human name
   what they're actually glad about — it may not be the biggest item.
3. **What didn't move — and why?** Aging active tasks, blocked items,
   recurring open loops. Help distinguish "blocked on someone", "chose not
   to", and "kept avoiding". The why matters more than the what.
4. **Does next week's plan match your stated priorities?** Hold Q1's answer
   against context.md's priorities. If they diverge, both fixes are
   legitimate: change the plan, or change the priorities.

### 3. Write the reflection note
`agents/<you>/workspace/private/reflections/<YYYY-MM-DD>.md` — half a page,
in the human's own words wherever possible:

```markdown
---
date: <YYYY-MM-DD>
period: <start> to <end>
agent: <you>
---
# Reflection — <YYYY-MM-DD>

## Where the time went
## What moved
## What didn't, and why
## Adjustment for next period
- <1-3 concrete changes>
```

### 4. Capture lessons (if any surfaced)
If the conversation produced a durable lesson, offer to add it to
`agents/<you>/memory/lessons.md` — newest on top, with **Why** and **How to
apply** lines per `platform/schemas/memory.md`. Confirm the wording with
the human before writing. Zero lessons is a fine outcome.

If the priorities themselves changed in Q4, update
`agents/<you>/memory/context.md` to match — otherwise the next /reflect
measures against a dead list.

### 5. Log
Append one line to `agents/<you>/logs/activity.log.md`:
`- <ISO-8601>  reflect  biweekly reflection → workspace/private/reflections/<YYYY-MM-DD>.md`

## Hard rules

- **Gentle by design.** Describe, don't grade: no scores, no streaks, no
  productivity verdicts. If the evidence is uncomfortable, present it
  plainly and let the human draw the conclusion.
- One question at a time — the pauses are the point.
- Evidence over vibes, but the human's reading of the evidence wins.
- Keep the note short: three adjustments max. One change kept beats five
  listed.
