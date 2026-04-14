## CDI @Dependent scope on producer methods creates separate instances per injection point
A `@Produces @Dependent` method returns a new instance for every `@Inject` site. For shared infrastructure like thread pools or work queues, this means each service gets its own isolated instance — work added by one service is invisible to another. Use `@Singleton` (not `@ApplicationScoped`, which requires a no-args constructor for the CDI proxy) for classes that extend framework types like `ThreadPoolExecutor`.
Observed: 2026-04-13

## JTA Synchronization.afterCompletion() defers work until transaction commits
When persisting entities and then handing them to background workers, the workers may start before the creating transaction commits, causing StaleObjectStateException. Fix: register a `Synchronization` callback via `TransactionManager.getTransaction().registerSynchronization()` and queue work in `afterCompletion(STATUS_COMMITTED)`. The callback runs on the committing thread.
Observed: 2026-04-13

## em.find() vs em.merge() for loading detached entities in new transactions
`em.merge()` on a detached entity triggers dirty-checking and can cause StaleObjectStateException if the entity version doesn't match. `em.find(Class, id)` performs a simple SELECT and returns null if not found — safer when loading entities that were persisted in a different transaction.
Observed: 2026-04-13

## Thread.sleep() inside @Transactional holds DB connections
When a method is `@Transactional`, the interceptor wraps the entire method including catch/finally blocks. A `Thread.sleep()` in a catch block holds the DB connection for the sleep duration, risking connection pool exhaustion under concurrent failures.
Observed: 2026-04-13
