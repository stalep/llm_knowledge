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
Status: RESOLVED for generated path (2026-04-23). CodeGenerator now generates fieldSetter/fieldGetter/fieldResetter for mixin options using cached static Field constants for private fields.

## resolveMixinInstance() re-resolves mixin Field on every call
ProcessedOption.resolveMixinInstance() calls getField(class, mixinFieldName) + setAccessible(true) + field.get() on every invocation. It is called from injectValueIntoField, resetField, captureInitialValue, and restoreInitialValue. For N mixin options sharing one mixin, the same mixin Field is looked up N times per parse cycle. The Field could be cached on ProcessedOption (or better, on ProcessedCommand keyed by mixinFieldName) to eliminate repeated hierarchy walks.
Observed: 2026-04-19
Status: RESOLVED for generated path (2026-04-23). On the generated path, resolveMixinInstance() is dead code because fieldGetter/fieldSetter/fieldResetter bypass it entirely. On the reflection path, the Field is now cached per ProcessedOption.

## ProcessedOption.getFieldValue/setFieldValue eliminate reflection for inherited option propagation
AeshCommandLineParser.propagateInheritedOptions() and AeshCommandPopulator.injectInheritedValues() previously used raw Field reflection to copy values between parent and child commands. Both now use ProcessedOption.getFieldValue()/setFieldValue() which dispatch through fieldGetter/fieldSetter when available (generated path) and fall back to cached Field reflection otherwise. This also fixed AeshCommandPopulator.getField() which used exception-based getDeclaredField() — now uses iteration.
Observed: 2026-04-23

## ProcessedCommand.parentCommandInjector eliminates @ParentCommand reflection scanning
@ParentCommand injection previously scanned all fields with getDeclaredFields() looking for the annotation, then used setAccessible()+field.set(). ProcessedCommand now has a BiConsumer<Object,Object> parentCommandInjector that the CodeGenerator sets. The injector does direct field assignment (public fields) or uses a cached static Field constant (private fields). Both AeshCommandPopulator and Executions check for the injector before falling back to reflection.
Observed: 2026-04-23

## ProcessedOption.isTypeAssignableByResourcesOrFile() is public
ProcessedOption.isTypeAssignableByResourcesOrFile() checks File/Resource/Path assignability. Was package-private until 2026-04-20, now public. Used by shell completion generators to decide file vs static-value completion.
Observed: 2026-04-20

## ProcessedOption lacks isBooleanType() and hasShortName() predicates
option.type().getName().equalsIgnoreCase("boolean") appears 6+ times across completion generators and parsers. option.shortName() != null && !option.shortName().isEmpty() appears 7+ times. Neither has a predicate method on ProcessedOption.
Observed: 2026-04-20

## LineParser operator matching ignores escape and quote state
In the operator-checking parse loop (`doParseLine` with operators), operator characters like `;`, `|`, `>` are matched even when inside quoted strings or after an escape character (`haveEscape`). The escape check only applies in the else branch (when no operator matches). This means args containing operator characters cannot be safely represented as escaped strings — they require the pre-tokenized path.
Observed: 2026-04-18

## ProcessedOption.getField() exception-as-control-flow was the top CPU and alloc hotspot
The old getField() used Class.getDeclaredField() which throws NoSuchFieldException at each class hierarchy level where the field is absent. Each exception triggers Throwable.fillInStackTrace() — a native method that walks the entire call stack and allocates long[], Object[], int[], short[] arrays. In the generated (processor) path, where fieldName doesn't match the command class fields, this dominated ~80% of both CPU time and allocations. Replacing with getDeclaredFields() iteration (no exceptions thrown) eliminated all exception overhead and gave 4-10x speedup on the generated startup path. The ProcessedOptionBuilder.apply(Consumer) lambda pattern was a secondary alloc hotspot — each builder setter created a lambda capture object. Direct field assignment eliminated ~30 lambda allocations per option.
Observed: 2026-04-21

