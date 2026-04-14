## SettingsImpl raw type was the root cause of @SuppressWarnings cascading
SettingsImpl implemented raw `Settings` instead of `Settings<CI>`, which erased all generic type info on overridden methods. This forced SettingsBuilder to accept raw `CommandRegistry` and `CommandInvocationProvider` parameters, requiring a class-level `@SuppressWarnings("unchecked")`. Fixing the `implements` clause eliminated the need for suppression entirely.
Observed: 2026-04-13

## Interface default methods as replacement for trivial provider implementations
The aesh provider pattern (ConverterInvocationProvider, CompleterInvocationProvider, etc.) had dedicated Aesh*Provider impl classes that only did identity pass-through. Moving the identity implementation to a `default` method on the interface and using anonymous `new Interface() {}` for instantiation eliminated 5+ classes with no behavioral change.
Observed: 2026-04-13

## AeshInvocationProviders constructed in SettingsBuilder.build() IS used
Tests in CompletionParserTest call `SettingsBuilder.builder().build().invocationProviders()` directly, so the invocationProviders created in `build()` is not dead code — even though the AeshCommandRuntimeBuilder path ignores it and reconstructs its own. Both paths must remain working.
Observed: 2026-04-13
