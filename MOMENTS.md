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
| `spec-approved` | `skills/brainstorming/SKILL.md` | The Written Design | the design doc's path, or `none` when approved in chat |
| `plan-written` | `skills/writing-plans/SKILL.md` | Execution Handoff | the plan's path, and the spec's path if any |
| `task-started` | `skills/subagent-driven-development/SKILL.md` | 1. Dispatch the implementer | the plan's path, the task number and its title |
| `task-done` | `skills/subagent-driven-development/SKILL.md` | 5. Complete the task | the plan's path, the task number, the commit range, the review result |
| `work-found` | `skills/subagent-driven-development/references/fix-loop.md` | The Fix Loop | a deferred minor: title, description, task number |
| `work-found` | `skills/subagent-driven-development/references/fix-loop.md` | The Fix Loop | a parked finding: title, description, task number |
| `work-found` | `skills/subagent-driven-development/references/handling-reports.md` | Handling a Report That Isn't DONE | an implementer's observation: title, description, task number |
| `work-found` | `skills/subagent-driven-development/references/final-review.md` | Final Review and Finish | a residual parked finding: title, description, `Final` |
| `task-started` | `skills/executing-plans/SKILL.md` | 1. Take the task | the plan's path, the task number and its title |
| `task-done` | `skills/executing-plans/SKILL.md` | 4. Complete the task | the plan's path, the task number, the commit range, the test command and result |
| `work-found` | `skills/executing-plans/SKILL.md` | Final Review | a deferred minor: title, description, `Final` |
| `branch-finished` | `skills/finishing-a-development-branch/SKILL.md` | Step 3: Determine Base Branch | the path of each plan the branch implemented, and the base branch |
| `ruling-recorded` | `skills/subagent-driven-development/SKILL.md` | Subagent-Driven Development | every `Ruling:` line: its text, and its task number, `Pre-flight` or `Final` |
| `ruling-recorded` | `skills/executing-plans/SKILL.md` | Executing Plans | every `Ruling:` line: its text, and its task number, `Pre-flight` or `Final` |
