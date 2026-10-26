#!/usr/bin/env bash
# Run the tests in tests/.
#
# Quickshell is built into qs, so qmltestrunner cannot load it: each
# tests/*Test.qml is run as the whole shell instead, under `qs -p`, in a copy
# of the tree whose shell.qml holds that test alone. The copy has state and
# cache directories of its own, so Settings starts from profile/ and writes
# nothing real, and a data directory of its own, empty but for what a test
# puts there (an icon theme). The native module is built from the branch for
# the run. A test reports through tests/Check.qml — a PASS or FAIL line
# per check and a closing line — and since nothing in QML can make qs quit,
# the script stops it once that line is out. tests/bin comes first on their
# PATH: a gsettings with a store of the run's own, a pkill that signals
# nothing and a notify-send that shows nothing, so no test writes the
# machine's dconf, reaches its processes or posts to its notifications.
#
# Every test, or those named: tools/test.sh ProcessesTest TasksTest
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Qt searches only the icon directories there are when it starts.
mkdir -p "$work/tree" "$work/data/icons"
tar -C "$src" --exclude=./.git --exclude=./.forge -cf - . | tar -C "$work/tree" -xf -
cmake -S "$src/native" -B "$work/native" -DCMAKE_BUILD_TYPE=Release --log-level=WARNING >/dev/null
cmake --build "$work/native" -j >/dev/null

tests=("$src"/tests/*Test.qml)
if (($#)); then
    tests=()
    for name in "$@"; do tests+=("$src/tests/$name.qml"); done
fi

status=0
for test in "${tests[@]}"; do
    name="$(basename "$test" .qml)"
    log="$work/$name.log"
    printf 'import Quickshell\nimport "root:/tests"\n\nShellRoot {\n    %s {}\n}\n' "$name" \
        > "$work/tree/shell.qml"

    # Its output read line by line as it comes, until the closing line, qs
    # exiting or fifteen seconds: a wait on the output, not on a clock.
    exec {out}< <(exec env XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" \
        XDG_DATA_HOME="$work/data" QML_IMPORT_PATH="$work/native/qml" \
        PATH="$work/tree/tests/bin:$PATH" \
        TEST_GSETTINGS="$work/gsettings" TEST_SIGNALS="$work/signals" TEST_NOTIFY="$work/notify" \
        qs -p "$work/tree/shell.qml" 2>&1)
    pid=$!
    : > "$log"
    deadline=$((SECONDS + 15))
    while ((SECONDS < deadline)) && IFS= read -r -t "$((deadline - SECONDS))" -u "$out" line; do
        printf '%s\n' "$line" >> "$log"
        [[ "$line" == *'TESTS DONE'* ]] && break
    done
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    exec {out}<&-

    echo "== $name"
    # Every line but Quickshell's own start-up chatter, without its colours.
    sed -E 's/\x1b\[[0-9;]*m//g' "$log" | grep -v -E '^ *INFO|^Shell cwd' | sed -E 's/^ *DEBUG qml: //' || true
    if ! grep -q 'TESTS DONE 0 failed' "$log"; then
        grep -q 'TESTS DONE' "$log" || echo "FAIL $name never finished"
        status=1
    fi
done
exit "$status"
