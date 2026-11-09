# Unattended administrator tasks

The Schedule editor offers **Run as administrator**. Saving asks for
administrator authorization once; its timer, login trigger and Run Now then
execute the saved command without a password. The entire command, including
pipes and redirects, runs as root. Use absolute paths; `sudo` is unnecessary
inside an administrator task.

`Tasks` still owns user-unit persistence, serialization and result reporting.
`TaskUnits` records a boolean `X-QsTask-Privileged` alongside the original
command; older tasks default to false. Administrator units use noninteractive
sudo to execute `/etc/quickshell-desktop/tasks/<uid>-<task-id>`. They never
execute an elevated command from a user-writable file.

`bin/quickshell-task-admin`, invoked through pkexec with isolated Python,
validates the caller uid, task identity, command and protected directories.
It stages a root-only script and a sudoers rule naming exactly that script,
with no arguments and no environment override allowed. visudo must accept
the rule before either file is published. Updates atomically replace the
script after validation; a lock serializes concurrent authorizations.

Every administrator save asks again. Deleting an administrator task or
switching it back to a normal task asks to revoke its grant, before changing
the user units. Dismissing the prompt leaves the previous task intact and
shows an error. Disabling a task only disables its schedule; Run Now remains
available. Removing its files outside the task manager does not revoke its
grant: use Delete or switch off administrator execution first.

No general passwordless sudo policy or stored password is added. Commands
that themselves read other scripts or files retain their normal semantics;
the authorization covers the saved command. Existing ordinary tasks keep
their execution and scheduling behavior. Administrator tasks follow the
same user-manager lifetime as ordinary tasks.

Verification:

- `TaskAdminTest.py`: exact no-argument grants parsed by visudo, file modes,
  command quoting and redirects, atomic edits, failure rollback, revocation,
  user isolation, path/line injection and protected-directory checks.
- `TaskUnitsTest`: metadata round trip, legacy defaults, snapshot execution,
  and unchanged timer generation.
- `TaskAuthorizationTest`: real isolated user units with a private pkexec
  fixture; cancellation during create/edit/delete, save/readback, revocation
  when switching to normal execution, and ordinary deletion without a prompt.
- Existing `TasksTest`, `TaskManagerTest` and `AuthPromptTest`; tree lint and
  runtime-log inspection. Real administrator authentication requires the
  user's password and is a separate manual check.
