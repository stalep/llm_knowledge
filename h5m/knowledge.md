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

## WorkCompletionService replaces WorkQueue-internal RootValueTracker
Per-root-value work completion tracking was moved from WorkQueue (non-CDI, using Condition.await on takeLock) to a dedicated WorkCompletionService (@ApplicationScoped CDI bean) using ConcurrentHashMap + AtomicInteger + CompletableFuture. This separation decouples completion tracking from dependency ordering (which stays in WorkQueue). Worker threads never block — only the CLI thread blocks via CompletableFuture.get(). The CDI event WorkCompletedEvent fires on completion, enabling future SSE/WebSocket frontends. Key ordering invariant: trackWork() is called in WorkService.create() before work enters the queue; workCompleted() is called in WorkService.execute()'s finally block after cascade create and decrement. Known issues: (1) non-atomic complete+remove allows stale tracker race, (2) `<= 0` check is fragile if retries are enabled, (3) CascadeType.MERGE still present on Work entity ManyToMany despite being a known source of StaleObjectStateException.
Observed: 2026-04-15

## WorkQueue.put() had inverted signal condition (pre-existing bug)
`put()` signaled `notEmpty` when `c != 0` (queue already non-empty) instead of `c == 0` (queue was empty, now has an item). This meant `take()` could hang forever when put() was the only method adding to an empty queue. Fixed to `c == 0` matching the pattern in `add()`. The bug was latent because `addWorks()` (the primary entry point) signals correctly.
Observed: 2026-04-09

## NodeType.isDetection() centralizes detection node classification
Detection nodes (FIXED_THRESHOLD, RELATIVE_DIFFERENCE) are identified by `NodeType.isDetection()` rather than open-coded enum comparisons. Adding a new detection node type only requires updating the enum method, not hunting for filter sites across FolderService/CLI.
Observed: 2026-04-09

## sqlpath/sqlpathall silently delete no-match values
When SQL jsonpath queries return null or empty arrays, the created ValueEntity is deleted (NodeService.java calculateSqlJsonpathValuesFirstOrAll). Horreum instead keeps null values so users can identify missing iterations. PR #81 (issue_80 branch) changes this to SELECT-first: the jsonpath result is computed via SELECT before creating the ValueEntity, so null results never get inserted. For PostgreSQL, sibling sql/sqlall nodes sharing the same source are batched into a single query using VALUES + CASE, reducing ~82 individual queries to 2 batched queries. Benchmark: 24.5% faster on the qvss perf test (47.1s → 35.5s for 100 uploads).
Observed: 2026-04-07
Updated: 2026-05-05

