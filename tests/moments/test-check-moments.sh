#!/usr/bin/env bash
# Tests check-moments.sh against the fixtures: each one breaks the moment list or a
# moment line in exactly one way, and the checker must name that way.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
checker="$here/check-moments.sh"
fixtures="$here/fixtures"
failures=0

expect() { # name, expected exit code, expected output pattern ("" = no output), args...
    local name="$1" want_code="$2" want_out="$3"; shift 3
    local out code
    out="$(bash "$checker" "$@" 2>&1)"; code=$?
    if [ "$code" -ne "$want_code" ]; then
        echo "FAIL $name: exit $code, want $want_code"; echo "$out" | sed 's/^/    /'
        failures=$((failures + 1)); return
    fi
    if [ -z "$want_out" ]; then
        if [ -n "$out" ]; then
            echo "FAIL $name: want no output, got:"; echo "$out" | sed 's/^/    /'
            failures=$((failures + 1)); return
        fi
    elif ! printf '%s\n' "$out" | grep -q -- "$want_out"; then
        echo "FAIL $name: output lacks '$want_out':"; echo "$out" | sed 's/^/    /'
        failures=$((failures + 1)); return
    fi
    echo "PASS $name"
}

expect good 0 "" "$fixtures/good"
expect missing 1 "FAIL: missing:" "$fixtures/missing"
expect unlisted 1 "FAIL: unlisted:" "$fixtures/unlisted"
expect malformed 1 "FAIL: malformed:" "$fixtures/malformed"
expect unknown-moment 1 "FAIL: unknown-moment:" "$fixtures/unknown-moment"
expect anchor-missing 1 "FAIL: anchor-missing:" "$fixtures/anchor-missing"
expect follows-missing 1 "FAIL: anchor-missing:" "$fixtures/follows-missing"
expect require-all 1 "FAIL: no-site:" --require-all "$fixtures/good"
expect require-all-after-root 1 "FAIL: no-site:" "$fixtures/good" --require-all

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
