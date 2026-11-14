#!/usr/bin/env bash
# Checks that the moment lines in skills/ and the table in MOMENTS.md agree.
#
# Usage: check-moments.sh [--require-all] [ROOT]   (the flag may come before or after ROOT)
#   ROOT defaults to the repository root.
#   --require-all also fails when one of the seven moments has no site.
# Exit 0 when everything agrees; otherwise exit 1 with one line per problem:
#   FAIL: <kind>: <file>: <detail>
# where <kind> is missing, unlisted, malformed, unknown-moment, anchor-missing or no-site.
#
# Each table row names a moment, its file, the nearest heading above its line, and a
# Follows phrase that must appear in the lines just above it, so a line moved within its
# section, or a step reworded upstream, fails as anchor-missing.
set -u

require_all=0
root=""
for arg in "$@"; do
    case "$arg" in
        --require-all) require_all=1 ;;
        *) root="$arg" ;;
    esac
done
[ -n "$root" ] || root="$(cd "$(dirname "$0")/../.." && pwd)"
moments_file="$root/MOMENTS.md"
known="spec-approved plan-written task-started task-done work-found ruling-recorded branch-finished"
window=8   # lines above a moment line searched for its Follows phrase

if [ ! -f "$moments_file" ]; then
    echo "FAIL: missing: MOMENTS.md: no moment list at $moments_file"
    exit 1
fi

is_known() { case " $known " in *" $1 "*) return 0 ;; esac; return 1; }

# Rows of the table: moment<TAB>file<TAB>heading<TAB>follows. Backticks are removed from
# the moment and file columns only; a heading may contain code.
rows="$(awk -F'|' '
    /^\|/ {
        for (i = 2; i <= 5; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
        gsub(/`/, "", $2); gsub(/`/, "", $3)
        if ($2 == "Moment" || $2 ~ /^-+$/ || $2 == "") next
        print $2 "\t" $3 "\t" $4 "\t" $5
    }' "$moments_file")"

# Every heading and every moment line in a markdown file, outside code fences:
#   H<TAB>heading
#   M<TAB>heading<TAB>lineno<TAB>line<TAB>the window lines above it, joined by spaces
# A fence closes only on the same character, at least as long as the one that opened it,
# so a ```` block holding ``` examples stays one block.
scan_file() {
    awk -v w="$window" '
        function remember(s) { buf[NR % w] = s }
        function above(   i, s) {
            s = ""
            for (i = NR - w; i < NR; i++) if (i > 0 && (i % w) in buf) s = s " " buf[i % w]
            return s
        }
        {
            if (match($0, /^(```+|~~~+)/)) {
                run = substr($0, 1, RLENGTH)
                if (fence == "") fence = run
                else if (substr(run, 1, 1) == substr(fence, 1, 1) && length(run) >= length(fence)) fence = ""
                remember($0); next
            }
            if (fence != "") { remember($0); next }
            if ($0 ~ /^#+ /) { h = $0; sub(/^#+ +/, "", h); print "H\t" h }
            else if ($0 ~ /^\*\*Moment:/) {
                line = $0; gsub(/\t/, " ", line); win = above(); gsub(/\t/, " ", win)
                print "M\t" h "\t" NR "\t" line "\t" win
            }
            remember($0)
        }
    ' "$1"
}

template='^\*\*Moment: `([a-z][a-z-]*)`\.\*\* If the skill `superpowers-moment-([a-z][a-z-]*)` is available, invoke it now, passing: .+\. Then continue\.$'

fails=0
fail() { echo "FAIL: $1: $2: $3"; fails=$((fails + 1)); }

# Moment lines in the skills.
declare -a l_file l_head l_line l_name l_win l_used
n=0
while IFS= read -r -d '' f; do
    rel="${f#"$root"/}"
    while IFS=$'\t' read -r kind heading lineno line win; do
        [ "$kind" = "M" ] || continue
        if [[ "$line" =~ $template ]] && [ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ]; then
            name="${BASH_REMATCH[1]}"
            is_known "$name" || fail unknown-moment "$rel" "line $lineno names '$name'"
            l_file[n]="$rel"; l_head[n]="$heading"; l_line[n]="$lineno"
            l_name[n]="$name"; l_win[n]="$win"; l_used[n]=0
            n=$((n + 1))
        else
            fail malformed "$rel" "line $lineno does not match the moment template"
        fi
    done < <(scan_file "$f")
done < <(find "$root/skills" -name '*.md' -print0 2>/dev/null)

# Rows of the list: each claims one unclaimed line with its moment, under its heading,
# whose window holds its Follows phrase.
declare -A has_site
while IFS=$'\t' read -r name file heading follows; do
    [ -n "$name" ] || continue
    is_known "$name" || fail unknown-moment "MOMENTS.md" "row names '$name'"
    has_site[$name]=1
    if [ -z "$follows" ]; then
        fail malformed "MOMENTS.md" "row for '$name' in $file has no Follows phrase"
        continue
    fi
    if [ ! -f "$root/$file" ]; then
        fail anchor-missing "$file" "file not found (row for '$name')"
        continue
    fi
    if ! scan_file "$root/$file" | awk -F'\t' -v h="$heading" '$1 == "H" && $2 == h { found = 1 } END { exit !found }'; then
        fail anchor-missing "$file" "no heading '$heading' (row for '$name')"
        continue
    fi
    claimed=-1; under=0
    for ((i = 0; i < n; i++)); do
        [ "${l_used[i]}" = 0 ] && [ "${l_file[i]}" = "$file" ] && [ "${l_head[i]}" = "$heading" ] \
            && [ "${l_name[i]}" = "$name" ] || continue
        under=$((under + 1))
        case "${l_win[i]}" in *"$follows"*) claimed=$i; break ;; esac
    done
    if [ "$claimed" -ge 0 ]; then
        l_used[claimed]=1
    elif [ "$under" -gt 0 ]; then
        fail anchor-missing "$file" "'$name' under '$heading' no longer follows '$follows'"
    else
        fail missing "$file" "'$name' under '$heading', following '$follows': no line"
    fi
done <<< "$rows"

for ((i = 0; i < n; i++)); do
    [ "${l_used[i]}" = 1 ] || fail unlisted "${l_file[i]}" "line ${l_line[i]}: '${l_name[i]}' under '${l_head[i]}' has no row"
done

if [ "$require_all" -eq 1 ]; then
    for name in $known; do
        [ -n "${has_site[$name]:-}" ] || fail no-site "MOMENTS.md" "$name"
    done
fi

[ "$fails" -eq 0 ]
