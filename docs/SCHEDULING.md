# Scheduling — the optional cadence runner

By default team-os is **pull-based**: recurring items in
[team/cadence.md](../team/cadence.md) are surfaced to whoever launches
their agent while an item is due, and offered — never auto-run. That needs
no daemon and no always-on machine, which is what keeps team-os deployable
by anyone on a subscription plan. The cost is that nothing fires on a
wall-clock schedule if nobody launches.

This optional module closes that gap **without** a persistent Claude
session or any MCP server. A host OS timer runs a small script that fires
due cadence items headlessly, on the same subscription credits an
interactive session uses.

## What it is

- [ops/cron-run.sh](../ops/cron-run.sh) — invoked on a timer. It pulls,
  asks the existing [cadence-due.sh](../ops/cadence-due.sh) engine what's
  due for this machine's member, and for each due item: **claims** it (the
  same git-push race the interactive path uses), runs the item's `action:`
  via a headless `claude -p`, verifies the declared `output:` file was
  produced, then commits and pushes it.
- [ops/cron-install.sh](../ops/cron-install.sh) — installs the timer:
  a **LaunchAgent** on macOS, a **crontab** entry on Linux/WSL.

Because it reuses the cadence grammar, the claim protocol, and tier model
selection, a runner behaves exactly like a punctual human. Nothing about
the file formats or the rest of the system changes.

## Subscription credits, not API billing

The runner calls `claude -p` (headless print mode). Authenticated by
**subscription login**, that draws on the same session credits / rate
limits as an interactive session — there is no `ANTHROPIC_API_KEY` and no
metered token billing. API pricing only applies if you deliberately set an
API key, which team-os never does.

- If the runner runs as your logged-in user, it can usually reach the OS
  keychain your interactive `claude` login uses — nothing extra needed.
- On a locked-down or headless box where the keychain isn't reachable,
  generate a subscription token once:

  ```bash
  claude setup-token
  ```

  and put it in `~/.config/team-os/runner.env` (chmod 600):

  ```
  CLAUDE_CODE_OAUTH_TOKEN=<the token>
  ```

  The runner loads this file if present. It is per-machine and never
  committed.

## Install

On the machine you want to host scheduling (a laptop that's on during work
hours, or a small always-on box):

```bash
tos cron-install                 # every 15 minutes (default)
tos cron-install --interval 5    # or tune the cadence
tos cron-install --status
tos cron-install --uninstall
```

Test immediately, without waiting for the timer:

```bash
tos cron-run --list      # what's due for me right now (runs nothing)
tos cron-run --dry-run   # same, plus confirms it would claim/execute
tos cron-run             # a real run
```

Runner activity is logged to `~/.config/team-os/cron.log`.

## Who runs what

The runner acts as **this machine's member** (from
`~/.config/team-os/identity`), so it handles exactly the items a human on
this machine would be offered:

- `owner: <this-member>` and `owner: rotate` landing on this member — run
  directly.
- `owner: any` — claimed via the git race; if another runner or a human
  claims first, this runner backs off.
- Items owned by *other* members are left alone (their machine, or a human,
  handles them).

The common setup for full unattended coverage: make the team's shared items
`owner: any` and point **one** always-on box's runner at them — it claims
and runs the lot. Running the timer on several machines is safe too; the
claim race guarantees each period runs once.

## Guarantees and limits

- **At-most-once per period.** The claim (a committed file + push) is the
  lock; the output file's existence stops re-runs. A run that dies after
  claiming but before producing output leaves a claim that goes stale after
  6 hours (measured by commit time, identical on every clone) and is then
  retried.
- **Overlap-safe.** A per-machine lock (`~/.config/team-os/cron.lock.d`,
  auto-reclaimed after 30 min) stops two timer firings from colliding.
- **Degrades cleanly.** If the host is off at the trigger, the item stays
  due until its period ends; the next run — or any human launch — catches
  up. Missed periods are never backfilled.
- **Needs a machine that's on** at the trigger time. If you need
  true 24/7 firing independent of any laptop, that's the heavier
  persistent-session route sketched in
  [ARCHITECTURE.md](ARCHITECTURE.md#10-future-optional-modules).

## Security note

The runner executes an agent **unattended**, so it defaults to
`--permission-mode acceptEdits` — the agent may write files (its edits land
under `shared/` and `agents/` per the committed permission model) but
cadence `action:` lines come from `team/cadence.md`, which only humans can
edit (it is agent-denied and, for platform stewards, protected). Keep it
that way: the safety of unattended execution rests on humans owning the
action list. For actions that need broader tools on a **trusted** runner
box, set `TEAMOS_CLAUDE_ARGS` (e.g. `--dangerously-skip-permissions`) — but
only on a box you control, and never as a way around the human-owns-cadence
rule.
