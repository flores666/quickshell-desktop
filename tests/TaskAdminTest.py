"""Administrator task snapshots and their narrowly scoped sudoers grants.

Run unprivileged: all writes stay in a temporary directory. Only the protected
directory boundary is replaced; visudo parses the actual generated rules.
"""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

loader = importlib.machinery.SourceFileLoader(
    "task_admin", str(Path(__file__).resolve().parent.parent / "bin/quickshell-task-admin"))
spec = importlib.util.spec_from_loader(loader.name, loader)
admin = importlib.util.module_from_spec(spec)
loader.exec_module(admin)


class TaskAdminTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="qs-task-admin-")
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        for name in ("TASKS", "SUDOERS"):
            self.enterContext(patch.object(admin, name, self.directory / name.lower()))
        self.secure = self.enterContext(patch.object(
            admin, "secure_directory", side_effect=lambda path: path.mkdir(exist_ok=True)))
        self.task_id = "qs-task-example"
        self.script = admin.TASKS / f"1000-{self.task_id}"
        self.grant = admin.SUDOERS / f"quickshell-task-1000-{self.task_id}"

    def apply(self, command="printf '%s' \"$HOME 100%\"", uid=1000):
        admin.authorize("install", uid, self.task_id, command)

    def test_snapshot_and_exact_no_arguments_rule(self):
        command = "printf '%s' \"$HOME 100%\" > /tmp/output"
        self.apply(command)
        self.assertEqual(self.script.read_text(), "#!/bin/sh\n" + command + "\n")
        self.assertEqual(stat.S_IMODE(self.script.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.grant.stat().st_mode), 0o440)
        self.assertIn(f'\n#1000 ALL=(root) NOPASSWD: NOSETENV: {self.script} ""\n', self.grant.read_text())
        subprocess.run(["/usr/bin/visudo", "-cf", str(self.grant)], check=True,
                       stdout=subprocess.DEVNULL)

    def test_command_and_redirection_run_as_a_shell_script(self):
        output = self.directory / "result"
        command = f"printf '%s' 'quotes $HOME 100% \\\"' | cat > '{output}'"
        self.apply(command)
        subprocess.run(["/bin/sh", str(self.script)], check=True)
        self.assertEqual(output.read_text(), 'quotes $HOME 100% \\"')

    def test_edit_replaces_snapshot_and_reuses_grant(self):
        self.apply("true")
        grant = self.grant.read_bytes()
        inode = self.grant.stat().st_ino
        self.apply("exit 3")
        self.assertEqual(self.script.read_text(), "#!/bin/sh\nexit 3\n")
        self.assertEqual(self.grant.read_bytes(), grant)
        self.assertEqual(self.grant.stat().st_ino, inode)
        self.assertEqual(list(admin.TASKS.glob(".qs-task-*")), [])
        self.assertEqual(list(admin.SUDOERS.glob(".qs-task-*")), [])

    def test_failed_validation_keeps_previous_command_and_grant(self):
        self.apply("true")
        previous = (self.script.read_bytes(), self.grant.read_bytes())
        with patch.object(admin.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "visudo")):
            with self.assertRaises(subprocess.CalledProcessError):
                self.apply("false")
        self.assertEqual((self.script.read_bytes(), self.grant.read_bytes()), previous)
        self.assertEqual(list(admin.TASKS.glob(".qs-task-*")), [])
        self.assertEqual(list(admin.SUDOERS.glob(".qs-task-*")), [])

    def test_failed_initial_grant_leaves_no_snapshot(self):
        replace = os.replace

        def fail_grant(source, target):
            if target == self.grant:
                raise OSError("fixture write failure")
            replace(source, target)

        with patch.object(admin.os, "replace", side_effect=fail_grant):
            with self.assertRaises(OSError):
                self.apply()
        self.assertFalse(self.script.exists())
        self.assertFalse(self.grant.exists())

    def test_remove_revokes_only_callers_task_and_is_idempotent(self):
        self.apply()
        self.apply("false", uid=1001)
        for _ in range(2):
            admin.authorize("remove", 1000, self.task_id, "")
        self.assertFalse(self.script.exists())
        self.assertFalse(self.grant.exists())
        self.assertTrue((admin.TASKS / f"1001-{self.task_id}").exists())
        self.assertTrue((admin.SUDOERS / f"quickshell-task-1001-{self.task_id}").exists())

    def test_path_and_command_injection_rejected_before_writes(self):
        for task_id in ("../escape", "qs-task-a/b", "qs-task-a\nOther", "--option"):
            with self.subTest(task_id=task_id), self.assertRaises(ValueError):
                admin.authorize("install", 1000, task_id, "true")
        for command in ("", "  ", "true\nfalse", "true\rfalse", "true\0false", "true \\"):
            with self.subTest(command=command), self.assertRaises(ValueError):
                self.apply(command)
        self.secure.assert_not_called()

    def test_only_pkexec_root_setup_is_accepted(self):
        with patch.object(admin.os, "geteuid", return_value=1000), self.assertRaises(ValueError):
            admin.main()
        with patch.object(admin.os, "geteuid", return_value=0), patch.dict(os.environ, {"PKEXEC_UID": ""}):
            with self.assertRaises(ValueError):
                admin.main()


class ProtectedDirectoryTest(unittest.TestCase):
    def test_symlink_and_writable_directory_rejected(self):
        # Exercise the real boundary without creating or changing /etc.
        for mode, owner in ((stat.S_IFLNK | 0o755, 0), (stat.S_IFDIR | 0o777, 0),
                            (stat.S_IFDIR | 0o755, 1000)):
            info = os.stat_result((mode, 0, 0, 1, owner, 0, 0, 0, 0, 0))
            with self.subTest(mode=mode, owner=owner), patch.object(Path, "mkdir"), \
                    patch.object(Path, "lstat", return_value=info), \
                    patch.object(admin.os, "geteuid", return_value=0), self.assertRaises(ValueError):
                admin.secure_directory(Path("/"))


if __name__ == "__main__":
    unittest.main()
