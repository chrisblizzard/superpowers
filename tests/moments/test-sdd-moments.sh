#!/usr/bin/env bash
# Checks the moments in subagent-driven development: every site the design needs is
# listed in MOMENTS.md, and the checker agrees with the skills.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="skills/subagent-driven-development"
failures=0

# has_row moment file [heading]: MOMENTS.md lists a site for moment in file (under heading).
has_row() {
    awk -F'|' -v m="$1" -v f="$2" -v h="${3:-}" '
        /^\|/ {
            for (i = 2; i <= 4; i++) { gsub(/`/, "", $i); gsub(/^[ \t]+|[ \t]+$/, "", $i) }
            if ($2 == m && $3 == f && (h == "" || $4 == h)) found = 1
        }
        END { exit !found }' "$root/MOMENTS.md"
}
row() {
    if has_row "$@"; then echo "PASS $1 in $2${3:+ under $3}"
    else echo "FAIL $1 in $2${3:+ under $3}: no row"; failures=$((failures + 1)); fi
}

row ruling-recorded "$dir/SKILL.md" "Subagent-Driven Development"
row task-started "$dir/SKILL.md" "1. Dispatch the implementer"
row task-done "$dir/SKILL.md" "5. Complete the task"
row work-found "$dir/references/fix-loop.md"
row work-found "$dir/references/handling-reports.md"
row work-found "$dir/references/final-review.md"

# One general site per skill: a specific one beside it would fire twice for one ruling.
n="$(grep -c '^| `ruling-recorded` | `'"$dir/" "$root/MOMENTS.md")"
if [ "$n" = "1" ]; then echo "PASS one ruling-recorded site in $dir"
else echo "FAIL ruling-recorded sites in $dir: $n, want 1"; failures=$((failures + 1)); fi

if bash "$root/tests/moments/check-moments.sh" "$root"; then echo "PASS check-moments"
else echo "FAIL check-moments"; failures=$((failures + 1)); fi

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
