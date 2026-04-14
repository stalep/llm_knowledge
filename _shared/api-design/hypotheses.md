## Prefer interface default methods over trivial implementation classes
When a Java interface has multiple implementations where most just do an identity pass-through (e.g., provider/strategy patterns), moving the identity logic to a `default` method on the interface eliminates boilerplate classes. Callers instantiate with `new Interface() {}`. Confirmed in aesh (5 provider classes removed), needs confirmation in other projects.
Status: unconfirmed
Confirmations: 1
First observed: 2026-04-13
Last tested: 2026-04-13

## Fix raw generic types at the source rather than suppressing warnings
When `@SuppressWarnings("unchecked")` is needed on a class, the root cause is often a raw type in a parent class or interface implementation (e.g., `implements Foo` instead of `implements Foo<T>`). Fixing the declaration eliminates warnings across all dependent code. Confirmed in aesh SettingsImpl, needs confirmation elsewhere.
Status: unconfirmed
Confirmations: 1
First observed: 2026-04-13
Last tested: 2026-04-13

## Flat DTOs with ID references outperform nested DTOs for frontend consumption
Frontend frameworks (React, etc.) typically normalize data into stores keyed by ID. Serving flat DTOs with ID references aligns with this pattern and avoids the frontend having to de-duplicate nested objects. Needs confirmation across multiple frontend integrations.
Status: unconfirmed
Confirmations: 0
First observed: 2026-04-07
Last tested: 2026-04-07
