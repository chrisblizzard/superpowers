# Moments

This fork adds named **moments** to the skills: points where the workflow reaches a
milestone, such as a plan being written or a task finishing. At each moment the skill
invokes a handler skill if one is installed, and otherwise carries on unchanged. The
fork ships no handlers.

Every moment is one line, never wrapped, in exactly this form:

```
**Moment: `<moment>`.** If the skill `superpowers-moment-<moment>` is available, invoke it now, passing: <what the moment carries>. Then continue.
```

A handler is a skill named exactly `superpowers-moment-<moment>`, in any plugin, whose
description begins "Handles the superpowers `<moment>` moment."

The moments: `spec-approved`, `plan-written`, `task-started`, `task-done`, `work-found`,
`ruling-recorded`, `branch-finished`.

## Keeping the list right

The table below lists every moment line in `skills/`. `Under heading` is the exact text
of the nearest heading above the line. After every rebase onto a new upstream release,
run:

```
tests/moments/check-moments.sh --require-all
```

It fails when a listed line has gone or moved, when a heading has been renamed, when a
line isn't listed, or when a line doesn't match the form above. Upstream rewrites can
move a step; each failure is a site to place again by hand.

| Moment | File | Under heading | Carries |
|---|---|---|---|
