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

## Other changes to upstream's text

Upstream's size check keeps `subagent-driven-development/SKILL.md` under 20,000 bytes.
To make room for its moments, its "Waiting on dispatched subagents" paragraph moved to
`references/waiting.md`, leaving a one-line pointer. When a rebase conflicts on that
paragraph, apply upstream's change to `references/waiting.md`.

## Keeping the list right

The table below lists every moment line in `skills/`. `Under heading` is the exact text
of the nearest heading above the line. `Follows` is a phrase of upstream's own text that
must appear in the 8 lines above it, so a line moved within its section, or a step
reworded upstream, is caught too. After every rebase onto a new upstream release, run:

```
tests/moments/check-moments.sh --require-all
```

It fails when a listed line has gone or moved, when a heading has been renamed, when a
line isn't listed, or when a line doesn't match the form above. Upstream rewrites can
move a step; each failure is a site to place again by hand.

| Moment | File | Under heading | Follows | Carries |
|---|---|---|---|---|
| `spec-approved` | `skills/brainstorming/SKILL.md` | The Written Design | that comes back through this gate. | the saved design doc's path, or `none` only when no doc was written |
| `plan-written` | `skills/writing-plans/SKILL.md` | Execution Handoff | "Plan complete and saved to `docs/superpowers/plans/<filenam | the plan's path, and the spec's path if any |
| `task-started` | `skills/subagent-driven-development/SKILL.md` | 1. Dispatch the implementer | and fix-round diffs need it. | the plan's path, the task number and its title |
| `task-done` | `skills/subagent-driven-development/SKILL.md` | 5. Complete the task | tripped breaker | the plan's path, the task number, the commit range, the implementer's test summary, the review result |
| `work-found` | `skills/subagent-driven-development/references/fix-loop.md` | The Fix Loop | never enter the loop. | a deferred minor: title, description, task number |
| `work-found` | `skills/subagent-driven-development/references/fix-loop.md` | The Fix Loop | leaves every path forward a guess. | a parked finding: title, description, task number |
| `work-found` | `skills/subagent-driven-development/references/handling-reports.md` | Handling a Report That Isn't DONE | DONE_WITH_CONCERNS:** The implementer completed the work but | an implementer's observation: title, description, task number |
| `work-found` | `skills/subagent-driven-development/references/final-review.md` | Final Review and Finish | finishing-a-development-branch presents the options. | a residual parked finding: title, description, `Final` |
| `task-started` | `skills/executing-plans/SKILL.md` | 1. Take the task | Mark the task's todo in_progress. | the plan's path, the task number and its title |
| `task-done` | `skills/executing-plans/SKILL.md` | 4. Complete the task | `Task <N>: complete (commits <base7>..<head7>, tests: <comma | the plan's path, the task number, the commit range, the test command and result |
| `work-found` | `skills/executing-plans/SKILL.md` | Final Review | conflict, not a note that you declined a polish suggestion. | a deferred minor: title, description, `Final` |
| `branch-finished` | `skills/finishing-a-development-branch/SKILL.md` | Step 3: Determine Base Branch | Confirm before merging: merging into the wrong base is expen | the path of each plan the branch implemented, and the base branch |
| `ruling-recorded` | `skills/subagent-driven-development/SKILL.md` | Subagent-Driven Development | session parked on a question costs their whole day and buys  | every `Ruling:` line: its text, and its task number, `Pre-flight` or `Final` |
| `ruling-recorded` | `skills/executing-plans/SKILL.md` | Executing Plans | in secret. | every `Ruling:` line: its text, and its task number, `Pre-flight` or `Final` |
| `work-found` | `skills/subagent-driven-development/references/fix-loop.md` | The Fix Loop | minors — they never extend the loop. | a re-review's out-of-scope observation: title, description, task number |
