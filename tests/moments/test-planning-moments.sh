#!/usr/bin/env bash
# Checks the spec-approved and plan-written moments: present, listed, and carrying what
# the chat-approved and revised-plan cases need.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

brainstorming="$root/skills/brainstorming/SKILL.md"
writing_plans="$root/skills/writing-plans/SKILL.md"

sa_line="$(grep -m1 '^\*\*Moment: `spec-approved`' "$brainstorming")"
if [ -n "$sa_line" ]; then pass spec-approved-present; else fail spec-approved-present; fi
# A design approved in chat has no file: the moment must still fire, passing none.
if printf '%s' "$sa_line" | sed 's/.*passing://' | grep -q '`none`'; then
    pass spec-approved-passes-none
else
    fail spec-approved-passes-none
fi

pw_lineno="$(grep -n -m1 '^\*\*Moment: `plan-written`' "$writing_plans" | cut -d: -f1)"
if [ -n "$pw_lineno" ]; then pass plan-written-present; else fail plan-written-present; fi
# The moment comes after the human's review and any edits, not at first save.
before="$(head -n "$((${pw_lineno:-1} - 1))" "$writing_plans" | grep -v '^[[:space:]]*$' | tail -1)"
if printf '%s' "$before" | grep -qi 'reviewed' && printf '%s' "$before" | grep -qi 'edit'; then
    pass plan-written-after-review
else
    fail "plan-written-after-review: preceding line is: $before"
fi

if bash "$root/tests/moments/check-moments.sh" "$root"; then pass check-moments; else fail check-moments; fi

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
