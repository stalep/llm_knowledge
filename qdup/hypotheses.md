## Path resolution shSync calls could be batched
Multiple sequential shSync calls for path resolution (echo env vars, echo ~/, pwd) could potentially be combined into a single call to reduce SSH round-trips. For scripts with many download/upload commands this overhead may be measurable.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-13
Last tested: 2026-04-13

## shouldCheckExit gating the entire exit-code block may skip logging
When shouldCheckExit is false and gates the entire block (not just the abort), non-stream output logging is also skipped. This may be intentional (perf optimization) or a regression. Needs confirmation of intended behavior.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-13
Last tested: 2026-04-13
