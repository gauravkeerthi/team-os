# Onboarding Interview

You are running this workflow because your `memory/context.md` still
contains the `<!-- onboarding:pending -->` sentinel. Read this file
end-to-end, then walk through it with your human before doing anything else
in the session. When you finish, you will remove the sentinel from
`memory/context.md`.

## How to run this

- Ask one question at a time. Wait for the answer before moving on.
- Keep your own replies short. You are listening, not lecturing.
- If an answer is vague, ask one polite follow-up. If it's still vague,
  write down what they said verbatim and move on — you can revisit later.
- Capture everything into a working draft as you go. Do not write to
  `memory/context.md` until after the human confirms the summary at the end.
- Plan for roughly ten minutes. If it runs long, flag it out loud so the
  human can choose to pause.

## Opening (read this aloud, in your own voice)

> I'm your paired agent here inside team-os. Before we get going, I want to
> spend about ten minutes learning who you are and how you like to work, so
> I can actually be useful instead of just busy. I'll ask a handful of
> questions across seven areas. You can skip anything, and we can always
> come back later. Ready?

If they say yes, proceed. If they say "not now," leave the sentinel in
place and tell them you'll run the interview next time they launch you.

---

## Section 1 — Current focus

Open with: "Let's start with what's in front of you right now."

1. What are you working on this week that actually matters?
2. What are you working on this month that actually matters?
3. Is there anything you're supposed to be doing that you're quietly not?
4. What's the one thing you don't want to drop?

## Section 2 — Collaborators

Open with: "Next I want to understand who you work with."

1. On this team (see the roster in my prompt): who do you work with most,
   in rough order of contact frequency?
2. Outside the team: are there external people I should know about —
   customers, vendors, advisors?
3. Who do you report to, and who reports to you?
4. Is there anyone whose requests I should treat as automatically urgent?

## Section 3 — Working surfaces

Open with: "Where does your work actually live?"

1. Where are your files — local folders, cloud drives, wikis? Give me
   specific paths or names where you can. (I may not have access to them —
   naming them still helps me know what exists.)
2. Are there documents that are load-bearing — things you refer back to
   often? Anything worth copying into the repo so I can read it?
3. What tools do you live in day-to-day (issue tracker, chat, design,
   code)? Just name them.
4. Where do you keep scratch notes for yourself?

Then briefly explain the workspace convention:

> Anything I produce that isn't ready for the team lives in my
> `workspace/private/`. Team-facing drafts go to `shared/incoming/`, and
> when you say one is ready, it gets promoted to `shared/knowledge/`.

## Section 4 — Rhythms

Open with: "Tell me about your recurring cadences."

1. What recurring meetings or check-ins do you have each week?
2. Is there a reporting cadence you owe someone — weekly update, monthly
   report?
3. When's your quiet time — blocks you want left alone?
4. Anything here that the whole team shares (a standup, a weekly review)?
   If so, mention that a maintainer can add it to `team/cadence.md` so the
   system tracks it for everyone.

## Section 5 — Tone and voice

Open with: "When I draft things on your behalf, how should I sound?"

1. How would you describe your default tone — formal, warm, blunt, playful?
2. Words or phrases you use a lot that I should mirror?
3. Words or phrases you hate that I should avoid?
4. When in doubt: longer and thorough, or shorter and punchier?

## Section 6 — Boundaries

Open with: "What do you definitely not want me touching?"

1. Are there files or topics I should never handle, even if asked?
2. Are there topics I should route straight back to you without trying to
   handle myself (legal, HR, personal)?
3. Anything you consider private from the rest of the team — stuff that
   stays between you and me (it stays in `workspace/private/`)?
4. If I'm ever unsure whether to act: ask first, or do nothing?

## Section 7 — Priorities and reading list

Open with: "Last section."

1. If five things land at once, how do you decide what's first?
2. What should never slip, even in a chaotic week?
3. Give me three to five things to read right now — files in this repo,
   or documents you can drop into `shared/incoming/` — so I can ground
   myself.

---

## Summary and confirm

When you reach the end, summarize back what you captured:

```
Here's what I've got. Correct me on anything that's wrong.

CURRENT FOCUS
- <one line per item>

COLLABORATORS
- <names, roles, frequency>

WORKING SURFACES
- <paths, tools>

RHYTHMS
- <recurring items>

TONE
- <voice description in their words>

BOUNDARIES
- <what I will not touch>

PRIORITIES
- <ordering rules>

READING LIST
- <3-5 items>
```

Ask: "Does this match what you meant? Anything to add, remove, or reword?"
Loop on corrections until the human says it's right.

## Commit to memory

Once the human confirms:

1. **Write to `memory/context.md`.** Replace the placeholder content with a
   section titled `## Onboarding (captured <YYYY-MM-DD>)` containing
   Current Focus, Collaborators, Working Surfaces, Tone, Boundaries,
   Priorities, and Reading List as bullet lists. Keep Current Focus at the
   top — it's the living part.
2. **Append rhythms to `memory/routines.md`** under a
   `## Recurring rhythms` heading — when it happens, who it's with, what
   your job is in it.
3. **Remove the sentinel** — delete the `<!-- onboarding:pending -->` line
   from `memory/context.md`. That is how team-os knows the interview is
   done.
4. **Log it.** Append to `logs/activity.log.md`:
   `- <ISO timestamp>  onboarding interview captured`.
5. **Tell the human what you did.** One short paragraph, then get on with
   whatever they actually wanted to do this session.

The interview is a one-time gate, not a ritual.
