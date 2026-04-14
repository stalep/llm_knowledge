## AeshCommandLineParser field type could be widened to eliminate unchecked cast
The constructor accepts `ProcessedCommand<? extends Command<CI>, CI>` but casts to the exact field type `ProcessedCommand<Command<CI>, CI>`. Widening the field and `getProcessedCommand()` return type in the CommandLineParser interface would remove the cast, but cascades to doPopulate() and callers in AeshCommandRuntime and MutableCommandRegistryImpl. Needs evaluation of whether the wider type breaks any downstream code.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-13
Last tested: 2026-04-13

## AeshCommandRuntimeBuilder.settings() should consume invocationProviders from Settings
Currently `settings()` copies 5 individual providers from Settings but ignores `settings.invocationProviders()`. Then AeshCommandRuntime reconstructs AeshInvocationProviders from those individuals. This means custom InvocationProviders set via `SettingsBuilder.invocationProviders()` are silently lost on the RuntimeBuilder path. May be an actual bug if anyone relies on that setter.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-13
Last tested: 2026-04-13
