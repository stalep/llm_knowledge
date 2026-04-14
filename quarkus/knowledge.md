## Monorepo snapshot versioning causes stale dependency failures

All modules use `999-SNAPSHOT`. When a branch adds new APIs (methods, classes), the local Maven cache
may still hold an older jar from a previous `mvn install`. Tests then fail with `NoSuchMethodError`
or `Failed to start quarkus` — not because code is broken, but because dependencies are stale.

Fix: run `mvn install -pl <module> -am -DskipTests -Dno-format` for upstream modules before testing.

Key modules that often need rebuilding:
- `test-framework/junit-internal` — contains `QuarkusUnitTest` (not `junit5-internal`)
- `extensions/vertx-http/runtime` and `extensions/vertx-http/deployment` — HTTP server, CORS
Observed: 2026-04-13

## Import sorting enforced by impsort-maven-plugin

Compilation with default settings runs `impsort-maven-plugin:check`. After refactoring (adding/removing
imports), the build fails if imports are unsorted. Use `-Dno-format` to skip during iteration,
but ensure imports are clean before final commit.
Observed: 2026-04-13

## Quarkus extension deployment vs runtime module boundary

Runtime modules must never depend on deployment modules. For example, `DelegateConnection` in
`core/deployment` cannot be used as a base class by runtime extension code. When extracting shared
abstractions, they must live in the runtime module.
Observed: 2026-04-13

## SmallRye Config handles enum conversion automatically

`@ConfigMapping` interface methods can return enum types directly (e.g., `AeshMode mode()` instead
of `String mode()`). SmallRye Config parses the string value into the enum. Invalid config values
become parse errors at startup rather than silently falling through to default behavior.
Observed: 2026-04-13

## Tests starting HTTP servers cannot run in parallel

Quarkus integration tests that start HTTP servers (e.g., WebSocket, SSH deployment tests) bind to
fixed ports (8081). Running multiple test modules in parallel causes `Port already bound` errors.
Run these test modules sequentially.
Observed: 2026-04-13

## GraalVM native image: static ExecutorService fields create Cleaner objects

A `static final ExecutorService` (e.g., `Executors.newSingleThreadExecutor()`) creates a
`jdk.internal.ref.CleanerImpl$PhantomCleanableRef` captured in the native image heap. GraalVM
rejects this with "Detected an active instance of Cleanable". Fix: lazily initialize the executor
(e.g., in a `register()` method or `@PostConstruct`) so it's never created during image build.
Observed: 2026-04-13

## GraalVM native image: aesh WinConsoleNative requires runtime init

`org.aesh.terminal.tty.impl.WinConsoleNative` loads a Windows native DLL in its static initializer.
On non-Windows hosts, this crashes native-image. Fix: add a `RuntimeInitializedClassBuildItem` for
this class in the deployment processor.
Observed: 2026-04-13

## Optional-dependency beans must be vetoed when the dependency is absent

If a runtime bean implements an interface from an optional dependency (e.g., `AeshWebSocketHealthCheck
implements HealthCheck` where `quarkus-smallrye-health` is `<optional>true</optional>`), and the bean
has CDI discovery annotations (`@Readiness`, `@ApplicationScoped`), Arc discovers it via Jandex even
when the dependency jar is absent. At runtime this causes `NoClassDefFoundError` (WARN in native).
Fix: use an annotation transformer to `@Vetoed` the class when the capability is absent, AND guard
the `HealthBuildItem` with a `Capability.SMALLRYE_HEALTH` check (return null if missing).
The SSH module already does this correctly; the WebSocket module was missing it.
Observed: 2026-04-13
