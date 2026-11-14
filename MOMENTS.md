# Moments

This fork adds named **moments**: points where the workflow reaches a milestone, such
as a plan being written or a task finishing. At each moment the agent invokes a handler
skill if one is installed, and otherwise carries on unchanged. The fork ships no
handlers.

The planning skills carry a moment as one line of their text; the execution skills'
moments come from a hook (see "Moments from the ledger"). Either way, a moment reads,
on one line, never wrapped, exactly:

```
**Moment: `<moment>`.** If the skill `superpowers-moment-<moment>` is available, invoke it now, passing: <what the moment carries>. Then continue.
```

A handler is a skill named exactly `superpowers-moment-<moment>`, in any plugin, whose
description begins "Handles the superpowers `<moment>` moment."

The moments: `spec-approved`, `plan-written`, `task-started`, `task-done`, `work-found`,
`ruling-recorded`, `branch-finished`.

## Moments from the ledger

`subagent-driven-development` and `executing-plans` keep upstream's text exactly. Their
moments come from `hooks/ledger-moments`, a `PostToolUse` hook on `Bash`, `Write` and
`Edit`. It reads each new line of a plan's ledger, `.superpowers/sdd/<plan>/progress.md`,
once, keeping a cursor beside it, and watches `Bash` for the task-start scripts:

| What appears | Moments | Carries |
|---|---|---|
| a `Bash` command running `…/task-brief PLAN N` or `…/task-start PLAN N` | `task-started` | the plan's path, the task number, the title from its `### Task N:` heading |
| a ledger line `Task <N>: complete (<rest>)` | `task-done` | the plan's path, the task number, and `<rest>` |
| a ledger line with ` parked — <finding>` | `work-found`, then `ruling-recorded` | the finding as a title, the line, the task |
| a ledger line with `minor (deferred): <one-liner>` | `work-found` | the one-liner as a title, the line, the task or `Final` |
| a ledger line with `Ruling:` | `ruling-recorded` | the line, and its task number, `Pre-flight` or `Final` |

The plan's path comes from the workspace's `plan-path` marker, or the ledger's
`# SDD ledger — plan:` header. Every other ledger line fires nothing. After a rebase,
`tests/moments/test-ledger-contract.sh` checks each format and script name is still in
upstream's text.

## Keeping the list right

The table below lists every moment line in `skills/`, and each moment the hook fires. `Under heading` is the exact text
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
| `branch-finished` | `skills/finishing-a-development-branch/SKILL.md` | Step 3: Determine Base Branch | Confirm before merging: merging into the wrong base is expen | the path of each plan the branch implemented, and the base branch |
| `task-started` | `hooks/ledger-moments` | — | — | the plan's path, the task number and its title |
| `task-done` | `hooks/ledger-moments` | — | — | the plan's path, the task number, the commits and tests or review result |
| `work-found` | `hooks/ledger-moments` | — | — | the finding as a title, the ledger line, the task or `Final` |
| `ruling-recorded` | `hooks/ledger-moments` | — | — | the ruling's text, and its task number, `Pre-flight` or `Final` |
