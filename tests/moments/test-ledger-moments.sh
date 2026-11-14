#!/usr/bin/env bash
# Runs hooks/ledger-moments against throwaway repositories with real workspace layouts,
# feeding it hook input on stdin the way Claude Code does.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
hook="$root/hooks/ledger-moments"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# make_repo DIR: a git repository with a two-task plan and one plan workspace.
make_repo() {
    local d="$1"
    mkdir -p "$d/docs" "$d/.superpowers/sdd/plan"
    git -C "$d" init -q
    printf '%s\n' '# Plan' '' '### Task 1: Alpha' '' 'Do alpha.' '' '### Task 2: Beta' '' 'Do beta.' > "$d/docs/plan.md"
    printf '%s\n' 'docs/plan.md' > "$d/.superpowers/sdd/plan/plan-path"
    printf '%s\n' "# SDD ledger — plan: $d/docs/plan.md" > "$d/.superpowers/sdd/plan/progress.md"
}

# input CWD TOOL [COMMAND]: hook input JSON, as Claude Code sends it.
input() {
    jq -nc --arg cwd "$1" --arg tool "$2" --arg cmd "${3:-}" \
        '{session_id: "s", hook_event_name: "PostToolUse", cwd: $cwd, tool_name: $tool,
          tool_input: (if $tool == "Bash" then {command: $cmd} else {file_path: "x"} end),
          tool_response: {}}'
}

# run NAME STDIN: runs the hook; sets out, err, code, ctx (the additionalContext, or "").
run() {
    out="$(cd "$tmp" && printf '%s' "$2" | bash "$hook" 2> "$tmp/err")"; code=$?
    err="$(cat "$tmp/err")"
    ctx=""
    if [ -n "$out" ]; then
        ctx="$(printf '%s' "$out" | jq -er '.hookSpecificOutput | select(.hookEventName == "PostToolUse") | .additionalContext' 2>/dev/null)" \
            || ctx="NOT-JSON: $out"
    fi
    if [ "$code" -ne 0 ] || [ -n "$err" ]; then fail "$1: exit $code, stderr: $err"; return 1; fi
}

moments() { printf '%s\n' "$ctx" | grep -o '^\*\*Moment: `[a-z-]*`' | sed 's/.*`\(.*\)`/\1/' | paste -sd' ' -; }

expect() { # NAME WANT-MOMENTS [PATTERN...]: ctx has exactly these moments, and each pattern
    local name="$1" want="$2"; shift 2
    local got; got="$(moments)"
    if [ "$got" != "$want" ]; then fail "$name: moments '$got', want '$want'; context: $ctx"; return; fi
    for p in "$@"; do
        printf '%s' "$ctx" | grep -qF -- "$p" || { fail "$name: context lacks '$p': $ctx"; return; }
    done
    pass "$name"
}

append() { printf '%s\n' "$2" >> "$1/.superpowers/sdd/plan/progress.md"; }

r="$tmp/repo"; make_repo "$r"

# No workspace: nothing at all.
mkdir -p "$tmp/bare"; git -C "$tmp/bare" init -q
run no-workspace "$(input "$tmp/bare" Edit)" && { [ -z "$out" ] && pass no-workspace || fail "no-workspace: output $out"; }

# The header alone fires nothing.
run header "$(input "$r" Edit)" && { [ -z "$out" ] && pass header || fail "header: output $out"; }

append "$r" 'Task 2: complete (commits aaaaaaa..bbbbbbb, review clean)'
run task-done "$(input "$r" Edit)" && expect task-done "task-done" "docs/plan.md" "task 2" "aaaaaaa..bbbbbbb" "review clean"

append "$r" 'Task 1: Ruling: a — b — c'
run ruling "$(input "$r" Bash 'echo x >> progress.md')" && expect ruling "ruling-recorded" "Task 1: Ruling: a — b — c" "task 1"

append "$r" 'Pre-flight: Task 1 vs Task 2 — conflict — Ruling: x'
run pre-flight "$(input "$r" Write)" && expect pre-flight "ruling-recorded" "Pre-flight"

append "$r" 'Task 2: parked — f — Ruling: r'
run parked "$(input "$r" Edit)" && expect parked "work-found ruling-recorded" '"f"' "task 2"

append "$r" 'Final: minor (deferred): m'
run deferred "$(input "$r" Edit)" && expect deferred "work-found" '"m"' "Final"

append "$r" 'Task 1: fix round 1/5 (1 addressed, 0 open — x; commits a..b)'
run ignored "$(input "$r" Edit)" && { [ -z "$out" ] && pass ignored || fail "ignored: output $out"; }

run once "$(input "$r" Edit)" && { [ -z "$out" ] && pass once || fail "once: output $out"; }

# A second plan's workspace fires with its own plan.
mkdir -p "$r/.superpowers/sdd/other"
printf '%s\n' 'docs/other.md' > "$r/.superpowers/sdd/other/plan-path"
printf '%s\n' '# SDD ledger — plan: docs/other.md' 'Task 5: complete (commits c..d, tests: t → ok)' > "$r/.superpowers/sdd/other/progress.md"
run two-plans "$(input "$r" Edit)" && expect two-plans "task-done" "docs/other.md" "task 5"

