## Shape detection diminishing returns past 4 patterns
The VM currently detects 4 shapes (IDENTITY, FIELD_ACCESS, FIELD_ACCESS2, PIPE_FIELD_ARITH) for fast-path execution. Adding more shapes increases code complexity but real-world jq usage may cluster heavily around these few patterns. Needs profiling of actual jq usage patterns to confirm whether more shapes would be worthwhile.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-13
Last tested: 2026-04-13

## Eager conversion may outperform lazy for small JSON objects
Lazy conversion (AbstractMap wrappers) adds indirection overhead. For small objects (<10 fields) where most fields are accessed, eager deep-copy may actually be faster. Needs benchmark comparison at different object sizes to establish crossover point.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-13
Last tested: 2026-04-13
