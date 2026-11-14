#!/usr/bin/env bash
# Checks the fork's marketplace and plugin manifests, and that Claude Code accepts them.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
mp="$root/.claude-plugin/marketplace.json"
pj="$root/.claude-plugin/plugin.json"
version="7.0.2+moments.1"
fork="https://github.com/chrisblizzard/superpowers"
failures=0

check() { # name, jq expression that must print true, file
    if [ "$(jq -r "$2" "$3")" = "true" ]; then echo "PASS $1"
    else echo "FAIL $1: $2 on $(basename "$3")"; failures=$((failures + 1)); fi
}

check marketplace-name '.name == "chrisblizzard-superpowers"' "$mp"
check marketplace-owner '.owner.name == "chrisblizzard"' "$mp"
check marketplace-owner-no-email '.owner | has("email") | not' "$mp"
check marketplace-plugin-name '.plugins[0].name == "superpowers"' "$mp"
check marketplace-plugin-version ".plugins[0].version == \"$version\"" "$mp"
check plugin-name '.name == "superpowers"' "$pj"
check plugin-version ".version == \"$version\"" "$pj"
check plugin-homepage ".homepage == \"$fork\"" "$pj"
check plugin-repository ".repository == \"$fork\"" "$pj"
check plugin-author '.author.name == "Jesse Vincent"' "$pj"

# Every manifest upstream's bump script tracks carries the same version.
while IFS=$'\t' read -r path field; do
    f="$root/$path"
    case "$path" in
        *.yaml|*.yml) v="$(awk -F': *' -v k="$field" '$1 == k { gsub(/"/, "", $2); print $2; exit }' "$f")" ;;
        *) v="$(jq -r --arg p "$field" 'getpath($p | split(".") | map(tonumber? // .))' "$f")" ;;
    esac
    if [ "$v" = "$version" ]; then echo "PASS version in $path"
    else echo "FAIL version in $path: $v"; failures=$((failures + 1)); fi
done < <(jq -r '.files[] | [.path, .field] | @tsv' "$root/.version-bump.json")

if out="$(cd "$root" && claude plugin validate . 2>&1)"; then echo "PASS validate"
else echo "FAIL validate:"; echo "$out" | tail -5 | sed 's/^/    /'; failures=$((failures + 1)); fi

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
