#!/usr/bin/env bash
# Run qmllint over the shell.
#
# Quickshell's "root:/" import scheme is not something qmllint understands, so
# the tree is copied to a scratch directory with those imports rewritten to
# ordinary relative paths first. Nothing in the real source is touched.
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$src"
find . -name '*.qml' -not -path './.git/*' | while read -r f; do
    mkdir -p "$work/$(dirname "$f")"
    depth=$(awk -F/ '{print NF-2}' <<<"$f")
    prefix=""
    for ((i = 0; i < depth; i++)); do prefix="../$prefix"; done
    [[ -z "$prefix" ]] && prefix="./"
    sed -E "s#import \"root:/#import \"${prefix}#g" "$f" > "$work/$f"
done

# Quickshell synthesizes a qmldir per directory at runtime; qmllint needs a real
# one to know which components are singletons.
python3 - "$work" <<'PY'
import os, sys
root = sys.argv[1]
for dirpath, _, files in os.walk(root):
    qml = sorted(f for f in files if f.endswith(".qml") and f[0].isupper())
    if not qml:
        continue
    with open(os.path.join(dirpath, "qmldir"), "w") as out:
        out.write(f"module {os.path.basename(dirpath)}\n")
        for f in qml:
            head = open(os.path.join(dirpath, f)).read(200)
            prefix = "singleton " if "pragma Singleton" in head else ""
            out.write(f"{prefix}{f[:-4]} 1.0 {f}\n")
PY

cd "$work"
qmllint=/usr/lib/qt6/bin/qmllint
[[ -x "$qmllint" ]] || qmllint=qmllint

# shellcheck disable=SC2046
"$qmllint" -I /usr/lib/qt6/qml -I . $(find . -name '*.qml' | sort) 2>&1 \
    | sed "s#$work/##"
