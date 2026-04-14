## Horreum is a performance regression detection system
Horreum is a multi-service Quarkus application for tracking performance test results and detecting regressions. It uses a 6-entity linear pipeline: Run -> Transformer -> Dataset -> Label -> Variable -> ChangeDetection. h5m is its lightweight rewrite that collapses this into a single polymorphic DAG node.
Observed: 2026-04-13

## Pipeline: 6 entity types with event-driven flow
Data flows through distinct entity types connected by an AMQP event bus (AsyncEventChannels):
1. **RunDAO** - raw JSON upload (data stored as JSONB)
2. **TransformerDAO** - JSONPath extractors that create datasets from runs
3. **DatasetDAO** - structured data derived from runs via transformers
4. **LabelDAO** - named value extractors (jsonpath + optional JS combination function)
5. **VariableDAO** - time-series metric definitions referencing labels
6. **ChangeDetectionDAO** - per-variable detection config (model enum + config JSON)
Each stage publishes events (RUN_NEW, DATASET_NEW, DATAPOINT_NEW, etc.) consumed by the next service.
Observed: 2026-04-13

## Change detection uses identical algorithms to h5m
FixedThresholdModel and RelativeDifferenceChangeDetectionModel in `changedetection/` package implement the same logic as h5m's FixedThreshold and RelativeDifference nodes. Key difference: Horreum operates on DataPointDAO (extracted scalar doubles), while h5m operates directly on ValueEntity (JSONB). Horreum's config format nests min/max: `{"min": {"value": N, "enabled": bool, "inclusive": bool}}` vs h5m's flat `{"min": N, "minInclusive": bool}`.
Observed: 2026-04-13

## Fingerprinting uses hash-based lookup on a separate entity
FingerprintDAO has datasetId as PK, a fingerprint JSONB object, and an fpHash integer for fast equality checks. Created in DatasetServiceImpl.createFingerprint() by extracting TestDAO.fingerprintLabels values from the dataset, optionally filtering via JavaScript (TestDAO.fingerprintFilter). Change detection queries filter DataPoints by matching fingerprint hash to prevent cross-configuration comparisons. In h5m, fingerprinting is a first-class DAG node type (FingerprintNode) rather than a separate entity.
Observed: 2026-04-13

## Label extraction uses PostgreSQL jsonpath natively
Horreum extracts label values using PostgreSQL's `jsonb_path_query_first()` / `jsonb_path_query_array()` functions at the SQL level, not in Java. ExtractorDAO stores a jsonpath string that gets concatenated with a schema prefix and executed as a native query. Results are stored in a denormalized `label_values` table (dataset_id, label_id, value JSONB) with a unique constraint. h5m instead evaluates jq/JS/JSONata/SQL in Java via the NodeService.
Observed: 2026-04-13

## Schema validation adds significant complexity
SchemaDAO stores JSON Schema definitions. Runs are linked to schemas via `run_schemas` (populated by a PostgreSQL trigger that extracts `$."$schema"` from run.data). Transformers, labels, and extractors all reference schemas. Schema changes trigger cascading recomputation of datasets and label values. h5m intentionally dropped schemas - they added entity relationships and code paths without catching many real issues.
Observed: 2026-04-13

## Notification system with pluggable action plugins
WatchDAO tracks user/team subscriptions per test. NotificationServiceImpl dispatches to plugins: SlackChannelMessageAction, GitHubIssueCreateAction, GitHubIssueCommentAction, HttpAction. Events are batched via EventAggregator (1-second delay) to prevent notification spam. MissingDataRuleDAO handles alerts for absent expected data. h5m currently has no notification system - change detection results are returned via CLI exit code or REST API.
Observed: 2026-04-13

## Experiment profiles compare baseline vs selector datasets
ExperimentProfileDAO defines comparison experiments: selector labels/filter pick the "new" datasets, baseline labels/filter pick the reference datasets, and ExperimentComparisonDAO defines the comparison conditions. This feature does not yet exist in h5m.
Observed: 2026-04-13

## Key service sizes reflect complexity
RunServiceImpl: 1551 lines, AlertingServiceImpl: 1434 lines, DatasetServiceImpl: 686 lines. Compare to h5m's NodeService: 1197 lines (which handles all computation types). Total backend: ~164 Java files vs h5m's ~30. The complexity is distributed across more services but each service is also large.
Observed: 2026-04-13

## Row-level security enforced at PostgreSQL level
Horreum uses PostgreSQL RLS policies on tables like label_values and dataset_schemas. Combined with Keycloak OIDC authentication and @WithRoles annotation for transactional scope boundaries. User/Team/Role model in entity/user/. h5m has no authentication.
Observed: 2026-04-13

## Pluggable datastores for run data storage
Datastore interface with implementations: PostgresDatastore (default), ElasticsearchDatastore, CollectorApiDatastore. Allows storing raw run data in different backends while keeping metadata in PostgreSQL. h5m stores everything in a single database (SQLite/PostgreSQL/DuckDB).
Observed: 2026-04-13

## Database uses Liquibase migrations with PostgreSQL triggers
Schema managed by changeLog.xml with versioned migrations. PostgreSQL triggers auto-maintain denormalized tables (run_schemas populated on insert). No closure tables - uses direct FK relationships and join tables. h5m uses Hibernate auto-update (no migrations) and closure-style edge tables (node_edge, value_edge) for DAG relationships.
Observed: 2026-04-13
