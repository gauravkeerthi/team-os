# Shared Governance

Everything under `shared/` is team-visible. These rules keep it trustworthy
and clean — with as little ceremony as possible: **any member's human can
promote anything to `shared/knowledge/`.** There is no gatekeeper role for
content. (The `maintainer` role in `team/team.md` exists for *platform*
stewardship — applying `tos update`, owning protected-path edits — not for
approving your teammates' work.)

## Zones

| Folder | Purpose | Who writes |
|---|---|---|
| `shared/incoming/` | Draft zone — work in progress | Any agent |
| `shared/knowledge/` | Team knowledge a human has called ready | Any member (their human decides) |
| `shared/projects/` | Cross-member project working files | Any agent, with a task |
| `shared/handoffs/` | Intermediate artifacts passed between agents | Any agent |
| `shared/cadence/` | Cadence outputs + claim files | The claiming agent, per the cadence protocol |
| `shared/archive/` | Superseded content, kept for history | Any member |

## Rules

1. **Drafting is an agent call; promoting is a human call.** Agents write
   freely to `shared/incoming/`, but never move content into
   `shared/knowledge/` on their own initiative — a human says "this is
   ready" first (their own human is enough).

2. **Promote with `ops/promote.sh`** (or `tos promote`):

   ```bash
   ops/promote.sh shared/incoming/<draft>.md shared/knowledge/<name>.md <task-id>
   ```

   It moves the file and writes a `<dest>.promoted-by` sidecar recording
   who, when, and which task — provenance, not permission. A plain
   `git mv` works too; the sidecar is just the courteous version.

3. **Promotion is a move, not a copy.** Once promoted, the source in
   `incoming/` is gone. Git preserves history.

4. **Shared writes trace to a task or cadence item.** A draft in
   `shared/incoming/` with no task reference is orphaned; `tos validate`
   warns when one sits untouched for 14+ days.

5. **Filenames in `shared/knowledge/` are descriptive and kebab-case.**
   `weekly-digest-2026-W28.md`, not `digest1.md`.

6. **No secrets, no bulk-pasted external content.** Summaries only; link
   to sources rather than dumping them.

7. **Archive, don't delete.** Outdated content moves to `shared/archive/`
   under a date-prefixed folder. Disagreements about what belongs in
   `knowledge/` are settled by humans talking — worst case, archive both
   versions and move on.
