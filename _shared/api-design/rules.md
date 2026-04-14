## Use flat DTOs for REST endpoints over JPA entity graphs
Never expose JPA entities or records mirroring entity relationships directly via REST. Use flat DTOs with ID-based references to avoid serialization cycles and decouple the API contract from the persistence model.
Promoted from hypothesis: 2026-04-07
Confirmations: 3 (h5m Node/NodeGroup StackOverflow, RestAssured parser crash, OpenAPI $ref cycle)
