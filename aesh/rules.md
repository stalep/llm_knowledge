## Use TestConnection() not TestConnection(false) for plain-text test assertions
aesh-readline 3.2+ emits bracketed paste and OSC 133 escape sequences. TestConnection() strips these by default; TestConnection(false) captures raw bytes and breaks text assertions.
Promoted from hypothesis: 2026-04-10
Confirmations: 3

## New features must not regress startup time or allocation pressure
Aesh's startup performance is a key competitive advantage (7-100x faster than picocli). When adding or changing features:
- Prefer lazy initialization over eager allocation — don't create objects until first use (e.g. completers, parsers, collections, queues).
- Use `Collections.emptyList()`/`emptyMap()` as initial values, upgrading to mutable on first write.
- Avoid regex, file I/O, and reflection in the command registration path — defer to first invocation.
- Don't add per-option overhead that scales with command count (e.g. new collections, new lookups per option).
- The benchmark module (`mvn -Pbenchmark -pl benchmark`) and async-profiler (`event=alloc`, `event=cpu`) can verify impact.
Added: 2026-04-18

## Always update aesh-processor when changing annotations or builder APIs
The annotation processor (`aesh-processor` module) generates `ProcessedCommand`/`ProcessedOption` metadata at compile time, bypassing the reflection-based `AeshCommandContainerBuilder`. When adding new attributes to `@CommandDefinition`, `@GroupCommandDefinition`, `@Option`, `@OptionList`, `@OptionGroup`, `@Argument`, or `@Arguments`, or adding new builder methods to `ProcessedCommandBuilder`/`ProcessedOptionBuilder`, the processor's `CodeGenerator.java` must be updated to emit the corresponding builder calls. Without this, commands compiled via the processor silently ignore the new feature — no compile error, just missing behavior at runtime.
Added: 2026-04-18
