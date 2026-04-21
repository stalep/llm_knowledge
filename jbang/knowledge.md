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

## Native-image config files still reference deleted picocli classes

After the aesh migration (commit a25367b7), the native-image config files were not updated:
- `src/native-image/config/reflect-config.json` still references `StrictParameterPreprocessor`,
  `picocli.CommandLine`, `picocli.CommandLine$IFactory`, `picocli.CommandLine$Model$CommandSpec`,
  and `handleDefaultRun` with the old picocli parameter signature.
- `src/native-image/config/reachability-metadata.json` still references all 10 deleted classes:
  AIOptions, CommaSeparatedConverter, ExportMixin, FormatMixin, HelpMixin, KeyValueConsumer,
  StrictParameterPreprocessor, TemplatePropertyConverter, VersionProvider, plus
  `picocli.CommandLine$AutoHelpMixin`.
These stale references will cause native-image build warnings or failures.

Observed: 2026-04-19

## TemplatePropertyConverterTest file name is misleading after migration

`TemplatePropertyConverterTest.java` tests `Template.TemplateAdd.parseProperties()`, not the
deleted `TemplatePropertyConverter` class. The test itself is functionally correct and compiles,
but the file/class name references a class that no longer exists. Should be renamed to
`TemplatePropertyParsingTest` or similar.

Observed: 2026-04-19
