#!/usr/bin/env bash
# End-to-end: does a real Claude Code session reach the plan-written moment and invoke a
# handler? And with no handler installed, does writing-plans carry on as upstream?
#
# SLOW: real model calls, several minutes per case. Run by hand:
#   bash tests/moments/test-moment-end-to-end.sh
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
stub="$root/tests/moments/stub-handler"
timeout_s="${E2E_TIMEOUT:-900}"
# Keep an installed upstream superpowers out of the run; this fork is loaded instead.
settings='{"enabledPlugins":{"superpowers@superpowers-marketplace":false}}'
failures=0

make_project() {
    local dir; dir="$(mktemp -d)"
    mkdir -p "$dir/docs/superpowers/specs"
    cat > "$dir/docs/superpowers/specs/greet-design.md" <<'EOF'
# greet: design

A shell script `greet.sh` that prints a greeting.

1. `greet.sh NAME` prints `Hello, NAME!` and exits 0.
2. `greet.sh` with no argument prints `usage: greet.sh NAME` to stderr and exits 2.
EOF
    git -C "$dir" init -q
    git -C "$dir" -c user.name=test -c user.email=test@example.invalid add -A
    git -C "$dir" -c user.name=test -c user.email=test@example.invalid commit -q -m spec
    echo "$dir"
}

# run_turns project_dir [extra claude args...]: the two turns, output to project_dir/turn*.out
run_turns() {
    local dir="$1"; shift
    local common=(--plugin-dir "$root" --settings "$settings" --permission-mode acceptEdits
        --allowed-tools "Read Write Edit Glob Grep Skill Bash(echo:*) Bash(git:*) Bash(ls:*) Bash(mkdir:*)" "$@")
    (cd "$dir" && timeout "$timeout_s" claude -p "Use superpowers:writing-plans to plan docs/superpowers/specs/greet-design.md. Native execution is already chosen." "${common[@]}" > turn1.out 2>&1) || return 1
    (cd "$dir" && timeout "$timeout_s" claude -p --continue "Reviewed. Approved as written. Don't start executing it." "${common[@]}" > turn2.out 2>&1) || return 1
}

plan_files() { find "$1/docs/superpowers/plans" -name '*.md' 2>/dev/null; }

# E2E_CASES picks cases to run (default: all three).
cases="${E2E_CASES:-positive negative ledger}"
want() { case " $cases " in *" $1 "*) return 0 ;; esac; return 1; }
kept=()

if want positive; then
    echo "== positive case: the stub handler is installed"
    p="$(make_project)"; log="$p/moment.log"; kept+=("$p")
    if run_turns "$p" --plugin-dir "$stub"; then
        n="$(grep -c '^plan-written ' "$log" 2>/dev/null)"; n="${n:-0}"
        plan="$(plan_files "$p" | head -1)"
        if [ "$n" = "1" ] && [ -n "$plan" ] && grep -q "$(basename "$plan")" "$log"; then
            echo "PASS positive: one plan-written line naming $(basename "$plan")"
        else
            echo "FAIL positive: $n plan-written line(s); plan: ${plan:-none}; log:"; sed 's/^/    /' "$log"
            failures=$((failures + 1))
        fi
    else
        echo "FAIL positive: a turn failed; see $p/turn*.out"; failures=$((failures + 1))
    fi
fi

if want negative; then
    echo "== negative case: no handler installed"
    n_dir="$(make_project)"; kept+=("$n_dir")
    if run_turns "$n_dir"; then
        # Only a handler or a missing skill counts: the toy spec itself talks about usage errors.
        if [ -n "$(plan_files "$n_dir")" ] && ! grep -qiE 'superpowers-moment|skill[^.]*(not available|not found|unavailable)' "$n_dir/turn1.out" "$n_dir/turn2.out"; then
            echo "PASS negative: plan written, no error, no handler mentioned"
        else
            echo "FAIL negative: see $n_dir/turn*.out"; failures=$((failures + 1))
        fi
    else
        echo "FAIL negative: a turn failed; see $n_dir/turn*.out"; failures=$((failures + 1))
    fi
fi

if want ledger; then
    # executing-plans on a one-task plan: the hook must fire task-started and task-done
    # from the task-start script and the ledger, with no moment line in the skill.
    echo "== ledger case: executing-plans with the stub handlers"
    l="$(make_project)"; kept+=("$l")
    mkdir -p "$l/docs/superpowers/plans"
    cat > "$l/docs/superpowers/plans/greet-plan.md" <<'PLAN'
# Greet Implementation Plan

**Goal:** A script `greet.sh` that prints `hello`.

### Task 1: The greet script

**Files:**
- Create: `greet.sh`
- Test: `test-greet.sh`

- [ ] **Step 1: Write the failing test.** `test-greet.sh` runs `bash greet.sh` and exits 0 only if it printed exactly `hello`.
- [ ] **Step 2: Run it.** `bash test-greet.sh` → FAIL (no script).
- [ ] **Step 3: Implement `greet.sh`,** one `echo hello`.
- [ ] **Step 4: Run it.** `bash test-greet.sh` → PASS.
- [ ] **Step 5: Commit.** `git add greet.sh test-greet.sh && git commit -m "Add greet"`
PLAN
    git -C "$l" -c user.name=test -c user.email=test@example.invalid add -A
    git -C "$l" -c user.name=test -c user.email=test@example.invalid commit -q -m plan
    if (cd "$l" && GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid \
        timeout "$timeout_s" claude -p "Use superpowers:executing-plans to execute docs/superpowers/plans/greet-plan.md. Native execution is chosen, and you have consent to work on the current branch. Stop after the plan's last task is complete; skip the final review and finishing." \
        --plugin-dir "$root" --plugin-dir "$stub" --settings "$settings" --permission-mode acceptEdits \
        --allowed-tools "Read Write Edit Glob Grep Skill Bash" > ledger.out 2>&1); then
        s="$(grep -c '^task-started 1$' "$l/moment.log" 2>/dev/null)"; d="$(grep -c '^task-done 1$' "$l/moment.log" 2>/dev/null)"
        if [ "${s:-0}" = "1" ] && [ "${d:-0}" = "1" ]; then
            echo "PASS ledger: one task-started 1 and one task-done 1"
        else
            echo "FAIL ledger: task-started ${s:-0}, task-done ${d:-0}; log:"; sed 's/^/    /' "$l/moment.log" 2>/dev/null
            failures=$((failures + 1))
        fi
    else
        echo "FAIL ledger: the session failed; see $l/ledger.out"; failures=$((failures + 1))
    fi
fi

[ "$failures" -eq 0 ] || { echo "$failures failed (projects kept: ${kept[*]})"; exit 1; }
rm -rf "${kept[@]}"
