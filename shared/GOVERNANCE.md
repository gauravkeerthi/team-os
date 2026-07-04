# Shared Governance

Everything under `shared/` is team-visible. These rules keep it trustworthy
and clean. Authority is **governance-lite**: any member whose `team/team.md`
block says `role: maintainer` can promote, archive, and arbitrate. No
tickets, no approval chains — a maintainer at a keyboard is the review.

## Zones

| Folder | Purpose | Who writes |
|---|---|---|
| `shared/incoming/` | Draft zone — work in progress, awaiting review | Any agent |
| `shared/knowledge/` | Authoritative, reviewed outputs | Maintainers, via `ops/promote.sh` |
| `shared/projects/` | Cross-member project working files | Any agent, with a task |
| `shared/handoffs/` | Intermediate artifacts passed between agents | Any agent |
| `shared/cadence/` | Cadence outputs + claim files | The claiming agent, per the cadence protocol |
| `shared/archive/` | Superseded content, kept for history | Maintainers |

## Rules

1. **All shared writes must trace to a task or a cadence item.** A file in
   `shared/incoming/` with no task ID in its header or frontmatter is
   orphaned and subject to archival. (`tos validate` warns on orphans
   older than 14 days.)

2. **Only maintainers promote to `shared/knowledge/`**, using:

   ```bash
   ops/promote.sh <source-in-incoming> <dest-in-knowledge> <task-id>
   ```

   The script refuses unless the identity on this machine belongs to a
   maintainer, moves the file, and writes a `<dest>.promoted-by` sidecar
   recording who, when, and which task. `tos validate` checks every
   knowledge file has a sidecar and that the sidecar author is a
   maintainer.

3. **Promotion is a move, not a copy.** Once promoted, the source in
   `incoming/` is gone. Git preserves history.

4. **Filenames in `shared/knowledge/` are descriptive and kebab-case.**
   `weekly-digest-2026-W28.md`, not `digest1.md`.

5. **No secrets, no bulk-pasted external content.** Summaries only. If you
   need to preserve a source, link to it.

6. **Archive, don't delete.** Outdated content moves to `shared/archive/`
   under a date-prefixed folder.

## Requesting a promotion

Any agent that wants something promoted files a task into a maintainer's
agent inbox (normal collaboration protocol) pointing at the draft in
`shared/incoming/` and proposing a destination path. The maintainer's
human reads it and runs `ops/promote.sh` — or doesn't. That's the whole
ceremony.
