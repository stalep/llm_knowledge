## Always check parent count before cascade-deleting in edge tables
When deleting a node/value that participates in edge tables (value_edge, node_edge), check if dependents have other parents before cascade-deleting. Use batch query `SELECT child_id, COUNT(*) FROM *_edge WHERE child_id IN (:ids) GROUP BY child_id` to avoid N+1.
Promoted from hypothesis: 2026-04-07
Confirmations: 3 (issue #5 fix, tests, code review)

## Clean up inverse-side edge rows before entity deletion
Before deleting a ValueEntity or NodeEntity, execute `DELETE FROM *_edge WHERE parent_id = :id` to remove inverse-side join table rows that JPA won't clean up automatically.
Promoted from hypothesis: 2026-04-07
Confirmations: 3 (issue #5 fix, tests, code review)

## Never serialize entity object graphs directly to REST responses
Bidirectional relationships (Node->NodeGroup->List<Node>) and @ManyToMany closure tables cause StackOverflow in JSON serialization even when @JsonBackReference is used on entities. Always use flat DTOs with ID-based references for REST endpoints. CycleAvoidingContext in MapStruct prevents cycles during mapping but doesn't help when Jackson serializes the resulting API records.
Promoted from hypothesis: 2026-04-07
Confirmations: 3 (RestEndpointTest StackOverflow, RestAssured Groovy parser crash, OpenAPI spec $ref cycle)
