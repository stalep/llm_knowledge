## Sh.postRun lifecycle ordering matters for $?
The `Sh.postRun` method has a critical ordering dependency: anything that calls `shSync` before the exit code capture (`export __qdup_ec=$?`) will overwrite `$?` on the remote shell. This includes deferred commands, path resolution calls, etc. The exit code must be saved to a shell variable before any other shell interaction.
Observed: 2026-04-13

## Cmd.getHead() walks to the root of the parent chain
`Cmd.getHead()` (line ~1242) already walks up `parent` pointers to the root. Any new method that needs the root command should delegate to it rather than re-implementing the traversal.
Observed: 2026-04-13

## QueueDownload.hasBashEnv is a general-purpose utility on a specific class
`hasBashEnv(String)` detects `$name` or `${name}` patterns in strings. It lives as a static method on `QueueDownload` but is used by Download, Upload, and QueueDownload. It belongs on `Cmd` or a shared utility class.
Observed: 2026-04-13

## Observer context and shell access
Commands running inside a timer/watcher (observer context) cannot use `shSync` because the shell is active (running the observed command). The pattern is to defer such commands and execute them in the observed command's `postRun`. Key check: `AbstractShell.isActive()` returns true when `currentAction != null`.
Observed: 2026-04-13

## Context interface removed cwd/homeDir tracking
The `Context` interface previously had `setCwd/getCwd/setHomeDir/getHomeDir` methods. These were removed in PR #267 in favor of resolving paths directly via `shSync("pwd")` and `shSync("echo ~/")` at the point of use.
Observed: 2026-04-13

## shSync can be made transparent to $? with wrapping
Pattern: `__qdup_saved=$?; (exit $__qdup_saved); <command>; (exit $__qdup_saved)`. This saves `$?`, restores it before the command (so the command sees the original `$?`), runs the command, then restores `$?` again after. No stdout pollution since wrapper commands produce no output. Discussed as a follow-up to the exit code clobbering issue in PR #267.
Observed: 2026-04-15
