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

echo "== positive case: the stub handler is installed"
p="$(make_project)"; log="$p/moment.log"
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

echo "== negative case: no handler installed"
n_dir="$(make_project)"
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

[ "$failures" -eq 0 ] || { echo "$failures failed (projects kept: $p $n_dir)"; exit 1; }
rm -rf "$p" "$n_dir"