## doGenerateHelp/doGenerateVersion bypass addOption() — must call setParent manually
ProcessedCommand.doGenerateHelp() and doGenerateVersion() add auto-generated options directly via `options.add(opt)` instead of going through `addOption()`. The `addOption()` method calls `opt.setParent(this)` which is required by `AeshOptionParser.parse()` — it calls `option.parent().searchAllOptions()` to check whether the next token is another option. Without `setParent`, this NPEs at parse time. Any code that adds to the options list directly must also call `setParent`.
Observed: 2026-04-22

## ProcessedOptionBuilder.valueSeparator defaults to space, not comma
The builder field `valueSeparator` defaults to `' '`. The @OptionList annotation defaults to `','` and @OptionGroup uses comma in the reflection path. Generated code must always emit `.valueSeparator(...)` for OptionList (even when the annotation value is the default comma) and must explicitly set `.valueSeparator(',')` for OptionGroup, otherwise the generated path diverges from reflection.
Observed: 2026-04-22

## AeshOptionParser doesn't apply default values for optionalValue options
When a NORMAL-type option with optionalValue=true is parsed bare (e.g., `--help` without `=value`), AeshOptionParser leaves getValue() as null. The parser only skips the "no value given" error (line 61: `!option.isOptionalValue()`), but doesn't fill in the default value. Code that changes a boolean option to an optionalValue string must add explicit default-value application at both exit paths in `parse()`: (1) after the while loop when no more words remain, and (2) in the else branch when the next word is another option. Without this, `getValue()` returns null and any `getValue() != null` check fails — the option appears unset even though it was specified.
Observed: 2026-04-21

## CodeGenerator must use direct instantiation for provider fields
CodeGenerator used `setHelpSectionProviderClass(X.class)` for the helpSectionProvider, which defers to reflective Class.newInstance(). The correct pattern is `setHelpSectionProvider(new X())` — direct instantiation, consistent with how the reflection path works (AeshCommandContainerBuilder instantiates the class and calls the instance setter). The `assertEquivalence` helper in ProcessorTest now checks command-level fields (generateHelp, disableParsing, stopAtFirstPositional, helpUrl, helpGroup) and option-level fields (overrideRequired, optionalValue, exclusiveWith, askIfNotSet, valueSeparator, visibility) to catch such parity gaps automatically.
Observed: 2026-04-23

## Benchmark must use real generated metadata providers, not hand-rolled ProcessedOptionBuilder
The original StartupBenchmark's "generated" path was fake — it hand-rolled ProcessedOptionBuilder calls without fieldSetter/fieldGetter/fieldResetter, making it measure the same overhead as the reflection path. The fix was to use `AeshCommandContainerBuilder.create(Class)` which auto-detects the processor-generated `CommandMetadataProvider` via `MetadataProviderRegistry`. For the reflection path, the private `doGenerateCommandLineParser(Command)` method is invoked via `Method.setAccessible(true)` handle to bypass the registry. Also: Maven `provided` scope does NOT trigger annotation processor discovery — an explicit `annotationProcessorPaths` block in maven-compiler-plugin is required.

Real benchmark results with correct measurement: generated path is 3.4-3.8x faster than reflection at 100 commands. At scale (100 nested groups), aesh generated is 655x faster than picocli reflection.
Observed: 2026-04-23

## propagateInheritedOptions must use findLongOptionNoActivatorCheck and skip child-parsed values
propagateInheritedOptions() copies parent inherited option values to child commands after population. Two bugs: (1) it used searchAllOptions(name) with a bare name (no `--` prefix), which routes through findBareLongOption() requiring acceptNameWithoutDashes(). Options without that flag weren't found on the child, so the method fell through to field reflection and unconditionally overwrote the field — even if the child had already parsed its own value. Fix: use findLongOptionNoActivatorCheck() which matches by name without restrictions. (2) For primitive types like boolean, getFieldValue() returns a boxed non-null value (Boolean.FALSE), so the null check never skips propagation. When the child already parsed the option (e.g., `group sub --verbose`), the parent's default false would overwrite the child's true. Fix: skip propagation when the child's ProcessedOption already has parsed values.
Observed: 2026-04-29

