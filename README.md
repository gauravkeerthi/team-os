```
 ████████╗███████╗ █████╗ ███╗   ███╗       ██████╗ ███████╗
 ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║      ██╔═══██╗██╔════╝
    ██║   █████╗  ███████║██╔████╔██║█████╗██║   ██║███████╗
    ██║   ██╔══╝  ██╔══██║██║╚██╔╝██║╚════╝██║   ██║╚════██║
    ██║   ███████╗██║  ██║██║ ╚═╝ ██║      ╚██████╔╝███████║
    ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝       ╚═════╝ ╚══════╝
     give everyone on your team their own AI teammate — that
        all share one brain made of markdown and git.
```

[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![runs on: Claude subscription](https://img.shields.io/badge/runs%20on-Claude%20subscription-8A63D2.svg)](https://claude.com/claude-code)

---

## What is this?

Imagine everyone on your team — or in your household, or your two-person
startup — has their **own AI teammate**. Not a shared chatbot: a personal
agent that knows _your_ role, remembers what _you're_ working on, and keeps
its own notebook of what it's learned about how you like to work.

Now imagine those agents can **talk to each other** — one hands a task to
another, leaves a note, publishes something the whole team can use — and it
all just… syncs. No servers to run. No database. No dashboard to babysit.

That's team-os. The trick is almost silly in how simple it is:

> **Every agent reads and writes plain markdown files. Git carries those
> files between everyone's laptops. The filesystem _is_ the shared brain.**

Because there's no backend, there's almost nothing to set up and nothing to
pay for beyond what you already have:

- 🧑‍🤝‍🧑 **One agent per person**, each with memory, a role, and a private workspace.
- 🗂️ **They coordinate through files** (`inbox/ → active/ → done/`), carried by git.
- 🔑 **No API keys, no bills.** It runs on the **Claude subscription** each
  person already has — even **Claude Pro** is enough.
- 🪶 **Tiny and inspectable.** A few hundred lines of bash. `ls` is your
  dashboard; `git log` is your history.

If you have a Claude account, your team can launch their AI teammates this afternoon.

This is how the team behind [StrongKeep](https://www.StrongKeep.com) builds better, faster, and more awesome products than everybody else. We believe in helping (and protecting) smaller businesses, so this is free for you to use (non-commercially). If you want our simple, affordable, and comprehensive cybersecurity protection built for companies with limited budget and technical know-how, get in touch with us.

---

## Get running in 5 minutes

You need: [git](https://git-scm.com), [Claude Code](https://claude.com/claude-code),
and a Claude subscription. macOS or Linux (Windows works via WSL or Git Bash).

### If you're the first person (the "founder")

```bash
# 1. Make your team's own PRIVATE fork of this repo, and clone it.
#    (GitHub's Fork button can't make a private fork of a public repo,
#    so it's three lines with the gh CLI:)
git clone https://github.com/gauravkeerthi/team-os.git my-team-os
cd my-team-os
git remote rename origin upstream
gh repo create my-team-os --private --source=. --remote=origin --push

# 2. Set up the team and create your own agent. It asks a few questions
#    (team name, your name, your agent's name, your Claude plan).
./ops/setup.sh

# 3. Bind THIS laptop to you, and install the `tos` command.
./ops/onboard.sh
source ~/.zshrc            # or ~/.bashrc — onboard tells you which

# 4. Sign in to Claude once, then publish your team config.
claude                     # type /login, sign in, then /exit
git push

# 5. Meet your agent. First launch runs a friendly 10-minute interview
#    so it learns who you are and how you work.
tos
```

Why a private **fork** rather than a plain copy? Your repo is about to hold
your team's working memory — tasks, agent notes, private workspaces — so it
must be **private**. And because it keeps this template's git history, `tos
update` can keep pulling my latest platform improvements from `upstream`
without ever touching your team's files.

### Adding a teammate (30 seconds for you, 2 minutes for them)

You — first give Sam access to your private fork (GitHub → your repo →
**Settings → Collaborators → Add people**; their agent syncs through this
repo, so no access means nothing reaches them). Then:

```bash
tos add-member sam "Sam Rivera" scout pro   # member id, name, agent name, plan
tos sync
```

Them, on their own laptop:

```bash
git clone <your-private-repo-url> my-team-os
cd my-team-os
./ops/onboard.sh          # they pick "sam" from the list
source ~/.zshrc
claude                    # /login with THEIR Claude account, /exit
tos                       # their agent's first-launch interview
```

That's it — two people, two agents, already syncing. When you hand Sam's
agent a task, it shows up in Sam's inbox the next time they run `tos`.

> New to this? [QUICKSTART.md](QUICKSTART.md) is the same thing with every
> expected screen output, plus a `tos doctor` command that checks your
> machine and prints the exact fix for anything that's off.

---

## Using it, day to day

Most of the time you just run **`tos`** and talk to your agent. Everything
mechanical has a plain command so you never burn Claude credits on
bookkeeping:

| Command                                       | What it does                                              |
| --------------------------------------------- | --------------------------------------------------------- |
| `tos`                                         | Pull the latest, show what's waiting, launch your agent   |
| `tos task --title "Review Q3 draft" --to sam` | Drop a task in a teammate's inbox                         |
| `tos status`                                  | A quick dashboard — who's got what — for **free** (no AI) |
| `tos sync`                                    | Save + share your work (commit + pull + push)             |
| `tos done`                                    | End-of-day: check everything's tidy, then sync            |
| `tos doctor`                                  | "Is my setup OK?" with copy-paste fixes                   |

Inside a session, type **`/today`** to get oriented and **`/close`** to wrap
up cleanly (it updates your agent's memory so tomorrow starts sharp). Five
more skills come in the box: `/standup-prep`, `/retro`, `/reflect`,
`/context-save`, `/context-restore`.

### 📱 Drive your agent from your phone

Every `tos` session turns on **Remote Control** automatically, named for the
day (e.g. `scout-2026-07-24`). Install the **Claude app** (desktop or
[iOS/Android](https://claude.com/download)) or open
[claude.ai/code](https://claude.ai/code), and your running agent is right
there — hand it a task from the sofa, check what it did from the train, pick
the same session back up on your laptop later. Rename the session anytime in
the app. Don't want it on a particular machine? Launch with `tos --no-rc`,
or add `remote_control=false` to `~/.config/team-os/identity` to turn it off
for good.

### Make it yours: skills are just markdown

Here's the fun part. A "skill" is a repeatable thing your agent knows how to
do — and **it's just a markdown file**. No code. If you can write
instructions for a smart intern, you can write a skill.

Say you want your agent to help plan dinners. Create one file:

```
.claude/skills/private/meal-plan/SKILL.md
```

```markdown
---
name: meal-plan
description: Plan the week's dinners. Triggers "/meal-plan", "what's for dinner this week".
recommended_model: sonnet
---

## Steps

1. Ask what's already in the fridge and which nights we're eating out.
2. Suggest 5 dinners that reuse ingredients so nothing goes to waste.
3. Write the plan and a grocery list to
   workspace/private/meal-plans/{this-week}.md.
```

Next launch, you type `/meal-plan` and it just works. Anything under
`.claude/skills/private/` is yours alone (it's gitignored). Some more ideas
people actually build in an afternoon:

- 🧾 `/expenses` — turn a pile of receipt notes into a tidy monthly summary.
- ✍️ `/blog-draft` — first drafts in _your_ voice, saved to your workspace.
- 📚 `/study` — quiz me on my notes before an exam.
- 📅 `/week-review` — every Friday, tell me what I actually got done.
- 🎁 `/gift-ideas` — remember birthdays and brainstorm, per person.

Like a skill enough to share it with the team? Move it out of `private/`,
commit, and now everyone's agent has it. Recurring things (a Monday standup,
a Friday retro) go in one `team/cadence.md` file and get offered to whoever
starts their day first. Full guide: [docs/EXTENDING.md](docs/EXTENDING.md).

---

## What you actually get

- **A paired agent per person** — personality (`soul.md`), role
  (`profile.md`), four memory files it maintains itself, a task queue, and a
  private workspace. One command to launch: `tos`.
- **Coordination through files, synced by git.** To ask a teammate's agent
  for something, your agent files a markdown task into their inbox and
  pushes. Their next launch pulls it. The folder a task sits in **is** its
  status: `inbox/ → active/ → done/`.
- **Team rhythms without a scheduler.** Recurring items live in one file;
  whoever launches while an item is due is offered it, and a git push
  settles who "claims" it. No always-on machine required. (Want true
  clockwork timing? There's an [opt-in runner](docs/SCHEDULING.md).)
- **Subscription-credit native.** Each person's plan (`pro`, `max-5x`,
  `max-20x`) is in the team config; the launcher picks the right model and
  trims context to fit. Pro is a first-class citizen, not an afterthought.
- **Seven skills in the box**, and writing your own is a markdown file away.

### How it fits together

```
my-team-os/                 (your team's PRIVATE repo — the repo IS the workspace)
├── team/
│   ├── team.md             # THE config: members, agents, plans, roles
│   └── cadence.md          # recurring team items
├── agents/
│   ├── _template/          # copied for each new member
│   └── <agent>/            # soul · profile · memory×4 · tasks/{inbox,active,done} · workspace · logs
├── shared/                 # incoming (drafts) → knowledge (published) · handoffs · projects · cadence
├── platform/               # the OS: base prompt, tier doctrine, schemas, conventions
├── ops/                    # the `tos` CLI (pure bash)
└── .claude/                # permission model + shared skills (+ your private ones)
```

One repo, one branch, everyone pushes. Each agent writes only under its own
`agents/<name>/`, so collisions are rare by construction; a battle-tested
auto-stash / rebase / abort sync core handles the rare overlap safely.

### Design principles

1. **Everything inspectable via files.** `ls` is your dashboard; `git log` is your audit trail.
2. **Conventions over configuration.** One template, one folder shape, one config file.
3. **Minimize hidden state.** No daemon, no database, nothing running when nobody's working.
4. **Visible failure.** Scripts fail loudly; agents block a task instead of guessing.
5. **Respect the meter.** Subscription credits are finite — spend them on judgment, never on bookkeeping.

---

## Everything else

**Requirements:** git, bash ≥ 3.2 (macOS/Linux; Windows via WSL or Git
Bash), [Claude Code](https://claude.com/claude-code), and a Claude
subscription per member. No API keys, no other accounts.

**Deeper reading:**

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how and why it works
- [docs/EXTENDING.md](docs/EXTENDING.md) — write skills, add cadence items, wire in your own tools
- [docs/SCHEDULING.md](docs/SCHEDULING.md) — the opt-in wall-clock cadence runner
- [docs/UPGRADING.md](docs/UPGRADING.md) — pull platform updates from this template
- [shared/GOVERNANCE.md](shared/GOVERNANCE.md) — how shared knowledge gets published

**Deliberately _not_ included:** no web dashboard, no vector database, no
real-time agent chat, no autonomous headless agents, and no third-party
integrations in the core (the extension point is documented; the
dependencies aren't shipped). Timed scheduling is opt-in, not core — the
default rhythm is pull-based and needs no daemon beyond a stock OS timer.

**Lineage & license.** team-os is the open, generic extraction of a private
system ("workforce-os") that ran a real 7-person company on markdown + git +
Claude Code. MIT licensed — see [LICENSE](LICENSE). Contributions welcome.
