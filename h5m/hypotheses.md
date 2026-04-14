## Edge table performance may degrade at Horreum scale for diamond topologies
DB-backed benchmarks show flat/chain insertion scales linearly to 2000 nodes with no degradation. Diamond topologies (where each node depends on all nodes in previous layer) show quadratic edge growth: 8x20 produces 2820 edges for 161 nodes (ratio 17.5). After optimizations (batch size 100, parent_id index, KahnDagSort short-circuit), diamond 8x20 costs ~2.5ms/node on PostgreSQL (407ms total) vs ~17.6ms/node on SQLite (2840ms total). Flat/chain remain ~2ms/node on both. For Horreum's typical label DAGs (shallow, mostly flat with some dependencies), performance is acceptable. Deep, wide diamond graphs (500+ labels all interconnected) could still hit issues on SQLite but PostgreSQL handles them well.
Status: partially confirmed
Confirmations: 3 (SQLite benchmark, PostgreSQL benchmark, performance optimizations applied and verified via JMH)
First observed: 2026-04-07
Last tested: 2026-04-09

## Delete cascade with shared children requires parent-count checking
Naive recursive delete cascades through all dependents, destroying shared children that have other parents. The fix (PR #44) computes parent counts upfront in the edge tables (node_edge, value_edge) and only cascades when parentCount <= 1. For value deletion, native SQL deletes are required (Panache delete fails on CTE-fetched entities). deleteDescendantValues and purge use EdgeQueries to clean both sides of value_edge before native DELETE. Tests confirm shared children survive when one parent is removed.
Status: confirmed
Confirmations: 3 (delete_does_not_cascade_to_shared_child, deleteDescendantValues_preserves_shared_descendants, purge_removes_subtree_preserves_external)
First observed: 2026-04-09
Last tested: 2026-04-09
