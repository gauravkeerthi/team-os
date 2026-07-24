# QUICKSTART — template to two syncing agents

Fifteen minutes: a founder (Alice) sets up the team, then a teammate (Bob)
joins from his own laptop. Adjust names as you go.

## 0. Prerequisites (each member)

- git ≥ 2.20 and bash ≥ 3.2 (stock macOS/Linux is fine)
- [Claude Code](https://claude.com/claude-code) installed
  (`npm install -g @anthropic-ai/claude-code`)
- A Claude subscription — **Pro is enough**; Max tiers get roomier defaults
- *(optional)* `gitleaks` for the pre-commit secret scan, `jq` not required

**Windows:** use WSL (recommended) or Git Bash. Two caveats: keep the repo
inside the WSL filesystem for speed, and don't let an editor rewrite line
endings (`.gitattributes` already pins `*.sh` to LF).

## 1. Founder: create your team's private fork

Your team's repo will hold working memory — agent notes, tasks, drafts — so
it must be **private**. Make it a *fork* (a clone that keeps this template's
git history) so `tos update` can keep pulling upstream improvements while
your files stay yours. GitHub's Fork button can't make a private fork of a
public repo, so:

```bash
git clone https://github.com/gauravkeerthi/team-os.git YOUR-TEAM-os
cd YOUR-TEAM-os
git remote rename origin upstream
gh repo create YOUR-ORG/YOUR-TEAM-os --private --source=. --remote=origin --push
./ops/setup.sh
```

(No `gh` CLI? Create an empty **private** repo on github.com, then
`git remote add origin git@github.com:YOUR-ORG/YOUR-TEAM-os.git` and
`git push -u origin main`.)

Setup asks for the team name, timezone, and your own details (member id,
agent name, plan, email), then creates your agent, installs the git hooks,
validates, and commits. Expected tail:

```
[ OK ] setup complete.
Next steps:
  1. ./ops/onboard.sh          # bind THIS machine to 'alice'
  ...
```

## 2. Founder: bind your machine and sign in

```bash
./ops/onboard.sh          # pick yourself; writes ~/.config/team-os/identity, installs the `tos` alias
source ~/.zshrc           # or whichever profile it names
claude                    # once: /login with your Claude subscription, then /exit
git push
```

## 3. Founder: add a teammate

First, give Bob access to the private fork — his agent syncs through it:
GitHub → your repo → **Settings → Collaborators → Add people** → Bob.
Then:

```bash
tos add-member bob "Bob Iyer" piper pro --email bob@example.com
tos sync
```

This appends Bob to `team/team.md`, creates `agents/piper/` from the
template (onboarding interview pending), commits, and pushes.

## 4. Teammate: join from your own laptop

```bash
git clone git@github.com:YOUR-ORG/YOUR-TEAM-os.git
cd YOUR-TEAM-os
./ops/onboard.sh          # pick 'bob'
source ~/.zshrc
claude                    # /login with YOUR OWN Claude subscription, /exit
tos doctor                # everything green?
```

## 5. First launches

Each of you:

```bash
tos
```

First launch, your agent runs a ~10-minute onboarding interview (who you
are, how you like to work), saves it to memory, and gets to work. Sessions
also enable **Remote Control** by default — your running agent shows up in
the Claude app / claude.ai/code, named `<agent>-<date>` (opt out with
`tos --no-rc`). End every
session with `/close` inside the session, then:

```bash
tos done                  # validate + commit + pull + push
```

## 6. The coordination loop (the whole point)

Alice, from her machine:

```bash
tos task --title "Review the Q3 draft" --to bob --priority high \
         --description "Draft at shared/incoming/q3-draft.md"
tos sync
```

Bob, whenever he next launches:

```bash
tos
#   piper — inbox: 1, active: 0 (plan pro, model sonnet)
#   ...prompt includes: T-....  Review the Q3 draft — from alice [high]
```

Bob's agent moves the task `inbox/ → active/`, does the work, writes the
output where the task says, moves it to `done/`, and `tos done` pushes it
back. Alice's next launch pulls the result. No server involved — files
moved between folders, carried by git.

## 7. First cadence item (optional, recommended)

Edit `team/cadence.md` and copy an example out of the blockquote, e.g. the
weekday standup digest. Commit (`tos sync`). From then on, the first person
to launch after 09:00 on a weekday is offered: *"run the standup digest?"*
— their agent claims it (a tiny file + push settles who), writes
`shared/cadence/standup-digest/<date>.md`, and everyone else sees it in
`tos status`.

## Troubleshooting

- `tos doctor` — checks the machine end to end and prints exact fixes.
- `tos validate` — checks the repo's conventions (CI runs the same).
- Sync conflict? `tos sync` prints a numbered manual-resolution recipe.
  Never `git reset --hard`, never force-push.
- Prompt looks wrong? Inspect exactly what your agent sees:
  `tos launch --print | less`.
