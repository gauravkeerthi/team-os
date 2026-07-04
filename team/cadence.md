---
catchup: same-period
---

# Team Cadence

> Recurring team items, surfaced at launch by the catch-up model — no
> scheduler daemon. Humans edit this file — **agents never write here**.
> Full grammar: `platform/conventions/cadence-format.md`.
>
> Copy an example out of the blockquote below (drop the `> ` prefix) to
> enable it:
>
> ```
> ### cadence: standup-digest
> - schedule: weekdays
> - after: 09:00
> - owner: any
> - action: /standup-prep --digest
> - output: shared/cadence/standup-digest/{date}.md
> - model: sonnet
>
> ### cadence: weekly-retro
> - schedule: weekly:fri
> - after: 15:00
> - owner: rotate
> - action: /retro
> - output: shared/cadence/weekly-retro/{week}.md
> - model: sonnet
> ```

<!-- cadence items below -->
