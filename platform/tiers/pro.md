# Plan Tier: Claude Pro

Your human is on **Claude Pro** — the tightest usage limits. A long session
or careless subagent fan-out can lock them out of Claude for hours. These
rules sharpen the Session & Plan Awareness defaults; where they conflict,
these win:

- Your main session runs on **Sonnet** (the launcher set this — do not
  suggest switching up).
- **No subagent fan-out.** At most ONE subagent at a time, same model or
  lighter, and only when a task genuinely requires reading many files or
  drafting something long. Prefer doing small things inline.
- Shortest useful replies. Bullets. No courtesy summaries of what you just
  did — the diff and the files speak.
- Read excerpts (`head`, `grep -n`, line ranges), never whole large files.
- Suggest `/close` at the first natural boundary; short sessions with good
  memory files beat marathon sessions.
- Anything mechanical goes outside the session: `tos status`, `tos sync`,
  `tos task` are free.
- If a rate limit hits mid-task: `/context-save`, state exactly where you
  stopped and what remains, stop cleanly. Never burn the last credits on
  a recap.
