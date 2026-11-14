#!/usr/bin/env bash
# The execution skills get their moments from hooks/ledger-moments, so the fork leaves
# their text exactly as upstream wrote it.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="skills/subagent-driven-development"
failures=0
if git -C "$root" diff --quiet v7.0.2 -- "$dir" && [ -z "$(git -C "$root" ls-files --others --exclude-standard -- "$dir")" ]; then
    echo "PASS $dir is upstream's v7.0.2 text"
else
    echo "FAIL $dir differs from v7.0.2:"; git -C "$root" diff --stat v7.0.2 -- "$dir" | sed 's/^/    /'
    failures=$((failures + 1))
fi
if grep -q "^| \`[a-z-]*\` | \`$dir/" "$root/MOMENTS.md"; then
    echo "FAIL MOMENTS.md still lists a line in $dir"; failures=$((failures + 1))
else echo "PASS MOMENTS.md lists no line in $dir"; fi
[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
