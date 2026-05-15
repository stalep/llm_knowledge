## Multi-extractor single-param labels need JQ combiner nodes

When a Horreum label has multiple extractors but a single-param JS function (e.g., `value => { value["workload"]... }`), Horreum pairs all extractor results per-dataset into one object. In h5m, separate extractor nodes produce values independently — if extractor counts differ (e.g., `$.workload` matches all 10 datasets but `$.results.*.MultiCore` only matches autobench items), `calculateSourceValuePermutations` returns null in the Length case.

**Fix:** For multi-extractor single-param labels, create a single JQ combiner node that builds the combined object from all extractors in one expression: `{workload: (.workload // null), results: (try [.results[]?.MultiCore] catch null)}`. This produces one value per dataset item with all fields. The label JS function then has a single source and avoids the permutation mismatch.

**JQ error suppression:** Use `// null` for scalar extractors and `try [...] catch null` for array extractors (`isArray=true`) to handle datasets where the path doesn't exist.

**Related bug:** `NodeGroupEntity.addNode()` uses `List.contains()` which calls `NodeEntity.equals()`. For unpersisted nodes with null IDs, equals compares source IDs — but `null == null` makes all unpersisted nodes with the same name/operation/source-count appear equal. This silently drops per-dataset nodes that should be distinct. The JQ combiner approach avoids this by creating labels once against a single source.

Observed: 2026-05-01
