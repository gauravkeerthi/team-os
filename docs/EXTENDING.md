# Extending team-os

Everything here happens in **your team's copy**. Nothing requires touching
`platform/` or `ops/` (and the pre-commit hook will stop you if you try by
accident — see the escape hatch at the bottom).

## 1. Write a skill

Skills are slash-command capabilities under `.claude/skills/`.

**Default: private.** Build new skills at
`.claude/skills/private/<name>/SKILL.md` — that path is gitignored, so you
can iterate freely without pushing experiments into every teammate's
prompt.

```markdown
---
name: my-skill
description: What it does. Triggers: "/my-skill", "natural phrase".
recommended_model: sonnet
---

## When to use
...

## Steps
1. ...
```

Rules of thumb:
- Declare `recommended_model:` honestly — agents honor it per base prompt
  §12 (a Pro member's sonnet session will run it as-is; an opus session
  may delegate it down).
- Skills read and write only `agents/<you>/**` and `shared/**` — the same
  boundary agents live in.
- To **share** a skill: move it from `skills/private/` to
  `.claude/skills/<name>/` and commit — any human can. It lands in every
  teammate's context, so a heads-up to the team is good manners.

The seven shipped skills are upstream-owned (they get updated by
`tos update`) — copy one as a starting point rather than editing in place.

## 2. Add a cadence item

Edit `team/cadence.md` (humans edit this file directly — agents are
deny-listed from it). Grammar: `platform/conventions/cadence-format.md`.

```markdown
### cadence: friday-shoutouts
- schedule: weekly:fri
- after: 16:00
- owner: rotate
- action: collect this week's wins from tasks/done/ across agents into a short, warm post
- model: sonnet
- output: shared/cadence/friday-shoutouts/{week}.md
```

Commit + `tos sync`. That's the whole deployment. The `action:` can be a
skill invocation (`/retro`) or a short plain-language instruction.

## 3. Add an MCP integration (email, issues, chat, …)

Core ships zero integrations on purpose. The pattern for adding your own,
per user, without committing secrets:

1. **Project `.mcp.json` is gitignored.** Each member generates their own
   locally. Commit a *template* instead, e.g.
   `team/integrations/gmail.mcp.template.json`, with a
   `REPLACE_WITH_YOUR_EMAIL` placeholder.
2. Add a tiny generator script in `team/integrations/` (team-owned, so no
   hook fight) that copies the template to the repo root as `.mcp.json`
   with the member's value filled in. Or members hand-edit — it's one file.
3. Each member allowlists the new `mcp__<server>__*` tools in their
   **`.claude/settings.local.json`** (gitignored, per machine) — not in
   the committed `.claude/settings.json`.
4. Document member-specific bindings as a line in the member's
   `profile.md` (e.g. `- Email account: alice@acme.com`) so the agent
   knows which mailbox is whose.

Non-negotiable rules for any integration (base prompt §16):
- **Non-destructive** — agents never delete data in external systems.
- **Fail loudly** — unreachable integration ⇒ log, block the task, say so.
- **External-write confirmation** (§10) — content that arrived from one
  external system needs a human's OK before being written to another.

Start small: a read-only integration (calendar, inbox summaries) delivers
most of the value with a fraction of the risk.

## 4. Add / remove a member

**Add:** `tos add-member carol "Carol Ng" quinn pro --email carol@acme.com`
then `tos sync`. Carol clones, runs `./ops/onboard.sh`, signs into Claude,
launches.

**Remove (offboard):**
1. Move their agent folder to the archive:
   `git mv agents/quinn shared/archive/2026-07-quinn` (memory is team
   history — archive, don't delete).
2. Delete their `### member:` block from `team/team.md`.
3. Commit, sync. `tos validate` will confirm nothing dangles.

## 5. Governance dials

Governance-lite has one dial: who has `role: maintainer` in `team/team.md`.
Maintainers steward the **platform** — they apply `tos update` and own
protected-path edits. Content needs no gatekeeper: any member promotes to
`shared/knowledge/` (`tos promote` records provenance) and anyone can
archive. One maintainer is required; several is healthier. There are no
other roles — if you need per-folder ACLs and approval chains, team-os is
probably the wrong size of tool.

## 6. The escape hatch (local platform edits)

`platform/`, `ops/`, the shipped skills, docs, and CI are upstream-owned
and hook-protected. When you genuinely need a local change:

```bash
TEAMOS_ALLOW_PLATFORM_EDIT=1 git commit -m "[ops][agent:-] why"
```

The hook appends an audit line to `platform/CHANGELOG.md` so future-you
knows. Expect `tos update` to list those files as differing from upstream
— you'll re-apply your local change after updating (UPGRADING.md). If the
change is generally useful, open a PR against the upstream template
instead and everyone gets it.
