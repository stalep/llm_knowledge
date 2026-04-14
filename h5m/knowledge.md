## h5m is a PoC rewrite of Horreum
h5m reimplements Horreum's core pipeline (DAG-based JSON transformation, change detection via FixedThreshold/RelativeDifference, fingerprinting) but intentionally drops schema validation — schemas added more complexity than value in Horreum. h5m adds JQ and JSONata node types that Horreum lacks.
Observed: 2026-04-07

## Edge table cleanup requires explicit SQL
JPA/Hibernate only cleans up the owning side of @ManyToMany join tables (value_edge, node_edge). These are adjacency list tables (direct parent-child edges), not true closure tables — transitive relationships are computed at query time via recursive SQL CTEs. When deleting an entity that is a *parent* (inverse side), the edge rows where parent_id = deleted_id are NOT automatically cleaned. Explicit `DELETE FROM value_edge WHERE parent_id = :id` is required before entity deletion to avoid orphaned FK references.
Observed: 2026-04-07

## SQLite COUNT(*) returns Integer, not Long
Native queries with COUNT(*) on SQLite return java.lang.Integer, while PostgreSQL returns java.lang.Long. Cast via `((Number) result).longValue()` to handle both.
Observed: 2026-04-07

## REST API added via JAX-RS annotations on service interfaces
Service interfaces now have JAX-RS + OpenAPI annotations following the Horreum pattern (annotations on interface, implementations unchanged). Deps: quarkus-rest, quarkus-rest-jackson, quarkus-smallrye-openapi. CORS config scoped to %dev profile. 14 REST endpoint integration tests pass using RestAssured. Circular reference Node->NodeGroup->List<Node> causes StackOverflow in REST serialization — flat DTOs needed (see plan-flatten-api-model.md).
Observed: 2026-04-07

## Hibernate format mapper conflicts with quarkus-rest-jackson
Adding quarkus-rest-jackson sets `quarkus.jackson.write-dates-as-timestamps` by default, which triggers Hibernate ORM's `BuiltinFormatMapperBehaviour` detection and causes a startup failure. Fix: add `quarkus.hibernate-orm.mapping.format.global=ignore` to application.properties.
Observed: 2026-04-07

## JAX-RS does not allow overloaded methods on the same path+verb
Two methods with the same @Path and @GET/@POST but different parameters cause `DeploymentException: GET /api/node is declared by:` at startup. Must use distinct paths (e.g., `create` vs `createConfigured` with `@Path("configured")`) or consolidate overloads with optional @QueryParam.
Observed: 2026-04-07

## JMH benchmarks cannot use Quarkus CDI
JMH creates State instances outside CDI, so @QuarkusTest annotations on JMH State classes don't work. DB-backed benchmarks that need services (NodeService, etc.) must be written as @QuarkusTest classes with programmatic System.nanoTime timing instead of JMH. This gives full CDI/transaction support via FreshDb pattern.
Observed: 2026-04-07

## Edge table insertion scales linearly for flat/chain topologies
Flat and chain node insertion costs ~2ms/node consistently from 100 to 2000 nodes (SQLite). Diamond topology per-node cost grows with width due to quadratic edge count: 3x5=4.6ms/node, 5x10=8.9ms/node, 8x20=18.1ms/node. Driven by KahnDagSort on sources list in @PrePersist. Query performance (FQDN lookup, descendant values) remains sub-millisecond at all tested scales.
Observed: 2026-04-07

## Detached JPA entities across transaction boundaries cause "Multiple representations" errors
When passing a JPA entity from one tm.begin()/tm.commit() block to another and using it as a source for a new entity, Hibernate throws "Multiple representations of the same entity are being merged." Fix: store entity IDs and reload via findById() in each new transaction.
Observed: 2026-04-07

## @BatchSize on collections overrides global fetch.batch-size
Hibernate's `@BatchSize(size = N)` annotation on a specific `@ManyToMany` or `@OneToMany` field overrides the global `quarkus.hibernate-orm.fetch.batch-size` setting. If global is 100 but the annotation says 25, that collection batch-fetches in groups of 25. Either remove the annotation to inherit the global default, or keep them aligned.
Observed: 2026-04-08

## KahnDagSort short-circuit for independent sources gives 3.5x speedup
When the sources list has no internal dependencies (no source depends on another source in the same list), the full topological sort can be skipped entirely. This is the common case for flat topologies. Checking `adjacencyMap.containsKey(dep)` after building the adjacency map avoids a separate HashSet allocation. JMH confirms ~3.5x faster for flat lists (175ns vs 604ns at size=10).
Observed: 2026-04-08

## PostgreSQL dramatically outperforms SQLite for diamond DAG insertion
Diamond topology (8 layers x 20 width, 161 nodes, 2820 edges) insertion: PostgreSQL ~407ms vs SQLite ~2840ms — 7x faster. PostgreSQL's query optimizer handles the quadratic edge growth in closure tables much better. Flat/chain topologies show similar performance between the two.
Observed: 2026-04-08

## Surefire file-pattern excludes work; tag-based excludes do not with -Dtest
Using `<excludedGroups>benchmark</excludedGroups>` in surefire config prevents discovery of `@Tag("benchmark")` tests even when explicitly selected with `-Dtest=ClassName`. File-pattern exclusion `<exclude>**/benchmark/**</exclude>` works correctly — tests are excluded from `mvn test` but can be run explicitly with `-Dtest=`.
Observed: 2026-04-08

## Panache delete() fails silently on entities from native CTE queries
When entities are fetched via native CTE queries (e.g., `getDescendantValues`), calling `v.delete()` (Panache) or `ValueEntity.deleteById(v.id)` does not reliably delete the row. The SQL is emitted but the transaction appears to roll back silently. Fix: use native SQL `DELETE FROM value WHERE id = :id` after explicitly cleaning both sides of the edge table (`deleteParentEdges` + `deleteChildEdges`). The `delete(ValueEntity)` method using `ValueEntity.deleteById` works because it's called recursively with properly managed entities, not CTE results.
Observed: 2026-04-09

