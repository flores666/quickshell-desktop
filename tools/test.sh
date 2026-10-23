#!/usr/bin/env bash
# Run the tests in tests/.
#
# Quickshell is built into qs, so qmltestrunner cannot load it: each
# tests/*Test.qml is run as the whole shell instead, under `qs -p`, in a copy
# of the tree whose shell.qml holds that test alone. The copy has state and
# cache directories of its own, so Settings starts from profile/ and writes
# nothing real. A test reports through tests/Check.qml — a PASS or FAIL line
# per check and a closing line — and since nothing in QML can make qs quit,
# the script stops it once that line is out.
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/tree"
tar -C "$src" --exclude=./.git --exclude=./.forge -cf - . | tar -C "$work/tree" -xf -

status=0
for test in "$src"/tests/*Test.qml; do
    name="$(basename "$test" .qml)"
    log="$work/$name.log"
    printf 'import Quickshell\nimport "root:/tests"\n\nShellRoot {\n    %s {}\n}\n' "$name" \
        > "$work/tree/shell.qml"

    XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" \
        qs -p "$work/tree/shell.qml" > "$log" 2>&1 &
    pid=$!
    for _ in $(seq 150); do
        grep -q 'TESTS DONE' "$log" && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    echo "== $name"
    # Every line but Quickshell's own start-up chatter, without its colours.
    sed -E 's/\x1b\[[0-9;]*m//g' "$log" | grep -v -E '^ *INFO|^Shell cwd' | sed -E 's/^ *DEBUG qml: //' || true
    if ! grep -q 'TESTS DONE 0 failed' "$log"; then
        grep -q 'TESTS DONE' "$log" || echo "FAIL $name never finished"
        status=1
    fi
done
exit "$status"