## jjq serializes integer-valued doubles without decimal suffix
The jjq library (io.hyperfoil.tools:jjq-jackson, which replaced jackson-jq in commit 862dd34) formats numbers like 20.0 as `20` (no `.0` suffix) in JSON output. jackson-jq preserved the decimal (`20.0`). This affects any test or assertion that string-matches on jq-extracted numeric values. FixedThreshold violation values (built via ObjectMapper's DoubleNode) still use `20.0` format since they bypass jq.
Observed: 2026-04-13

## WorkQueueExecutor must be @Singleton, not @Dependent
The CDI producer in ExecutorConfiguration.java was originally `@Dependent`, creating a separate WorkQueueExecutor (with its own WorkQueue) per injection point. WorkService and tests operated on different queues — work added by one was invisible to the other. Changed to `@Singleton`. Cannot use `@ApplicationScoped` because WorkQueueExecutor extends ThreadPoolExecutor which has no no-args constructor (required for CDI proxy).
Observed: 2026-04-13

## WorkService.create() must defer queue insertion until transaction commits
Work entities persisted via em.merge()+em.flush() inside a @Transactional method are not visible to other transactions until the outer transaction commits. Immediately adding them to the in-memory WorkQueue allows worker threads to pick them up before the DB row is visible, causing StaleObjectStateException. Fix: JTA Synchronization.afterCompletion(STATUS_COMMITTED) defers queue insertion. REQUIRES_NEW doesn't work because: (a) sourceValues created in the caller's transaction are not committed/visible when the new tx tries to merge them, and (b) CDI self-invocation in execute() for cascade work bypasses interceptors, so REQUIRES_NEW wouldn't fire anyway. afterCompletion avoids both problems by joining the caller's transaction for persist and only deferring the queue insertion. create() is called from FolderService.upload(), FolderService.recalculate(), and self-invoked from WorkService.execute() for cascade work — all three paths must be considered for transaction boundary changes. See issue #50.
Observed: 2026-04-13
Updated: 2026-04-16

## CascadeType.MERGE on Work's ManyToMany causes StaleObjectStateException
Work entity had `cascade = {CascadeType.PERSIST, CascadeType.MERGE}` on sourceValues and sourceNodes. When em.merge() was used in execute(), the cascade attempted to merge related ValueEntity/NodeEntity instances, triggering dirty-checking across detached entities from different transactions. Removing CascadeType.MERGE (keeping only PERSIST) and switching execute() to use em.find() resolved the issue.
Observed: 2026-04-13

## Use io.quarkus.logging.Log instead of SLF4J
Quarkus recommends its static `io.quarkus.logging.Log` API (or `org.jboss.logging.Logger`). SLF4J works but adds an unnecessary abstraction layer since Quarkus routes everything through JBoss Logging internally. `Log` requires no field declaration — just `Log.infof("message %s", arg)` with printf-style formatting.
Observed: 2026-04-13

## calculateSourceValuePermutations returns null for mismatched multi-source nodes
NodeService.calculateSourceValuePermutations() (line 227) returns null in the Length case when source value counts don't match across sources. This causes NPE when processing fan-in nodes (e.g., a "dataset" node depending on 3 first-tier nodes). Pre-existing bug — not yet fixed.
Observed: 2026-04-13

## afterCompletion callbacks run outside the Hibernate session
JTA Synchronization.afterCompletion() runs after the transaction commits and the Hibernate session closes. Any lazy proxies on entities accessed inside the callback will throw LazyInitializationException. Fix: eagerly initialize all fields that the callback will touch while still inside the @Transactional method. For WorkQueue.sort() → Work.dependsOn(), this means: Hibernate.initialize(sv.node), Hibernate.initialize(sv.sources), and NodeEntity.initializeAncestorCache() (which pre-computes the ancestor ID set so dependsOn() never traverses lazy sources). The dependsOn(self) call in NodeEntity triggers computeAncestorIds() which traverses the full graph and initializes all needed lazy collections recursively.
Observed: 2026-04-16

## em.merge() does not make the parameter managed
em.merge(w) returns a NEW managed copy; the original parameter `w` stays detached with potentially uninitialized lazy proxies. Code in finally blocks that needs entity data must extract it from the merged `work` copy (inside the try) into local variables, not access `w` directly. Example: getRootValueId() on detached `w` throws LazyInitializationException for Work loaded from DB on restart (onStart path).
Observed: 2026-04-16

## Retry re-queue must happen on rollback too
When a @Transactional execute() catches an exception, persists retryCount, and defers retry re-queue via afterCompletion — if the transaction rolls back, the retryCount update is lost AND the work isn't re-queued (only STATUS_COMMITTED was handled). The work gets stuck in DB until process restart. Fix: re-queue on rollback too, since DB state wasn't advanced. The in-memory retryCount on the Work parameter still tracks attempts.
Observed: 2026-04-16

## Security model: config-driven AuthorizationService as single checkpoint
h5m uses a single AuthorizationService bean with `h5m.security.enabled` (default false). In local mode all checks pass (including null username). In service mode: admin role grants all access, team membership is checked via JPQL existence query (not collection loading), folders with no team are unrestricted. This replaces Horreum's 5-layer model (filter + augmentor + interceptor + annotation + 33 RLS policies). Phase 1 (PR #52) covers entities/services/CLI. Phase 2 (issue #57) adds OIDC + API key authentication + REST security annotations.
Observed: 2026-04-17
Updated: 2026-04-25

## @Authenticated requires an identity even when h5m.security.enabled=false
Adding `@Authenticated` to REST endpoints blocks all unauthenticated requests — including local mode where security is disabled. The ApiKeyAuthenticationMechanism must return a synthetic "local admin" SecurityIdentity (with admin+user roles) when `h5m.security.enabled=false`, so `@Authenticated` and `@RolesAllowed` pass without requiring real credentials. Without this, all existing tests break with 401.
Observed: 2026-04-25

## ApiKey.user must be EAGER for cross-transaction use
ApiKey.user was originally LAZY, but `ApiKeyService.validateKey()` returns the `User` entity to be used after the transaction closes (in the identity provider). Accessing the lazy proxy outside the session throws LazyInitializationException. Changed to EAGER — API key lookups always need the associated user. Horreum's `UserApiKey.user` is also EAGER.
Observed: 2026-04-25

## @TestProfile with QuarkusTestProfile for config overrides in tests
Use `@TestProfile(SecurityEnabledProfile.class)` to override config properties per test class. The profile class implements `QuarkusTestProfile.getConfigOverrides()` returning a Map. This allows testing security-enabled behavior while keeping all existing tests running with security disabled (via application-test.properties).
Observed: 2026-04-17

## Avoid PostgreSQL reserved words as JPA entity names
"user" is a reserved word in PostgreSQL. Use `@Entity(name = "h5m_user")` to avoid conflicts. The entity class can still be named `User` — only the JPA entity/table name needs to be different.
Observed: 2026-04-17

## DetectionNode interface provides shared contract for change detection algorithms
FixedThreshold and RelativeDifference both implement DetectionNode (getFingerprintNode, getGroupByNode, getRangeNode, getFingerprintFilter). The `groupBy` node (set via the `by` CLI parameter) serves as both the scoping boundary and the result attachment point. Users must specify `by` explicitly for dataset split scenarios — without it, `groupBy` defaults to root and fingerprint-to-range matching crosses split boundaries. An earlier `findScopingNode` method that auto-inferred scoping from the DAG was removed per team consensus that it made assumptions not part of the model's constraints.
Observed: 2026-04-19
Updated: 2026-04-21

## Removing --enable-preview from surefire causes cascading test failures on Java 21
The `--enable-preview` flag in pom.xml's surefire `<argLine>` is required for CI (Java 21). Removing it causes Quarkus/Arjuna transaction errors (`ARJUNA016051: thread is already associated with a transaction!`) across all @QuarkusTest classes, even though the code compiles fine without it. The errors appear unrelated to preview features — they manifest as transaction failures, not class loading errors. The `--enable-preview` removal should be paired with a CI Java version upgrade.
Observed: 2026-04-21

## Horreum transformer/label name collisions require de-duplication during import
Horreum tests may have transformer extractors and target schema labels with the same name (e.g., `tag`, `testName`). In h5m's flattened node tree, both become nodes — creating ambiguity when fingerprint lookup matches by name. The correct resolution is to remove the extractor-created node when the target schema label is encountered, since the label represents the final computed value. Papering over the ambiguity (e.g., picking last match) leaves the duplicate node in the graph and produces incorrect results.
Observed: 2026-04-21

## Horreum tests with multiple transformers sharing the same target schema
Some Horreum tests (e.g., keycloak-benchmark, rhivos-perf-comprehensive) have multiple transformers that target the same output schema but handle different source schema versions (e.g., `$.autobench_workload[*].results` vs `$.autobench_workload.data[*].results`). In Horreum, both transformers run independently and only the matching one produces output. The h5m import merges extractors from all transformers: shared extractors with different paths get a primary node, an `_alt` node, and a JS coalesce node `(primary, alt) => primary != null ? primary : alt`. Extractors unique to one transformer (e.g., `autoware_pcp_ts`) are skipped, and the function from the transformer whose parameters are all shared is used.
Observed: 2026-04-21
Updated: 2026-04-28

## Hibernate cascade persist reorders @OrderColumn indices
Hibernate's cascade persist assigns `@OrderColumn` values based on entity ID order, not Java List insertion order. The `setNodes()` method on `FixedThreshold` and `RelativeDifference` sets the sources list directly. The getters (`getFingerprintNode`, `getGroupByNode`, `getRangeNode`) use positional access (`sources.get(0/1/2)`) with no bounds checking or config JSON fallback — they will throw `IndexOutOfBoundsException` if the sources list is shorter than expected. Note: `order-inserts=true` was investigated but is NOT the cause — the reordering happens during cascade persist regardless.
Observed: 2026-04-28
Updated: 2026-05-05

## Legacy import: coalesced transformers with JQ combiner nodes
h5m's legacy import creates both transformer nodes, coalesces them at the transformer level (before the JQ `.[]` split) so the permutation logic handles empty sources correctly, then creates a single dataset node. For multi-extractor single-param labels (e.g., Autobench with `workload` and `results` extractors), a JQ combiner node builds the combined object in one expression instead of using separate extractor nodes that produce mismatched value counts. PostgreSQL jsonpath filter expressions (`? (@.field == "value")`) are converted to JQ `select()`. No-transform path deduplicates coalesce sources and adds variant label nodes to the group to avoid NodeEntity.equals dedup issues.
Observed: 2026-04-28
Updated: 2026-05-05

## Horreum label functions assume numeric types but JSON stores numbers as strings
Many Horreum label functions (e.g., `value => value.reduce((a,b) => a+b)`) assume numeric inputs, but some run data stores numbers as JSON strings ("759660"). The fix belongs at the node operation level during import — wrapping the JS function to coerce string-encoded numbers — not in h5m's generic JS evaluation engine. The `wrapWithNumberCoercion()` approach prepends `param = typeof param === "string" && !isNaN(param) ? Number(param) : param;` for each function parameter.
Observed: 2026-04-21

## Horreum Util.java handles string-to-number coercion in three distinct places
Verified by inspecting Hyperfoil/Horreum `horreum-backend/src/main/java/io/hyperfoil/tools/horreum/svc/Util.java`:
1. **`toDoubleOrNull(Value value, ...)`** (lines 115-143): GraalVM polyglot Value overload — checks `value.isString()` and calls `Double.parseDouble(value.asString())`. Used when JS combination functions return string-encoded numbers.
2. **`toDoubleOrNull(Object value)`** (lines 145-169): Object overload — strips surrounding quotes from strings (`"123"` -> `123`), then calls `Double.parseDouble()`. Also handles Long/Integer/Float/Short. Used by ReportServiceImpl.
3. **AlertingServiceImpl.java** (lines 493-500): Inline in the `nonFuncResultConsumer` lambda — checks `data.value.isTextual()` and calls `Double.parseDouble(data.value.asText())` to coerce JSON text nodes to doubles for datapoint creation.
All three are at the *consumption* layer (when turning values into datapoints/reports), not during label evaluation. Horreum does NOT coerce string-encoded numbers during JS function *input* — the label functions receive the raw JSON types. This confirms h5m's `wrapWithNumberCoercion()` approach (coercing at function input time) goes beyond what Horreum did.
Observed: 2026-04-22

## Picocli Callable.call() runs outside CDI request/transaction context
Quarkus CLI commands using Picocli's `Callable<Integer>` run outside the CDI request scope. Calling `entity.persist()` (Panache) directly throws `ContextNotActiveException`. Fix: inject a CDI service bean with `@Transactional` methods and call through that instead.
Observed: 2026-04-21

## Horreum transformer .[] splits objects by key, not as single dataset
Horreum treats non-array transformer output as a single dataset. Using jq `.[]` on an object iterates its *values* (one per key), not its elements. For example, `{info: {...}, stats: [...]}` produces two items (the info object and the stats array) instead of one dataset. The correct jq expression is `if type == "array" then .[] else . end`.
Observed: 2026-04-22

## value_edge(parent_id) index is critical for recursive CTE performance
The recursive CTE in `getDescendantValues` joins on `parent_id`, but only `child_id` is indexed by default (JPA generates indexes for the owning side). Adding `CREATE INDEX idx_value_edge_parent_id ON value_edge(parent_id)` gives 2.4x speedup. Similarly, `value(node_id)` and `value(folder_id)` should be indexed.
Observed: 2026-04-22

## Work queue thread pool contention dominates at high thread counts
50 concurrent threads all running recursive CTEs cause massive PostgreSQL contention — reducing to 5 threads gives 10x speedup for bulk imports. At low thread counts (1 vs 5), there's no measurable difference, indicating the bottleneck shifts from contention to per-item processing time. Optimal pool size depends on workload: high for independent simple queries, low for recursive/complex queries.
Observed: 2026-04-22

## Horreum multi-extractor labels pass named-property objects to single-param functions
When a Horreum label has multiple extractors and a function with a single parameter (e.g., `value => { value["workload"]... }`), Horreum passes an object where each key is the extractor name. h5m's `createNodesFromLabel` fallback for single-param functions collects all sources but doesn't construct a named-property object, so labels like Autobench that access `value["workload"]` produce 0 values.
Observed: 2026-04-22

## PostgreSQL cursor-based fetching requires autoCommit=false
PostgreSQL JDBC driver ignores `setFetchSize()` unless `connection.setAutoCommit(false)` is set. Without both, all rows are buffered in memory. This caused OOM when loading 1,327 large JSON run records in LoadLegacyRuns.
Observed: 2026-04-22

## h5m runs change detection per-upload, producing cumulative detections
Unlike Horreum which can batch process, h5m's `calculateRelativeDifferenceValues` runs after each upload via the work queue. With 3 uploads of trending data (window=1, minPrevious=1), the 2nd upload detects changes at the highest domain values (enough history), and the 3rd upload detects at the next-highest. This produces 4 total detections instead of the 2 a one-shot analysis would find. This is expected behavior, not a bug.
Observed: 2026-04-19

## NodeEntity.equals treats all unpersisted nodes with same name/operation as equal
When `id == null`, `NodeEntity.equals()` compares source IDs one level deep — but unpersisted sources also have `null` IDs, so `Objects.equals(null, null)` returns true. This makes `NodeGroupEntity.addNode()` (which uses `List.contains()`) silently reject legitimately distinct nodes that have the same name and operation but different sources. Affects any code path that creates multiple nodes with the same structure but different source contexts (e.g., per-dataset label nodes in multi-transformer import).
Observed: 2026-05-01

## Multi-transformer import: coalesce at transformer level, not dataset level
When coalescing multi-transformer outputs, coalesce BEFORE the jq split (at transformer level), not after (at dataset level). Transformer nodes produce 0 or 1 values — `calculateSourceValuePermutations` handles this via the simple case (`maxNodeValuesLength == 1`). Dataset nodes produce N values after jq `.[]` split — mismatched counts between sources trigger the Length case which returns null.
Observed: 2026-05-01

## Test suite does not verify cross-transaction value persistence
The H5mTest CLI tests verify value counts via `list value` output, but run in-process where the work queue completes synchronously. They don't catch persistence-context changes (em.detach, em.clear) that break value visibility across transactions. Both em.clear() and selective em.detach() passed all 222 tests while producing 0 persisted values at runtime. Any optimization touching the Hibernate persistence context needs an integration test that uploads data, then queries the DB in a separate transaction to verify values exist.
Observed: 2026-05-07

## Hibernate JSON column dirty-checking is 27% of upload CPU
After Will's work queue optimizations (getTopLevelNodes, streaming), Hibernate dirty-checking became the dominant bottleneck at 27%. The `FormatMapperBasedJavaType.deepCopy` deserializes and re-serializes the JSON `data` column on every flush to compare with the snapshot. Selective em.detach() of computed values after flush gives ~13% speedup but needs proper test coverage before it can be safely applied.
Observed: 2026-05-07

## ValueService.create() detach-after-flush gives 20% CPU reduction
Detaching the merged ValueEntity immediately after em.merge()+em.flush() in ValueService.create() and returning the original transient object (which already has all fields populated including the id copied from merged.id) reduces total CPU samples by 20% on a 5-run rhivos-perf-comprehensive import. Dirty-checking samples dropped 42% (6087→3522). The key insight: em.merge() returns a new managed copy while the original parameter stays detached — returning the original avoids LazyInitializationException since its fields were set by the caller. Combined with a native UPDATE for the existingValue.data mutation case in WorkService.execute() (replacing reliance on Hibernate dirty-detection at commit time), all 222 tests pass. Attempting to also detach entities loaded by getDescendantValuesByNodes() fails because ValueEntity.getPath() recursively traverses the lazy `sources` collection — detaching breaks the proxy chain. Removing CascadeType.MERGE from ValueEntity.sources would be needed to fully detach query results, but causes 16 test failures due to cascade behavior changes. The remaining dirty-checking hotspot is calculateSqlJsonpathValuesFirstOrAll (71% of remaining dirty-check samples) where session.doWork() triggers auto-flush on accumulated managed entities from earlier queries.
Observed: 2026-05-11

## Horreum has two separate notification/action systems
Horreum's outbound messaging has two distinct subsystems: (1) **Notifications** — per-user/per-team subscription-based alerts for change detection, missing data, missing values, expected runs, and API key expiration. Uses `NotificationPlugin` SPI with CDI `Instance<NotificationPlugin>` discovery. Only `EmailPlugin` ships by default. Configured via `Watch` (who subscribes per test) + `NotificationSettings` (how each user/team wants to be notified). (2) **Actions** — per-test webhook-style integrations triggered by `ActionEvent` enum events (test/new, run/new, change/new, experiment_result/new, dataset_labels/computed). Uses `ActionPlugin` SPI with 4 implementations: `HttpAction`, `SlackChannelMessageAction`, `GitHubIssueCreateAction`, `GitHubIssueCommentAction`. Each Action stores config (JSON) + secrets (JSON) + event type. The two systems connect via `ServiceMediator`: change detection in `AlertingServiceImpl` fires `Change.Event` → `ServiceMediator.newChange()` → both `ActionServiceImpl.onNewChange()` (actions) and `EventAggregator.onNewChange()` (aggregates changes per dataset, then after 1s delay → `ServiceMediator.newDatasetChanges()` → `NotificationServiceImpl.onNewChanges()`). The `notificationsEnabled` boolean on `Test` controls whether notifications fire. For h5m's simpler needs, a single plugin SPI combining both patterns would suffice.
Observed: 2026-05-13
