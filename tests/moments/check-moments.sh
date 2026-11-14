#!/usr/bin/env bash
# Checks that the moment lines in skills/ and the table in MOMENTS.md agree.
#
# Usage: check-moments.sh [--require-all] [ROOT]
#   ROOT defaults to the repository root.
#   --require-all also fails when one of the seven moments has no site.
# Exit 0 when everything agrees; otherwise exit 1 with one line per problem:
#   FAIL: <kind>: <file>: <detail>
# where <kind> is missing, unlisted, malformed, unknown-moment, anchor-missing or no-site.
set -u

require_all=0
if [ "${1:-}" = "--require-all" ]; then require_all=1; shift; fi
root="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
moments_file="$root/MOMENTS.md"
known="spec-approved plan-written task-started task-done work-found ruling-recorded branch-finished"

if [ ! -f "$moments_file" ]; then
    echo "FAIL: missing: MOMENTS.md: no moment list at $moments_file"
    exit 1
fi

is_known() { case " $known " in *" $1 "*) return 0 ;; esac; return 1; }

# Rows of the table: moment<TAB>file<TAB>heading, with backticks and padding removed.
rows="$(awk -F'|' '
    /^\|/ {
        for (i = 2; i <= 4; i++) { gsub(/`/, "", $i); gsub(/^[ \t]+|[ \t]+$/, "", $i) }
        if ($2 == "Moment" || $2 ~ /^-+$/ || $2 == "") next
        print $2 "\t" $3 "\t" $4
    }' "$moments_file")"

# Every heading and every moment line in a markdown file, outside code fences:
#   H<TAB>heading                       for headings
#   M<TAB>heading<TAB>lineno<TAB>line   for lines starting **Moment:
scan_file() {
    awk '
        /^```/ { fence = !fence; next }
        fence { next }
        /^#+ / { h = $0; sub(/^#+ +/, "", h); print "H\t" h; next }
        /^\*\*Moment:/ { print "M\t" h "\t" NR "\t" $0 }
    ' "$1"
}

template='^\*\*Moment: `([a-z][a-z-]*)`\.\*\* If the skill `superpowers-moment-([a-z][a-z-]*)` is available, invoke it now, passing: .+\. Then continue\.$'

fails=0
fail() { echo "FAIL: $1: $2: $3"; fails=$((fails + 1)); }

declare -A found_count want_count
# Moment lines in the skills.
while IFS= read -r -d '' f; do
    rel="${f#"$root"/}"
    while IFS=$'\t' read -r kind heading lineno line; do
        [ "$kind" = "M" ] || continue
        if [[ "$line" =~ $template ]] && [ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ]; then
            name="${BASH_REMATCH[1]}"
            if ! is_known "$name"; then
                fail unknown-moment "$rel" "line $lineno names '$name'"
            fi
            key="$rel"$'\t'"$heading"$'\t'"$name"
            found_count[$key]=$(( ${found_count[$key]:-0} + 1 ))
        else
            fail malformed "$rel" "line $lineno does not match the moment template"
        fi
    done < <(scan_file "$f")
done < <(find "$root/skills" -name '*.md' -print0 2>/dev/null)

# Rows of the list.
declare -A has_site
while IFS=$'\t' read -r name file heading; do
    [ -n "$name" ] || continue
    is_known "$name" || fail unknown-moment "MOMENTS.md" "row names '$name'"
    has_site[$name]=1
    if [ ! -f "$root/$file" ]; then
        fail anchor-missing "$file" "file not found (row for '$name')"
        continue
    fi
    if ! scan_file "$root/$file" | awk -F'\t' -v h="$heading" '$1 == "H" && $2 == h { found = 1 } END { exit !found }'; then
        fail anchor-missing "$file" "no heading '$heading' (row for '$name')"
        continue
    fi
    key="$file"$'\t'"$heading"$'\t'"$name"
    want_count[$key]=$(( ${want_count[$key]:-0} + 1 ))
done <<< "$rows"

for key in "${!want_count[@]}"; do
    have=${found_count[$key]:-0}; want=${want_count[$key]}
    IFS=$'\t' read -r file heading name <<< "$key"
    if [ "$have" -lt "$want" ]; then
        fail missing "$file" "'$name' under '$heading': $have line(s), $want row(s)"
    fi
done
for key in "${!found_count[@]}"; do
    have=${found_count[$key]}; want=${want_count[$key]:-0}
    IFS=$'\t' read -r file heading name <<< "$key"
    if [ "$have" -gt "$want" ]; then
        fail unlisted "$file" "'$name' under '$heading': $have line(s), $want row(s)"
    fi
done

if [ "$require_all" -eq 1 ]; then
    for name in $known; do
        [ -n "${has_site[$name]:-}" ] || fail no-site "MOMENTS.md" "$name"
    done
fi

[ "$fails" -eq 0 ]
