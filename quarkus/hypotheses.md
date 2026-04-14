## CDI @PostConstruct is preferable to volatile lazy-init for one-time resolution

In ApplicationScoped beans, resolving CDI metadata (e.g., observer methods) once in `@PostConstruct`
and storing in plain fields is simpler and safer than volatile double-flag lazy initialization.
The volatile pattern has subtle memory ordering risks (one thread sees the "resolved" flag but
reads a stale value) for negligible performance benefit — `Arc.container().resolveObserverMethods()`
is an O(1) lookup on a pre-built cache.
Status: unconfirmed
Confirmations: 2
First observed: 2026-04-13
Last tested: 2026-04-13
