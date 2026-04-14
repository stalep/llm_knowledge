## Worker thread pool should not exceed DB connection pool
With 50 worker threads and 10-20 DB connections, up to 30-40 threads can block waiting for connections, causing cascading timeouts. Aligning pool sizes (workers <= connections) or adding connection-wait timeouts prevents starvation.
Status: unconfirmed
Confirmations: 1 (h5m work queue race condition analysis)
First observed: 2026-04-13
Last tested: 2026-04-13
