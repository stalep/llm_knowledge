## SettingsImpl raw type was the root cause of @SuppressWarnings cascading
SettingsImpl implemented raw `Settings` instead of `Settings<CI>`, which erased all generic type info on overridden methods. This forced SettingsBuilder to accept raw `CommandRegistry` and `CommandInvocationProvider` parameters, requiring a class-level `@SuppressWarnings("unchecked")`. Fixing the `implements` clause eliminated the need for suppression entirely.
Observed: 2026-04-13

## Interface default methods as replacement for trivial provider implementations
The aesh provider pattern (ConverterInvocationProvider, CompleterInvocationProvider, etc.) had dedicated Aesh*Provider impl classes that only did identity pass-through. Moving the identity implementation to a `default` method on the interface and using anonymous `new Interface() {}` for instantiation eliminated 5+ classes with no behavioral change.
Observed: 2026-04-13

## AeshInvocationProviders constructed in SettingsBuilder.build() IS used
Tests in CompletionParserTest call `SettingsBuilder.builder().build().invocationProviders()` directly, so the invocationProviders created in `build()` is not dead code — even though the AeshCommandRuntimeBuilder path ignores it and reconstructs its own. Both paths must remain working.
Observed: 2026-04-13

## Startup allocation hotspots: PropertiesLookup regex and ProcessedOptionBuilder
async-profiler allocation profiling revealed two main allocation sources during command registration:
1. PropertiesLookup.checkForSystemVariables — allocated regex Matcher, int[], ArrayList for every option's default values, even though >99% of defaults are not system variable references. A fast-path `${` prefix check avoids all regex work.
2. ProcessedOptionBuilder — allocated ArrayList for defaultValues on every builder, but most options have no defaults. Lazy initialization (start with Collections.emptyList, upgrade on first add) eliminated ~77% of ArrayList allocations.
Observed: 2026-04-18

## CLConverterManager cache should be pre-populated
CLConverterManager uses a factory pattern with lazy cache population via ConcurrentHashMap.computeIfAbsent. Since it's a singleton with only 22 built-in types, pre-populating the cache at construction time eliminates the two-step lookup (cache miss → factory → computeIfAbsent) and reduces ConcurrentHashMap overhead by 73% during startup.
Observed: 2026-04-18

## DefaultCommandContainer ConcurrentLinkedQueue is unused during registration
DefaultCommandContainer allocates a ConcurrentLinkedQueue<ParsedLine> in its constructor, but the queue is only used during command execution (addLine/pollLine), never during command registration. Lazy initialization defers this allocation to first use.
Observed: 2026-04-18

## FileOptionCompleter triggers file stat calls at registration time
ProcessedOptionBuilder.initCompleter() eagerly instantiates FileOptionCompleter for File/Resource-typed options during command registration. Class loading and initialization triggers __xstat64 file system stat calls. Deferring creation to ProcessedOption.completer() (first completion request) avoids this startup cost.
Observed: 2026-04-18

## DefaultValueProvider integrates via AeshCommandPopulator not ProcessedOption
The dynamic default value provider hooks into AeshCommandPopulator.populateObject(), checked AFTER user values but BEFORE static annotation defaults. The provider value is applied via option.addValue() + injectValueIntoField(), reusing the existing injection path. This avoids modifying ProcessedOption's internal default storage and keeps the provider per-command (stored on ProcessedCommand, instantiated from @CommandDefinition annotation). Precedence: user value > dynamic default > static default > reset to null.
Observed: 2026-04-18

## LineParser does not consume backslash escapes inside double quotes
Inside double-quoted strings, LineParser appends `\` literally to the builder (not as an escape). The `\"` sequence within double quotes preserves BOTH characters in the output (`\"` → `\"`), not just the quote. This differs from POSIX shell behavior. However, outside of quotes, `\"` correctly produces just `"` (backslash consumed as escape). This means string reconstruction with double-quote wrapping and `\"` escaping does NOT roundtrip correctly through LineParser. The pre-tokenized path (`executeCommand(String, String[])`) bypasses this entirely.
Observed: 2026-04-18

## Annotation processor preserves command instance identity (no proxying)
The generated `CommandMetadataProvider` creates command instances via direct `new CommandClass()` and passes them to `ProcessedCommandBuilder.command(instance)`, which stores the reference as-is. `ProcessedCommand.getCommand()` returns the exact same object. This means any runtime `instanceof` check on the command instance (e.g., `cmd instanceof CommandLifecycle`) works transparently -- no proxy, no wrapping, no interface stripping. The `clear()` method also preserves the command reference (only clears option values). New runtime-only interfaces like `CommandLifecycle` do NOT require processor changes.
Observed: 2026-04-18

## Mixin options always use reflection path, never get fieldSetter/fieldResetter
The CodeGenerator explicitly skips generating fieldSetter/fieldResetter for mixin options (when mixinFieldName != null). AeshCommandContainerBuilder also never sets them. This locks mixin options into the reflection path (injectValueWithReflection, resetField reflection fallback) on every parse cycle. The generated code knows both command class and mixin field, so setters like `((Cmd)cmd).mixin.field = val` are feasible and would eliminate all parse-time reflection for mixin options.
Observed: 2026-04-19

## resolveMixinInstance() re-resolves mixin Field on every call
ProcessedOption.resolveMixinInstance() calls getField(class, mixinFieldName) + setAccessible(true) + field.get() on every invocation. It is called from injectValueIntoField, resetField, captureInitialValue, and restoreInitialValue. For N mixin options sharing one mixin, the same mixin Field is looked up N times per parse cycle. The Field could be cached on ProcessedOption (or better, on ProcessedCommand keyed by mixinFieldName) to eliminate repeated hierarchy walks.
Observed: 2026-04-19

## ProcessedOption.isTypeAssignableByResourcesOrFile() is public
ProcessedOption.isTypeAssignableByResourcesOrFile() checks File/Resource/Path assignability. Was package-private until 2026-04-20, now public. Used by shell completion generators to decide file vs static-value completion.
Observed: 2026-04-20

## ProcessedOption lacks isBooleanType() and hasShortName() predicates
option.type().getName().equalsIgnoreCase("boolean") appears 6+ times across completion generators and parsers. option.shortName() != null && !option.shortName().isEmpty() appears 7+ times. Neither has a predicate method on ProcessedOption.
Observed: 2026-04-20

## LineParser operator matching ignores escape and quote state
In the operator-checking parse loop (`doParseLine` with operators), operator characters like `;`, `|`, `>` are matched even when inside quoted strings or after an escape character (`haveEscape`). The escape check only applies in the else branch (when no operator matches). This means args containing operator characters cannot be safely represented as escaped strings — they require the pre-tokenized path.
Observed: 2026-04-18

## Parser argumentMarker pattern is the extension point for stop-at-positional
AeshCommandLineParser.doParse() uses a `boolean argumentMarker` that, once set to true, routes all remaining tokens through setArgStatus() as positional arguments. The `--` separator already sets this flag. stopAtFirstPositional reuses the same mechanism: after the first positional argument is consumed via setArgStatus(), it sets argumentMarker=true. The same pattern applies in doParseCompletion(). When stopAtFirstPositional is enabled, the unknown-option error check (`word.startsWith("-")`) must also be skipped to avoid rejecting option-like tokens that should be passthrough arguments.
Observed: 2026-04-18
