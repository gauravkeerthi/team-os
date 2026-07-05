# Upgrading team-os

Your team's repo is a copy of the template, so upstream improvements don't
arrive by magic — `tos update` pulls them in, respecting the ownership
split.

## Who owns what

| Upstream owns (updated by `tos update`) | Your team owns (never touched) |
|---|---|
| `platform/**` (base prompt, tiers, schemas, conventions, workflows) | `team/**` (roster, cadence) |
| `ops/**` (the CLI) | `agents/**` (all agent state) |
| `.claude/settings.json` | `shared/**` (all team content) |
| the seven shipped skills (`.claude/skills/{today,close,context-save,context-restore,standup-prep,retro,reflect}`) | your own shared skills + `.claude/skills/private/` |
| `docs/**`, `README.md`, `QUICKSTART.md`, `LICENSE`, `.github/**`, `.gitattributes` | `.claude/settings.local.json`, `.mcp.json` (gitignored anyway) |

## The flow

```bash
tos update            # dry run — fetches upstream, lists what would change
tos update --apply    # requires a clean tree; checks out upstream-owned
                      # paths and commits "[ops] platform update vX -> vY"
tos sync              # publish to your team
```

`upstream:` in `team/team.md`'s frontmatter points at the template repo
(`--url` overrides per run). The version is `platform/VERSION`; release
notes live at the top of `platform/CHANGELOG.md`.

Everyone else just pulls: their next `tos` launch picks it up.

## Local platform edits

If you've used the `TEAMOS_ALLOW_PLATFORM_EDIT=1` escape hatch, those files
show up in every `tos update` dry run as differences, and `--apply`
**overwrites them**. The audit lines in `platform/CHANGELOG.md` are your
checklist of what to re-apply afterwards. Keep local platform edits rare;
upstream PRs are the better home for anything generally useful.

## Compatibility promises (v0.x)

- Anything under `team/`, `agents/`, `shared/` is **data** — updates never
  rewrite your data's *content*, though validators may get stricter
  (`tos update` then `tos validate` tells you what to tidy).
- File-format changes (task frontmatter, cadence grammar) come with a
  release-notes entry and a validator that explains exactly what to fix.
- Breaking CLI changes bump the minor version and are called out at the
  top of the changelog.
