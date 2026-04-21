# Knowledge Tree Index

## Shared
- [api-design](./_shared/api-design/) — REST API design patterns (DTOs, JPA serialization, JAX-RS)
- [concurrency](./_shared/concurrency/) — JTA transaction visibility, CDI scoping for shared infrastructure, thread/connection pool sizing
- [performance](./_shared/performance/) — Cross-project performance patterns
- [security](./_shared/security/) — Cross-project security patterns

## Projects
- [aesh](./aesh/) — Æsh CLI framework: API simplification, generics cleanup, provider patterns
- [aesh-readline](./aesh-readline/) — Æsh terminal/readline: Windows native code, FFM migration, console API
- [h5m](./h5m/) — PoC rewrite of Horreum: DAG-based performance data transformation and regression detection
- [horreum](./horreum/) — Performance regression detection system: 6-entity pipeline, event-driven, PostgreSQL + Keycloak
- [qdup](./qdup/) — Remote command execution tool: shell lifecycle, deferred commands, SSH path resolution
- [jjq](./jjq/) — Pure Java jq engine: bytecode VM, multi-backend JSON adapters, GraalVM native-image
- [jbang](./jbang/) — jbang CLI tool: picocli-to-aesh migration, option parsing, preview mode
- [quarkus](./quarkus/) — Quarkus framework: extension development (aesh CLI), build system quirks, CDI patterns
