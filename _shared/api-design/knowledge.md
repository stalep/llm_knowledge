## JPA bidirectional relationships cause REST serialization cycles
@ManyToOne / @OneToMany bidirectional JPA relationships and @ManyToMany self-referencing join tables produce infinite recursion in Jackson serialization. @JsonBackReference only works on the entity layer; if API records/DTOs mirror the entity graph, the cycle reappears. Use flat DTOs with ID-based references for REST responses.
Observed: 2026-04-07

## JAX-RS method overloading requires distinct paths
JAX-RS (RESTEasy Reactive) does not allow two methods with the same HTTP verb + path even if they have different parameter signatures. Use distinct @Path values or consolidate with optional @QueryParam parameters.
Observed: 2026-04-07

## quarkus-rest-jackson + Hibernate ORM format mapper conflict
Adding quarkus-rest-jackson triggers Hibernate's BuiltinFormatMapperBehaviour check. Fix with `quarkus.hibernate-orm.mapping.format.global=ignore`.
Observed: 2026-04-07
