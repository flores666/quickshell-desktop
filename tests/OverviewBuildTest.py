"""Overview source pin and rebuild lifecycle. Run: python3 tests/OverviewBuildTest.py.

The production builder applies real patches to a local Git fixture. Only the
network, compiler and desktop commands are replaced; no plugin is loaded.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
REVISION = "00a44bf1296ee64c719aec7ae6c8d2fa08fef0dd"
PATCHES = (
    "real-wallpaper-bg", "tile-zoom-and-add-tile", "swipe-open-close",
    "shell-above-overview", "key-zoom", "focus-tokens", "elastic-drag",
)


class OverviewBuildTest(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix="qs-overview-build-")
        self.addCleanup(scratch.cleanup)
        self.directory = Path(scratch.name)
        self.tools = self.directory / "tools"
        self.tools.mkdir()
        self.script = self.tools / "build-overview-plugin.sh"
        shutil.copy2(ROOT / "tools/build-overview-plugin.sh", self.script)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        upstream = self.directory / "upstream"
        upstream.mkdir()
        self.git = shutil.which("git")

        def git(*args):
            return subprocess.check_output([self.git, "-C", str(upstream), *args],
                                           text=True, stderr=subprocess.PIPE).strip()

        git("init", "--quiet")
        (upstream / "src").mkdir()
        subject = upstream / "src/OverviewRender.cpp"
        subject.write_text("stage0\n")
        git("add", ".")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "commit", "--quiet", "-m", "supported base")
        base = git("rev-parse", "HEAD")
        subject.write_text("incompatible upstream renderer\n")
        git("add", ".")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "commit", "--quiet", "-m", "future release")
        git("tag", "v0.57.99")
        for index, name in enumerate(PATCHES):
            (self.tools / f"hyprexpo-{name}.patch").write_text(
                "diff --git a/OverviewRender.cpp b/OverviewRender.cpp\n"
                "--- a/OverviewRender.cpp\n+++ b/OverviewRender.cpp\n"
                f"@@ -1 +1 @@\n-stage{index}\n+stage{index + 1}\n")
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        XDG_DATA_HOME=str(self.directory / "data"),
                        TEST_UPSTREAM=str(upstream), TEST_BASE=base,
                        TEST_REAL_GIT=self.git, TEST_GIT_LOG=str(self.directory / "git.log"),
                        TEST_HYPR_VERSION="0.57.1", HYPRLAND_INSTANCE_SIGNATURE="")
        self.command("git", '''printf '%s\n' "$*" >> "$TEST_GIT_LOG"
case "$1" in
    clone) exec "$TEST_REAL_GIT" clone --quiet "$TEST_UPSTREAM" "${@: -1}" ;;
    checkout)
        if [[ "${@: -1}" =~ ^[0-9a-f]{40}$ ]]; then
            printf '%s\n' "${@: -1}" > .source-revision
            exec "$TEST_REAL_GIT" checkout --quiet "$TEST_BASE"
        fi
        exec "$TEST_REAL_GIT" "$@" ;;
    *) exec "$TEST_REAL_GIT" "$@" ;;
esac
''')
        self.command("pkg-config", 'printf "%s\\n" "$TEST_HYPR_VERSION"\n')
        self.command("make", '''[[ "${TEST_MAKE_FAIL:-}" != 1 ]] || exit 1
[[ "$(cat src/OverviewRender.cpp)" == stage7 ]] || exit 1
cp .source-revision hyprexpo.so
''')
        for name in ("nm-online", "notify-send", "pidof"):
            self.command(name, "exit 0\n")
        self.command("hyprctl", "exit 99\n")  # Must never reach the desktop.
        self.dest = self.directory / "data/hyprexpo"

    def command(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
        path.chmod(0o755)

    def build(self, *args, succeeds=True):
        result = subprocess.run([str(self.script), *args], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)
        return result

    def installed(self):
        return ((self.dest / "hyprexpo.so").read_bytes(),
                (self.dest / "built-for").read_bytes())

    def test_future_tag_does_not_change_patch_base(self):
        self.build()
        binary, stamp = self.installed()
        self.assertEqual(binary.decode().strip(), REVISION)
        self.assertEqual(stamp.decode().split()[:2], ["0.57.1", REVISION])
        self.assertIn("checkout --quiet " + REVISION, (self.directory / "git.log").read_text())

    def test_current_build_is_silent_and_offline(self):
        self.build()
        log = (self.directory / "git.log").read_bytes()
        result = self.build("--if-stale")
        self.assertEqual(result.stdout + result.stderr, "")
        self.assertEqual((self.directory / "git.log").read_bytes(), log)

    def test_source_pin_change_invalidates_build(self):
        self.build()
        next_revision = "1" * 40
        self.script.write_text(self.script.read_text().replace(REVISION, next_revision))
        self.build("--if-stale")
        self.assertEqual(self.installed()[0].decode().strip(), next_revision)

    def test_hyprland_update_invalidates_build(self):
        self.build()
        self.env["TEST_HYPR_VERSION"] = "0.57.2"
        self.build("--if-stale")
        self.assertEqual(self.installed()[1].decode().split()[0], "0.57.2")

    def test_legacy_stamp_and_missing_binary_rebuild(self):
        self.build()
        stamp = self.dest / "built-for"
        fields = stamp.read_text().split()
        stamp.write_text(f"{fields[0]} {fields[-1]}\n")
        self.build("--if-stale")
        self.assertEqual(self.installed()[1].decode().split()[1], REVISION)
        (self.dest / "hyprexpo.so").unlink()
        self.build("--if-stale")
        self.assertEqual(self.installed()[0].decode().strip(), REVISION)

    def test_patch_failure_preserves_previous_install(self):
        self.build()
        previous = self.installed()
        (self.tools / "hyprexpo-real-wallpaper-bg.patch").write_text("broken patch\n")
        self.build("--if-stale", succeeds=False)
        self.assertEqual(self.installed(), previous)

    def test_compile_failure_preserves_previous_install(self):
        self.build()
        previous = self.installed()
        self.env["TEST_MAKE_FAIL"] = "1"
        self.build(succeeds=False)
        self.assertEqual(self.installed(), previous)

    def test_unsupported_hyprland_fails_before_network(self):
        self.env["TEST_HYPR_VERSION"] = "0.58.0"
        result = self.build(succeeds=False)
        self.assertIn("no patched hyprexpo revision", result.stderr)
        self.assertFalse((self.directory / "git.log").exists())


if __name__ == "__main__":
    unittest.main()
