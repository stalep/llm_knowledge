## handleDefaultRun may need to propagate parent options to child command

When parseCommand is used instead of execute, the parent-level options (--preview, --verbose,
--fresh, --offline, etc.) that trigger Util.setX() calls are never applied. This could affect
more tests beyond the currently failing ones if other tests rely on --verbose or --fresh being
set before the subcommand.

Status: unconfirmed
Confirmations: 0
First observed: 2026-04-18
Last tested: 2026-04-18

## Template parseProperties empty defVal handling may affect other templates

The `parseProperties` method in `Template.TemplateAdd` has a fallback parsing branch
(using `split(":", 3)`) that produces `defVal = ""` (empty string) instead of null when
the input ends with `::`. This may affect any template using the `-P key::` format to
indicate "no default value". The primary branch (using `indexOf("=")` then `indexOf("::")`)
correctly handles this, but only when the value contains `=`.

Status: unconfirmed
Confirmations: 0
First observed: 2026-04-18
Last tested: 2026-04-18
