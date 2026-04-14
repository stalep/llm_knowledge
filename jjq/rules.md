## Keep jjq-core dependency-free
The core module must have zero external dependencies. JSON library integrations (Jackson, fastjson2) go in separate adapter modules. This preserves GraalVM native-image compatibility and keeps the module boundary clean.
Promoted from hypothesis: 2026-04-13
Confirmations: 3 (GraalVM native-image success, modular Jackson adapter, modular fastjson2 adapter)

## Use JUnit Assumptions for upstream test compatibility tracking
When importing an upstream test suite where not all tests will pass, use `Assumptions.assumeTrue(false, msg)` on failure rather than `@Disabled`. This keeps passing tests asserted (catches regressions) while skipping known failures without CI noise.
Promoted from hypothesis: 2026-04-13
Confirmations: 3 (95.1% → 95.5% → 96.7% compatibility tracked across releases)

## Prefer compile-time pattern detection over runtime specialization
Detecting expression shapes (fused iteration, identity, field access) at compile time and emitting specialized opcodes is more effective than runtime guards in the interpreter loop. Compile-time detection adds zero overhead to the hot path.
Promoted from hypothesis: 2026-04-13
Confirmations: 4 (COLLECT_ITERATE, REDUCE_ITERATE, COLLECT_SELECT_ITERATE, shape detection)
