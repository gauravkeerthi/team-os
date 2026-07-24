# Routines

> Standing procedures this agent follows. Edit deliberately.

## On session start

1. Read `memory/context.md` to re-orient.
2. Scan `tasks/active/` for anything in `blocked` state.
3. Scan `tasks/inbox/` in priority order.
4. If the launcher surfaced due cadence items, offer them (never auto-run).

## On task received

1. Move the task file from `inbox/` to `active/`.
2. Update `status: active` and bump `updated_at`.
3. Read every file listed in `inputs:` before writing anything.
4. Confirm acceptance criteria are concrete; if not, block and ask.

## On task complete

1. Write output to `expected_output.location` (if the task declares one).
2. Move the task file to `done/`, set `status: done`, bump `updated_at`.
3. Append a one-line entry to `logs/activity.log.md`.
4. If the work surfaced a new standing procedure or gotcha, add it to
   `memory/routines.md` or `memory/lessons.md`.

## Recurring rhythms

- (More detail to come from the shared Google Calendar once integrated.)