## ObjectMapper should be a shared static constant
`new ObjectMapper()` is expensive and thread-safe. NodeService had 7 separate instantiations per call path. Replaced with `private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()`. Same pattern applies across the codebase (50+ instances in tests and services).
Observed: 2026-04-09

## EdgeQueries utility consolidates closure table operations
Both NodeService and ValueService had identical parent-count and edge-delete methods differing only in table name (`node_edge` vs `value_edge`). Extracted to `EdgeQueries` (package-private, static methods): `getParentCount`, `getParentCounts`, `deleteParentEdges`, `deleteChildEdges`. Parameterized by table name string.
Observed: 2026-04-09

## Service-layer change detection replaced DAG-based NotificationNode
NotificationNode (a DAG node type that computed change detection during work execution) was removed. Change detection now happens at the service layer: FolderService.getDetectionValues() queries for FIXED_THRESHOLD/RELATIVE_DIFFERENCE values after all work completes. CLI upload returns exit code 2 when changes are detected. This avoids coupling detection logic to the DAG execution model and supports future web frontend use.
Observed: 2026-04-09

## Per-root-value work tracking replaces global awaitIdle
Service-layer change detection uses per-upload tracking instead of waiting for the entire WorkQueue to drain. Each Work item carries `sourceValues = List.of(rootValue)` through the cascade chain. WorkQueue tracks a `RootValueTracker` (count + Condition) per root value ID, all guarded by the existing `takeLock`. Race-freedom relies on WorkService.execute() creating cascade work BEFORE calling decrement() in the finally block. The global `awaitIdle`/`isIdle` were removed — no production code needs them.
Observed: 2026-04-09

## WorkQueue.put() had inverted signal condition (pre-existing bug)
`put()` signaled `notEmpty` when `c != 0` (queue already non-empty) instead of `c == 0` (queue was empty, now has an item). This meant `take()` could hang forever when put() was the only method adding to an empty queue. Fixed to `c == 0` matching the pattern in `add()`. The bug was latent because `addWorks()` (the primary entry point) signals correctly.
Observed: 2026-04-09

## NodeType.isDetection() centralizes detection node classification
Detection nodes (FIXED_THRESHOLD, RELATIVE_DIFFERENCE) are identified by `NodeType.isDetection()` rather than open-coded enum comparisons. Adding a new detection node type only requires updating the enum method, not hunting for filter sites across FolderService/CLI.
Observed: 2026-04-09

## sqlpath/sqlpathall silently delete no-match values
When SQL jsonpath queries return null or empty arrays, the created ValueEntity is deleted (NodeService.java calculateSqlJsonpathValuesFirstOrAll). Horreum instead keeps null values so users can identify missing iterations. h5m's approach is acceptable for now but may need revisiting.
Observed: 2026-04-07

## jjq serializes integer-valued doubles without decimal suffix
The jjq library (io.hyperfoil.tools:jjq-jackson, which replaced jackson-jq in commit 862dd34) formats numbers like 20.0 as `20` (no `.0` suffix) in JSON output. jackson-jq preserved the decimal (`20.0`). This affects any test or assertion that string-matches on jq-extracted numeric values. FixedThreshold violation values (built via ObjectMapper's DoubleNode) still use `20.0` format since they bypass jq.
Observed: 2026-04-13

## WorkQueueExecutor must be @Singleton, not @Dependent
The CDI producer in ExecutorConfiguration.java was originally `@Dependent`, creating a separate WorkQueueExecutor (with its own WorkQueue) per injection point. WorkService and tests operated on different queues — work added by one was invisible to the other. Changed to `@Singleton`. Cannot use `@ApplicationScoped` because WorkQueueExecutor extends ThreadPoolExecutor which has no no-args constructor (required for CDI proxy).
Observed: 2026-04-13

## WorkService.create() must defer queue insertion until transaction commits
Work entities persisted via em.merge()+em.flush() inside a @Transactional method are not visible to other transactions until the outer transaction commits. Immediately adding them to the in-memory WorkQueue allows worker threads to pick them up before the DB row is visible, causing StaleObjectStateException. Fix: JTA Synchronization.afterCompletion(STATUS_COMMITTED) defers queue insertion. See issue #50.
Observed: 2026-04-13

## CascadeType.MERGE on Work's ManyToMany causes StaleObjectStateException
Work entity had `cascade = {CascadeType.PERSIST, CascadeType.MERGE}` on sourceValues and sourceNodes. When em.merge() was used in execute(), the cascade attempted to merge related ValueEntity/NodeEntity instances, triggering dirty-checking across detached entities from different transactions. Removing CascadeType.MERGE (keeping only PERSIST) and switching execute() to use em.find() resolved the issue.
Observed: 2026-04-13

## Use io.quarkus.logging.Log instead of SLF4J
Quarkus recommends its static `io.quarkus.logging.Log` API (or `org.jboss.logging.Logger`). SLF4J works but adds an unnecessary abstraction layer since Quarkus routes everything through JBoss Logging internally. `Log` requires no field declaration — just `Log.infof("message %s", arg)` with printf-style formatting.
Observed: 2026-04-13

## calculateSourceValuePermutations returns null for mismatched multi-source nodes
NodeService.calculateSourceValuePermutations() (line 227) returns null in the Length case when source value counts don't match across sources. This causes NPE when processing fan-in nodes (e.g., a "dataset" node depending on 3 first-tier nodes). Pre-existing bug — not yet fixed.
Observed: 2026-04-13
