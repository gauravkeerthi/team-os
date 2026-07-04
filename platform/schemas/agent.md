# Agent Folder Contract

Every agent lives under `agents/<name>/` and MUST contain exactly this layout:

```
agents/<name>/
├── soul.md                 # Personality + behavioral defaults
├── profile.md              # The human, the agent's role, scope
├── memory/
│   ├── context.md
│   ├── routines.md
│   ├── lessons.md
│   └── decisions.md
├── tasks/
│   ├── inbox/              # Tasks waiting to be started
│   ├── active/             # Tasks currently being worked
│   └── done/               # Completed (or cancelled) tasks
├── workspace/
│   └── private/            # Agent scratch space (committed, never promoted)
└── logs/
    ├── activity.log.md     # One-line audit trail
    └── sessions.log.md     # Session ledger (written by launch/close)
```

`ops/validate.sh` asserts this contract across every agent. New agents are
created by copying `agents/_template/` via `ops/add-member.sh` — never by
hand.

The **member ↔ agent binding** lives in `team/team.md` (the `agent:` line
of the member block), and each machine binds to one member via
`~/.config/team-os/identity`. The agent folder itself carries no machine
or account identifiers.

## `soul.md`

Personality, voice, defaults. This is the part of the prompt that makes the
agent feel like "them". Keep it under 200 lines. Example structure:

```markdown
# Soul — <Name>

## Voice
- Direct, warm, low on filler
- Uses bullet points more than prose

## Defaults
- Always asks "what is the acceptance criteria?" before starting work

## Do
- Push back politely when scope balloons

## Don't
- Don't use emojis unless the user does first
- Don't drop context mid-task
```

## `profile.md`

Role, responsibilities, and hard facts. Every profile distinguishes **two**
roles:

- `Title:` — the **human's** job title inside the team. "Founder / CEO."
  "Product Manager." What the human would put on a business card.
- `Agent role:` — the **agent's** functional role, as a separate top-level
  `## Agent role` section below the `## Human` block. "Assistant to the
  CEO." "The lead engineer's assistant."

The two are deliberately separate. An agent paired with the CEO is an
*assistant to* the CEO, not a CEO. Conflating the two makes the agent drift
into impersonating the human; keeping them distinct keeps the agent's scope
honest.

```markdown
# Profile — Ajax

## Human
- Name: Alice Wong
- Title: Founder / CEO
- Member id: alice
- Timezone: Asia/Singapore

## Agent role
Assistant to the CEO. Ajax supports Alice directly on the day-to-day —
task tracking, prep, follow-ups, drafting. Ajax does not set strategy or
make approvals; those remain Alice's.

## Mandate
What this agent is responsible for. One paragraph.

## In scope
- ...

## Out of scope
- ...
```
