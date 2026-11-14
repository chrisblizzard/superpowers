#!/usr/bin/env bash
# Pins every upstream format and script name hooks/ledger-moments reads. After a rebase,
# a format upstream renamed fails here, by name, instead of the hook silently firing
# nothing. Usage: test-ledger-contract.sh [ROOT]
set -u
root="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
failures=0

# format<TAB>file it must appear in (fixed strings)
contract=$(cat <<'EOF'
# SDD ledger — plan:	skills/executing-plans/SKILL.md
# SDD ledger — plan:	skills/subagent-driven-development/SKILL.md
Task <N>: complete (	skills/executing-plans/SKILL.md
Task <N>: complete (	skills/subagent-driven-development/SKILL.md
complete (commits	skills/executing-plans/scripts/task-done
Ruling:	skills/executing-plans/SKILL.md
Ruling:	skills/subagent-driven-development/SKILL.md
parked — 	skills/subagent-driven-development/references/fix-loop.md
minor (deferred): 	skills/executing-plans/SKILL.md
minor (deferred): 	skills/subagent-driven-development/references/fix-loop.md
Pre-flight	skills/executing-plans/SKILL.md
Pre-flight	skills/subagent-driven-development/references/preflight.md
Final: 	skills/executing-plans/SKILL.md
scripts/task-brief PLAN_FILE N	skills/subagent-driven-development/SKILL.md
scripts/task-start PLAN_FILE N	skills/executing-plans/SKILL.md
plan-path	skills/subagent-driven-development/scripts/sdd-workspace
.superpowers/sdd	skills/subagent-driven-development/scripts/sdd-workspace
progress.md	skills/executing-plans/SKILL.md
progress.md	skills/subagent-driven-development/SKILL.md
 — Ruling:	skills/subagent-driven-development/references/fix-loop.md
### Task N:	skills/writing-plans/SKILL.md
EOF
)

while IFS=$'\t' read -r format file; do
    if grep -q -F -- "$format" "$root/$file" 2>/dev/null; then
        echo "PASS '$format' in $file"
    else
        echo "FAIL '$format' not in $file"; failures=$((failures + 1))
    fi
done <<< "$contract"

for script in skills/subagent-driven-development/scripts/task-brief skills/executing-plans/scripts/task-start; do
    if [ -f "$root/$script" ]; then echo "PASS $script exists"
    else echo "FAIL $script is gone"; failures=$((failures + 1)); fi
done

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