## enterSubCommandMode pushes root parser, not the parsed child parser
AeshCommandInvocation.enterSubCommandMode() used `commandContainer.getParser()` which is always the root command container's parser. For nested group commands (group within a group), this pushed the root parser instead of the child, causing the wrong command name in prompts and preventing nested sub-command mode from working. Fix: check `parser.parsedCommand()` and use the child parser when it matches the command being entered.
Observed: 2026-05-07

## Splitting aesh from readline requires more than moving Prompt
Prompt was moved to terminal-api (clean, zero dependencies on readline). But CompleteOperation, Completion, CompletionHandler, and the entire completion framework are in the readline module and are used by aesh's core parsing code — not just the interactive console. AeshRuntimeRunner also uses completion for shell script generation (--aesh-completion). A proper split would require either moving the completion interfaces to terminal-api or creating an aesh-core module. Needs dedicated investigation.
Observed: 2026-05-08

## doInjectValues in completion parser must swallow all exceptions
AeshCommandLineCompletionParser.doInjectValues() populates command fields during completion so completers can access already-parsed state. It originally caught only CommandLineParserException and OptionValidatorException, but converters like IntegerConverter throw NumberFormatException (a RuntimeException) when given empty/partial input during tab completion (e.g., `--parallel=<tab>`). The catch must include RuntimeException to prevent completion crashes. Similarly, the sub-command mode completion transfer in ReadlineConsole.AeshCompletion must copy appendSeparator and separator from the prefixed operation to the original, otherwise flags like "no trailing space after =" are lost.
Observed: 2026-05-07

## Parser argumentMarker pattern is the extension point for stop-at-positional
AeshCommandLineParser.doParse() uses a `boolean argumentMarker` that, once set to true, routes all remaining tokens through setArgStatus() as positional arguments. The `--` separator already sets this flag. stopAtFirstPositional reuses the same mechanism: after the first positional argument is consumed via setArgStatus(), it sets argumentMarker=true. The same pattern applies in doParseCompletion(). When stopAtFirstPositional is enabled, the unknown-option error check (`word.startsWith("-")`) must also be skipped to avoid rejecting option-like tokens that should be passthrough arguments.
Observed: 2026-04-18

## OutputRedirectionOperator handles both > and >> via boolean append flag
OutputRedirectionOperator uses a constructor boolean `append` to differentiate between overwrite (>) and append (>>) behavior. There is no separate AppendOutputRedirectionOperator class. The `buildOperator()` factory in Executions passes `true` for APPEND_OUT. The OutputDelegateImpl inner class checks `append` in buildWriter() to select StandardOpenOption.APPEND vs overwrite. This avoids class duplication but puts behavioral branching inside the inner class.
Observed: 2026-05-07

## OutputDelegate.close() has commented-out writer.close() -- resource leak
OutputDelegate.close() only checks/throws the stored IOException but never closes the underlying BufferedWriter (the writer.close() call is commented out at lines 58-59). For pipe operators this is benign (ByteArrayOutputStream), but for file redirection this means the file writer is never explicitly closed -- relying on GC finalization to flush/close the underlying file handle.
Observed: 2026-05-07

## CommandInvocationConfiguration has 7 constructor overloads for 4 fields
CommandInvocationConfiguration has constructors for every combination of (context, outputDelegate, inputDelegate, dataProvider). All telescope to the 4-arg canonical constructor. The class could use a builder or just the canonical constructor with nulls, since all fields are nullable. The `impl.operator` package types (OutputDelegate, InputDelegate, DataProvider) leak into this public-API-adjacent class.
Observed: 2026-05-07

