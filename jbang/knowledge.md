## Aesh OptionGroup parsing convention differs from picocli map options

Aesh `@OptionGroup` expects the format `--name<key>=<value>` (e.g., `-Dfoo=bar`), where the key
is the text between the option name and the `=` sign, and the value is after the `=`.

jbang's `--javaagent` uses a different convention: `--javaagent=<agent>=<options>`, where the
agent path IS the value and the options come after a second `=`. Aesh parses this as key="" (empty
string between "javaagent" and the first "=") and value="<agent>=<options>".

This means `@OptionGroup` cannot be used directly for --javaagent without either:
1. A custom OptionParser on the @OptionGroup annotation
2. Post-processing in resolveScriptArgs() to re-parse the values
3. Using a different annotation (@OptionList or @Option with custom parsing)

Observed: 2026-04-18

## Parent command options not propagated in parseCommand

`JBang.parseCommand()` returns the child command (e.g., Run), not the parent (JBang).
When options like `--preview` appear before the subcommand name (`jbang --preview run ...`),
aesh sets them on the parent JBang instance, not the child Run instance.

Since `parseCommand` only returns the child, and side effects like `Util.setPreview(true)`
are triggered in `BaseCommand.execute()` (which parseCommand doesn't call), global flags
set on the parent command are silently lost.

The `checkedRun()` test helper also only calls `cmd.doCall()`, not `cmd.execute()`, so
even if `preview` were set on the child, `Util.setPreview(true)` would still not be called.

**Testing implication:** Tests for inherited boolean flags (verbose, quiet, offline, fresh)
must assert via `Util.isVerbose()` etc., NOT via the field on the child command (e.g.,
`run.verbose`). The fields remain false on the child instance because aesh's
`propagateInheritedOptions()` doesn't reliably copy them in the `buildExecutor` path.
The `applyParentFlags()` workaround sets the Util state from raw args.

Observed: 2026-04-18

## Aesh @OptionGroup does not support space-separated key=value format

Aesh `@OptionGroup(shortName='D')` requires the format `-Dkey=val` (attached).
The space-separated format `-D key=val` (two separate tokens) is not supported.
Aesh's `processProperty()` method checks `word.length() < (1 + name.length())` and
throws `OptionParserException("Option -D, must be part of a property")` when just `-D`
is given as a standalone token.

Tests that use `-D`, `"prop=val"` as two separate args will fail. They must be changed
to `-Dprop=val` (single token) or the parsing must be adapted.

Observed: 2026-04-18

## Aesh resetField sets Boolean wrapper fields to FALSE instead of null

In `ProcessedOption.resetField()`, there is logic at line 226-227:
```java
} else if (!hasValue() && field.getType().equals(Boolean.class)) {
    field.set(instance, Boolean.FALSE);
}
```
This means any unspecified `@Option(hasValue=false)` of type `Boolean` (wrapper) gets
set to `Boolean.FALSE` rather than remaining `null`. This differs from picocli behavior
where unset Boolean fields stay null. This affects serialization (e.g., JSON) where
null fields are omitted but false fields are serialized.

Observed: 2026-04-18

## Aesh resetField nullifies pre-initialized collection fields

When `@Arguments List<String> field = new ArrayList<>()` has no values provided,
aesh's `AeshCommandPopulator` calls `resetField()` which sets the field to `null`,
overriding the initializer. In picocli, unset @Parameters fields retained their
initialized values. Commands that check `.size()` on such fields will NPE.

Observed: 2026-04-18

## Aesh group command --help parsing fails in parseCommand

Aesh's `AeshCommandLineParser.parse()` treats `--help` on a group command specially:
it adds a `CommandLineParserException("'<cmd> --help' is not part of the <cmd> commands")`.
This means `JBang.parseCommand("--help")` throws, unlike picocli which would have
generated help text. Tests that use `checkedRun(null, "--help")` to test help output
cannot work with the `parseCommand` + `doCall()` approach.

Observed: 2026-04-18

## checkedRun exception wrapping differs from picocli

With picocli, exceptions from command execution were typically wrapped in
`ExecutionException` or similar, so tests could check `e.getCause()`. With aesh,
`checkedRun` calls `parseCommand` + `doCall()` directly, so exceptions like
`IllegalArgumentException` propagate unwrapped. Tests checking `e.getCause()` need
to be updated to check `e` directly.

Observed: 2026-04-18

## Picocli-to-aesh migration dropped many inline code comments

The aesh migration removed business-logic comments along with picocli-specific annotations/code.
Key patterns of lost comments:
- SSL/TLS trust manager setup comments in BaseCommand.enableInsecure()
- "NB: Do not put .mainClass(main) here" in BaseBuildCommand.createBaseProjectBuilder()
- Cache clearing logic comments ("if all we add everything", "add the default safe set", "toggle on/off")
- Export.java had ~15 comments explaining JAR copy, manifest update, pom generation, signature removal
- Info.java lost Javadoc on getDocsMap() and the null-return-code explanation for select
- Jdk.java lost the println vs print comment for Windows line separator issues in bash env
- Template.java lost file ref processing pipeline comments
- Run.java lost the HACK comment about interactive mode needing a dummy file

When migrating CLI frameworks, comments should be preserved independently of annotation changes.
Observed: 2026-04-19

## Aesh migration code quality review findings (picocli to aesh)

The migration from picocli to aesh across ~57 files introduced several structural patterns:

1. Mixin flattening: picocli @Mixin classes dissolved into the class hierarchy.
2. @Argument + afterParse() pattern repeated ~15 times for scriptArg -> scriptOrFile copy.
3. Configuration-based default values (IDefaultValueProvider) lost with no aesh equivalent.
4. Version check on every run (VersionChecker.newerVersionAsync) removed from Main/JBang.execute.
5. applyGlobalOptions() defined on JBang but never called -- --stacktrace/-x is dead code.
6. SUBCOMMANDS list in Main.java duplicates the @GroupCommandDefinition annotation on JBang.
7. Five separate createProjectBuilder variants with overlapping builder chains.
8. AIOptions.java is completely unused (Init.java inlines the AI fields directly).
9. gradleify() duplicated identically in Edit.java and Export.ExportGradleProject.
10. GsonBuilder pattern (disableHtmlEscaping/setPrettyPrinting/create) repeated 14 times.
11. Config.BaseConfigCommand.getConfigFile() structurally mirrors CatalogFileOptionsMixin.getCatalog().
12. DebugOptionParser and StrictOptionParser share identical prefix-resolution code block.

Observed: 2026-04-19

## Aesh migration efficiency review findings

Key performance observations:

1. parseCommand() builds a full CommandRegistry + CommandRuntime per call -- reflection over
   JBang (parent) + 18 subcommands + all nested group commands. Called ~126 times in tests.
   Cost: instantiates ~40+ command objects and processes all their @Option fields via reflection.

2. checkedRun() calls parseCommand() then doCall(). On CommandLineParserException, it falls back
   to JBang.execute(), which calls handleDefaultRun() a second time (it was already called inside
   parseCommand), then builds a SECOND full CommandRegistry+Runtime. Total: 2x registry build +
   2x handleDefaultRun on error paths.

3. handleDefaultRun() is called 3 times in the Main.main() hot path if an implicit run triggers
   and then hits a parse error in checkedRun fallback: once in Main.main(), once inside
   parseCommand(), once inside execute(). The function does catalog alias lookups and PATH
   searches (Alias.get(), Util.searchPath()) which involve filesystem I/O.

4. beforeParse() is called on BOTH parent (JBang) and child (e.g., Run) commands during group
   command parsing. This means Util.setVerbose(false) etc. are called 2x per parse. The resets
   are harmless but unnecessary for the parent -- the child's reset immediately overwrites.

5. applyParentFlags() scans ALL args linearly including user script args passed after --.
   It will match "--verbose" or "--offline" even if they appear in user args (after the script
   name). This is a correctness issue, not just performance.

Observed: 2026-04-19

## DefaultCommandInvocation lacks CommandContext for inherited propagation

Aesh's `DefaultCommandInvocation` (used by `AeshRuntimeRunner` and `AeshCommandRuntimeBuilder`)
does NOT override `getCommandContext()` — the default returns null. This means the
`CommandContext`-based inherited option injection in `AeshCommandPopulator.injectInheritedValues()`
cannot work in this path.

The parser-level `propagateInheritedOptions()` (in `AeshCommandLineParser.doPopulate()`) does work
via direct reflection, copying inherited field values from parent to child. However,
`applyParentFlags()` workaround in `JBang.parseCommand()` remains necessary because
`beforeParse()` resets Util flags and the afterParse chain may not reliably restore them
in the `buildExecutor` flow.

Observed: 2026-04-19

## Mixin migration pattern for BaseScriptCommand subclasses

When converting a class from `extends BaseScriptCommand` to `extends BaseCommand` with mixins:
1. Add `@Mixin ScriptMixin scriptMixin` and `@Mixin DependencyInfoMixin dependencyInfoMixin` fields
2. In `afterParse()`: `scriptOrFile = scriptArg` becomes `scriptMixin.scriptOrFile = scriptArg`
3. `validateScript(bool)` becomes `scriptMixin.validate(bool)` (different method name)
4. Bare field refs `sources`, `resources` become `scriptMixin.sources`, `scriptMixin.resources`
5. Accessor methods `getProperties()`, `getDependencies()`, `getRepositories()`, `getClasspaths()`
   become `dependencyInfoMixin.getX()` equivalents
6. `getForceType()` becomes `scriptMixin.getForceType()`
7. Be careful not to change method calls on other objects (e.g., `prj.getRepositories()` should
   remain unchanged -- only bare `this` references need the mixin prefix)

Observed: 2026-04-19

## Mixin migration pattern for Run.java (BaseRunCommand -> BaseBuildCommand + RunMixin)

When converting Run from `extends BaseRunCommand` to `extends BaseBuildCommand` with `@Mixin RunMixin`:
- `BaseBuildCommand` already provides `scriptMixin`, `buildMixin`, `nativeMixin`, `dependencyInfoMixin`
- RunMixin fields: `interactive`, `enableAssertions`, `enableSystemAssertions`, `flightRecorderString`,
  `debugString`, `javaAgentSlots`, `javaRuntimeOptions`, `getCds()`
- BuildMixin fields: `main`, `module`
- ScriptMixin fields: `scriptOrFile`, `getForceType()`
- NativeMixin fields: `nativeImage`
- `runMixin.resolveAfterParse()` must be called in `afterParse()` to replace the config-lookup
  and resolution logic that was in `BaseRunCommand.afterParse()`

Observed: 2026-04-19

## DefaultValueProvider doesn't replace sentinel-based config lookups

Aesh's `DefaultValueProvider` is called for options NOT explicitly set by the user. For options
using `StrictOptionParser` (which sets `""` sentinel for `--option` without value), the provider
is NOT called because the option WAS set (to ""). Config lookups for sentinel values (`run.debug`,
`run.jfr`, `edit.open` sentinel case) cannot be replaced by the provider alone.

The provider works cleanly for options like `init.template` where null = not specified.

Observed: 2026-04-19

## optionalValue doesn't replace StrictOptionParser or DebugOptionParser

Aesh's `@Option(optionalValue=true)` consumes the next non-flag word as the value. This differs
from `StrictOptionParser` (ONLY accepts `=` syntax) and `DebugOptionParser` (pattern-matches
before consuming). Both custom parsers remain necessary.

Observed: 2026-04-19

## AliasAdd mixin migration pattern (BaseRunCommand -> BaseCommand + 6 mixins)

When converting `AliasAdd` from `extends BaseRunCommand` to `extends BaseCommand` with mixins:
- Needs 6 mixins: `ScriptMixin`, `BuildMixin`, `DependencyInfoMixin`, `NativeMixin`, `RunMixin`, `JdkProvidersMixin`
- `enablePreviewRequested` becomes a direct `@Option` field on AliasAdd (not in any mixin)
- `runMixin.resolveAfterParse()` must be called in `afterParse()` for debug/jfr/javaagent resolution
- `createJavaAgents()` accesses `runMixin.javaAgentSlots`
- `JdkProvidersMixin` must be a direct @Mixin on AliasAdd (not nested inside BuildMixin) due to
  aesh's lack of nested @Mixin support
- The `AliasList` and `AliasRemove` inner classes already extended `BaseCommand` and were unaffected

Observed: 2026-04-19

## Aesh does NOT support nested @Mixin (fields inside mixin classes)

Aesh's `ProcessedOption.resolveMixinInstance()` only looks at the command class's own declared
fields when resolving @Mixin annotations. A @Mixin field inside another mixin class is NOT
discovered or resolved. This causes `NoSuchFieldException` at runtime (e.g.,
"Mixin field 'jdkMixin' not found on dev.jbang.cli.Run").

Workaround: Any @Mixin that was nested inside another mixin must be promoted to a direct
field on the command class (or on a base class that the command extends). For example,
`JdkProvidersMixin` cannot live inside `BuildMixin`; it must be a direct field on
`BaseBuildCommand` and on any command class that needs it but doesn't extend BaseBuildCommand
(e.g., `AliasAdd`).

Observed: 2026-04-19

## Native-image config requires Maven model and Gson reflection entries

The native-image `reachability-metadata.json` needs `allPublicMethods` for Maven model classes
(`Model`, `Build`, `BuildBase`, `ModelBase`, `Organization`, `Reporting`) because Maven's
`StringVisitorModelInterpolator` walks them reflectively during dependency resolution.

It also needs `allPublicFields` for Gson-serialized CLI output classes (`AliasOut`, `CatalogOut`,
`TemplateOut`, `JdkOut`, `OriginOut`) used by `--format json` output.

These entries are not auto-discovered by native-image tracing because they depend on which
commands and dependencies are exercised during the trace run.

Observed: 2026-05-01, updated 2026-05-05

## TemplatePropertyConverterTest file name is misleading after migration

`TemplatePropertyConverterTest.java` tests `Template.TemplateAdd.parseProperties()`, not the
deleted `TemplatePropertyConverter` class. The test itself is functionally correct and compiles,
but the file/class name references a class that no longer exists. Should be renamed to
`TemplatePropertyParsingTest` or similar.

Observed: 2026-04-19

## Aesh is 2x FASTER than picocli on JVM for `jbang version` (JDK 25, 2026-04-23)

End-to-end `java -jar jbang.jar version` timing (shadow jar, JDK 25):
- Picocli: ~220ms (1719 classes loaded, last at 0.225s)
- Aesh: ~110ms (1578 classes loaded, last at 0.114s)

Class loading breakdown:
| Category            | Picocli | Aesh | Delta |
|---------------------|---------|------|-------|
| Total classes       | 1719    | 1578 | +141  |
| JDK classes         | 1376    | 1216 | +160  |
| Framework classes   | 178     | 130  | +48   |
| jbang CLI classes   | 103     | 194  | -91   |
| jbang non-CLI       | 40      | 22   | +18   |
| Lambda classes      | 108     | 84   | +24   |
| AeshMetadata        | 0       | 120  | -120  |
| Other               | 22      | 16   | +6    |

Picocli's extra 160 JDK classes include:
- 32 sun.reflect.generics.* classes (vs 17 for aesh) - generic type resolution
- 30 picocli BuiltIn converters (registered eagerly for all types)
- 15 extra java.lang.invoke.LambdaForm classes
- 11 mixin-related classes (separate mixin classes not needed in aesh)

Root cause of picocli slowness: picocli uses runtime reflection to introspect all @Option/@Parameters
fields, which forces loading field VALUE types (domain classes like Project, Catalog, Source$Type,
JdkManager, etc.) even when those commands won't be executed. Aesh's compile-time metadata providers
access fields via anonymous inner classes that only reference the command type, not field value types.

Picocli loads 18 domain classes not loaded by aesh: Alias$JavaAgent, Catalog, CatalogItem, Template,
TemplateProperty, ArtifactInfo, MavenRepo, Jdk, JdkManager, BuildContext, CmdGeneratorBuilder,
Project, ProjectBuilder, RefTarget, Source$Type, TemplateEngine, Cache$CacheClass, Configuration (2nd lambda).

The earlier belief that "aesh takes ~110ms, picocli takes ~21ms" was incorrect. The 21ms number was
from an in-JVM benchmark measuring only `getCommandLine() + parseArgs()`, not end-to-end process startup.
End-to-end, aesh is ~2x faster than picocli.

Observed: 2026-04-23

## Lambda expressions cause JVM startup regression on JDK 25 (2026-04-23)

The aesh annotation processor generated ~3,045 lambda call sites across 63 `_AeshMetadata` classes
(3 per option: fieldSetter, fieldResetter, fieldGetter). All metadata classes are loaded eagerly at
startup, even when only one command is executed.

Each lambda triggers `LambdaMetafactory.metafactory()` → `InnerClassLambdaMetafactory.spinInnerClass()`
which dynamically generates anonymous classes. On JDK 25, this caused ~100ms slower startup vs picocli.
JDK 25's `java.lang.classfile` API (used for lambda class generation) has higher per-lambda bootstrap
cost than JDK 11's ASM-based approach.

Fix: Replace generated lambdas with anonymous inner classes in CodeGenerator. Also replaced lambdas
in CLConverterManager (23 lambdas → concrete converter classes), SettingsBuilder (50 lambdas → direct
setters), and AeshCommandRuntimeBuilder (11 lambdas → direct field assignment).

Result: JDK 25 gap closed from ~100ms to ~15-30ms. Remaining gap is due to eager loading of all 63
metadata classes vs picocli's lazy approach (~17 classes for `jbang version`).

Observed: 2026-04-23

## Exit code propagation bug in Main.main() (2026-04-23)

`Main.main()` called `AeshRuntimeRunner.execute()` but discarded the returned `CommandResult`.
Non-zero exit codes from parse errors (unknown options, mutually exclusive options) were silently
converted to exit 0. Fix: capture the `CommandResult` and call `System.exit(exitCode)` when non-zero.

Observed: 2026-04-23

## --help on group commands blocked by parser exclusion (2026-04-23)

`AeshCommandLineParser.parse()` had `& !(equalsIgnoreCase("--help"))` that prevented `--help` from
being parsed as an option on group commands with `generateHelp=true`. This caused `--help` on the
root command (e.g., `jbang --help`) to be treated as an unknown subcommand, producing an error
message and exit code 2. Removing the exclusion allows `--help` to flow through `doParse()` normally.

Observed: 2026-04-23

## Picocli CLI parsing baseline benchmarks (main branch, 2026-04-23)

Benchmarked on Linux 6.19.12, with 20 warmup + 100 measured iterations per scenario.
All times include `JBang.getCommandLine()` (picocli CommandLine construction).

| Scenario                     | min     | avg     | median  | p95     | max     |
|------------------------------|---------|---------|---------|---------|---------|
| getCommandLine() only        | 19.99ms | 23.90ms | 23.21ms | 29.52ms | 34.24ms |
| version                      | 19.65ms | 21.57ms | 21.27ms | 23.71ms | 27.05ms |
| run (minimal)                | 20.22ms | 21.88ms | 21.68ms | 23.19ms | 27.32ms |
| run (with options)           | 20.23ms | 22.20ms | 22.32ms | 23.56ms | 24.72ms |
| run (with deps)              | 20.43ms | 22.26ms | 22.32ms | 24.45ms | 26.48ms |
| build (compile opts)         | 19.64ms | 21.93ms | 22.00ms | 23.53ms | 23.90ms |
| alias list                   | 19.62ms | 21.79ms | 21.78ms | 23.32ms | 24.13ms |
| init (with options)          | 19.46ms | 21.55ms | 21.52ms | 23.52ms | 23.94ms |
| execute("version") full      | 19.74ms | 21.42ms | 21.28ms | 22.82ms | 25.71ms |

Key findings:
- Registry build (getCommandLine) dominates total time at ~20-24ms median
- parseArgs adds negligible overhead (~0-1ms) regardless of scenario complexity
- handleDefaultRun adds negligible overhead
- The `--module` option uses `StrictParameterPreprocessor` with `arity="0..1"`, requiring
  `--module=value` syntax (not `--module value`). This is a picocli-specific behavior.

Observed: 2026-04-23

## ExitException must be caught in BaseCommand.execute(), not left to aesh

Aesh's `Executions.java:275-277` catches any `Exception` from `command.execute()`, wraps it in
a new `RuntimeException`, and sets `result=CommandResult.FAILURE`. If `doCall()` throws
`ExitException(EXIT_INVALID_INPUT=2)`, aesh converts it to exit code 4 (FAILURE) unless
`BaseCommand.execute()` intercepts it first.

Fix: catch `ExitException` in `execute()`, print the error message via `Util.errorMsg()`,
and return `CommandResult.valueOf(e.getStatus())` to preserve the exact exit code.

Observed: 2026-04-29

## Deprecated flag scan must only check leading options

The deprecated flag detector in `Main.handleDefaultRun()` must only scan `leadingOpts`
(flags before the first positional argument), not all args. Otherwise `jbang run echo.java --init`
triggers the deprecated flag error even though `--init` is a script argument, not a jbang flag.

Observed: 2026-05-03

## JBangDefaultValueProvider must key by class, not leaf command name

Config key resolution (e.g., `app.list.format`) requires knowing the full command path.
The command path map must be keyed by `Class<?>`, not by leaf command name (e.g., `"list"`),
because multiple commands share the same leaf name (`alias list`, `template list`, `config list`,
etc.). Using leaf name as key causes the last-registered command to win, producing wrong config
keys for all others.

Observed: 2026-05-03

## Aesh native image startup benchmarks (2026-05-01)

End-to-end benchmarks with GraalVM 25 native image, 20 warmup + 100 measured iterations:

| Scenario       | Aesh   | Picocli | Speedup |
|----------------|--------|---------|---------|
| version        | 6ms    | 33ms    | 5.5x    |
| run --help     | 6ms    | 37ms    | 6.2x    |
| --help         | 29ms   | 58ms    | 2.0x    |

JDK 25 Temurin (JVM mode):
| version        | 109ms  | 228ms   | 2.1x    |
| run --help     | 118ms  | 245ms   | 2.1x    |
| --help         | 207ms  | 303ms   | 1.5x    |

Observed: 2026-05-01