# A ledger shorter than its cursor: its lines fire once.
printf '%s\n' '# SDD ledger — plan: docs/plan.md' 'Task 1: complete (commits e..f, review clean)' > "$r/.superpowers/sdd/plan/progress.md"
run truncated "$(input "$r" Edit)" && expect truncated "task-done" "task 1" "e..f"

run task-start "$(input "$r" Bash "bash /x/skills/executing-plans/scripts/task-start $r/docs/plan.md 2")" \
    && expect task-start "task-started" "task 2" '"Beta"'
run task-brief "$(input "$r" Bash "bash /x/skills/subagent-driven-development/scripts/task-brief docs/plan.md 1")" \
    && expect task-brief "task-started" "task 1" '"Alpha"'

# Broken input: exit 0, no stderr, and what is known still fires.
run bad-json 'not json {' && { [ -z "$out" ] && pass bad-json || fail "bad-json: output $out"; }
rm "$r/.superpowers/sdd/other/plan-path"; printf '%s\n' 'Task 6: complete (commits g..h, review clean)' >> "$r/.superpowers/sdd/other/progress.md"
# Without a plan-path marker, the ledger's own header names the plan.
run no-plan-path "$(input "$r" Edit)" && expect no-plan-path "task-done" "docs/other.md" "task 6"
run missing-task "$(input "$r" Bash "bash /x/scripts/task-start docs/plan.md 9")" && expect missing-task "task-started" "task 9" "unknown"

# Text that needs escaping round-trips through valid JSON.
line=$'Task 1: Ruling: say "hi" \\ back\tslash — done'
append "$r" "$line"
run escaping "$(input "$r" Edit)" && expect escaping "ruling-recorded" "$line"


# Control characters (a coloured test log copied into the ledger) still give valid JSON.
append "$r" $'Task 1: Ruling: log says \e[32mok\e[0m and \x01'
run control-chars "$(input "$r" Edit)" && expect control-chars "ruling-recorded" "log says" "task 1"

# The script as the skills call it: quoted, with -C, through bash.
run quoted-script "$(input "$r" Bash 'bash "/x/scripts/task-brief" docs/plan.md 1')" \
    && expect quoted-script "task-started" "task 1" '"Alpha"'
run dash-C "$(input "$tmp" Bash "bash /x/scripts/task-brief -C $r docs/plan.md 2")" \
    && expect dash-C "task-started" "task 2" '"Beta"'
run not-a-script "$(input "$r" Bash 'echo usage: task-brief foo 1')" \
    && { [ -z "$out" ] && pass not-a-script || fail "not-a-script: output $out"; }

# task-started names the plan as the ledger moments do: the workspace's plan-path.
run same-plan-name "$(input "$r" Bash "bash /x/scripts/task-start $r/docs/plan.md 1")" \
    && expect same-plan-name "task-started" '`docs/plan.md`'

# A ledger already there, untouched for a while, is taken as read: no replay of old work.
o="$tmp/old"; make_repo "$o"
append "$o" 'Task 1: complete (commits a..b, review clean)'
touch -d '10 minutes ago' "$o/.superpowers/sdd/plan/progress.md"
run old-ledger "$(input "$o" Edit)" && { [ -z "$out" ] && pass old-ledger || fail "old-ledger: output $out"; }
append "$o" 'Task 2: complete (commits c..d, review clean)'
run old-ledger-new-line "$(input "$o" Edit)" && expect old-ledger-new-line "task-done" "task 2" "c..d"

# Task IDs as task-brief accepts them, and headings at any depth.
printf '%s\n' '### Task 6b: Six-b' '' '## Task 2.1: Sub' >> "$r/docs/plan.md"
run id-letters "$(input "$r" Bash 'bash /x/scripts/task-brief docs/plan.md 6b')" \
    && expect id-letters "task-started" "task 6b" '"Six-b"'
run id-dotted "$(input "$r" Bash 'bash /x/scripts/task-brief docs/plan.md 2.1')" \
    && expect id-dotted "task-started" "task 2.1" '"Sub"'
append "$r" 'Task 6b: complete (commits e..f, review clean)'
append "$r" 'Task 6b: Ruling: q'
run id-ledger "$(input "$r" Edit)" && expect id-ledger "task-done ruling-recorded" "task 6b, and commits" ", and task 6b."

# A subagent's tool call leaves the ledger to the agent that wrote it.
append "$r" 'Task 1: Ruling: for the controller'
sub="$(input "$r" Edit | jq -c '. + {agent_id: "sub-1"}')"
run subagent "$sub" && { [ -z "$out" ] && pass subagent || fail "subagent: output $out"; }
run controller-after "$(input "$r" Edit)" && expect controller-after "ruling-recorded" "for the controller"

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