## Duplicate input-vs-pipe check in Executions.ExecutionImpl.execute()
Lines 182-195 in Executions.java check hasRedirectIn() then throw if pipedData exists, then check pipedData then throw if hasRedirectIn(). Only one branch can ever trigger since both throw the same exception. The second check is unreachable if the first triggers.
Observed: 2026-05-07

## ReadlineConsole.preProcessors is static but mutated per-instance — concurrency and leak bug
ReadlineConsole.preProcessors is declared `private static final List<...> preProcessors = new ArrayList<>()` at line 104, but the constructor appends to it on every instance creation (ExportPreProcessor, AliasPreProcessor). Multiple ReadlineConsole instances accumulate preprocessors indefinitely in the shared static list, and concurrent instantiation can corrupt the ArrayList. This field must be an instance field.
Observed: 2026-05-10

## CLConverterManager.getConverter() has TOCTOU race on HashMap
CLConverterManager is a singleton with a plain HashMap. getConverter() does unsynchronized check-then-put for enum types: if the enum class isn't in the map, it creates an EnumConverter and calls put(). Two threads calling getConverter for the same enum type can corrupt the HashMap. The converters map should use ConcurrentHashMap or synchronize the getConverter method.
Observed: 2026-05-10

## ExportManager.listAllVariables() uses wrong map for system environment values
When exportUsesSystemEnvironment is true, the system-env loop (line 222-228) iterates System.getenv().keySet() but looks up values in `variables` (the local export map), not System.getenv(). This produces "null" string output for any env var not also in the variables map. Should use getVariable(key) or System.getenv().get(key).
Observed: 2026-05-10

## ExportManager.addVariable() NPEs on self-referencing undefined variable
Line 100-101: `variables.get(name)` returns null if the variable hasn't been set before, and String.replace(null) throws NPE. Common pattern like `export PATH=$PATH:/new/dir` on first definition will crash.
Observed: 2026-05-10

## ExportManager.parseValue() has no cycle detection — infinite recursion possible
If two variables reference each other (A=$B, B=$A), parseValue() recurses until StackOverflowError. No visited-set or depth limit is used.
Observed: 2026-05-10

## AeshOptionParser.doAddValueToOption uses String.split with unquoted separator character
Line 147: `word.split(String.valueOf(currOption.getValueSeparator()))` treats the separator as regex. If the separator is a regex metacharacter (|, ., *, +, etc.), this throws PatternSyntaxException or produces wrong splits. Should use Pattern.quote().
Observed: 2026-05-10

## doParseCompletion catch block distinguishes "no value" from other parse errors
The catch block at AeshCommandLineParser.java:682 now checks the exception message for "no value was given" and maps only that case to OPTION_MISSING_VALUE. Other OptionParserExceptions (unknown options, grouping errors, property syntax errors) map to INVALID_INPUT, which has no handler in the completion parser and falls through silently — a safer fallback than attempting value completion.
Observed: 2026-05-11

## OPTION_MISSING_VALUE short option branch was a no-op (fixed)
AeshCommandLineCompletionParser.java lines 145-153: When a short option was used without a value, no separator, and no trailing space (e.g., `cmd -e` with Tab), the code did nothing (the TODO block). The fix adds the same behavior as the long-option branch: offer a space as a completion candidate so the user can then type the value. The key flow is: AeshOptionParser.parse() throws OptionParserException("no value was given") → caught by doParseCompletion → sets OPTION_MISSING_VALUE → completion parser now offers " " for short options with hasValue()==true.
Observed: 2026-05-11

## PipelineResource is a heavyweight adapter with 20+ stub methods
PipelineResource implements the full Resource interface (file system abstraction) to wrap a BufferedInputStream for pipe data. Most methods are stubs (return null, false, empty list, or throw nothing). The Resource interface was designed for file system resources; pipe data only needs read(). This forces pipe consumers to program against a file-like API when they only need an InputStream.
Observed: 2026-05-07
