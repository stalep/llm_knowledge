## Legacy Migration: Container Setup

### Horreum Database Container (port 6000)

The backup is at `~/git/backup_horreum/archive-primary-20260312060001-pii-purged.tar.zst` (15GB compressed, 42GB extracted).

**Extract** (only needed once):
```bash
tar --zstd -xf ~/git/backup_horreum/archive-primary-20260312060001-pii-purged.tar.zst -C ~/git/backup_horreum/
```

The PostgreSQL data directory ends up at `~/git/backup_horreum/archive-primary-20260312060001/primary-20260312060001/`.

**Important:** The backup's `postgresql.conf` has `port = 6000` baked in, so the container's internal PostgreSQL listens on 6000, not the default 5432. The port mapping must be `6000:6000`.

**Start:**
```bash
podman run -d --name hdb \
  -v ~/git/backup_horreum/archive-primary-20260312060001/primary-20260312060001:/var/lib/postgresql/data:rw,Z \
  -e POSTGRES_DB=horreum \
  -e PGDATABASE=horreum \
  -e POSTGRES_USER=horreum-user \
  -e PGUSER=horreum-user \
  -p 6000:6000 \
  mirror.gcr.io/library/postgres:16
```

**Set password** (needed after first start — uses Unix socket with trust auth):
```bash
podman exec hdb psql -p 6000 -U horreum-user -d horreum -c "ALTER USER \"horreum-user\" WITH PASSWORD 'horreum';"
```

**Grant permissions** (horreum-user needs superuser to create functions/tables):
```bash
podman exec hdb psql -p 6000 -U postgres -d horreum -c "GRANT ALL ON SCHEMA public TO \"horreum-user\"; ALTER USER \"horreum-user\" WITH SUPERUSER;"
```

**Stop/restart:**
```bash
podman stop hdb
podman start hdb
```

After restart, the password and permissions persist (stored in pgdata).

### h5m Database Container (port 5432)

**Start:**
```bash
podman run -d --name h5m-legacy \
  -e POSTGRES_DB=quarkus \
  -e POSTGRES_USER=quarkus \
  -e POSTGRES_PASSWORD=quarkus \
  -p 5432:5432 \
  mirror.gcr.io/library/postgres:17
```

**Stop/restart:**
```bash
podman stop h5m-legacy
podman start h5m-legacy
```

### h5m Configuration

`.env` file in project root:
```
h5m.work.maximumPoolSize=50
quarkus.datasource.jdbc.url=jdbc:postgresql://0.0.0.0:5432/quarkus
quarkus.datasource.username=quarkus
quarkus.datasource.password=quarkus
```

`application.properties` must have `quarkus.datasource.db-kind=postgresql` (set on legacy_tests branch).

### Running the Migration

Build (JVM mode — faster build, better runtime than native):
```bash
mvn clean package -DskipTests
```

Load tests (creates folders + node trees; first run creates reference tables which takes several minutes):
```bash
java -jar target/h5m-0.1.0-SNAPSHOT.jar load-legacy-tests username=horreum-user password=horreum url=jdbc:postgresql://0.0.0.0:6000/horreum
```

Load runs (one test at a time to avoid overwhelming the work queue):
```bash
java -jar target/h5m-0.1.0-SNAPSHOT.jar load-legacy-runs testId=12 username=horreum-user password=horreum url=jdbc:postgresql://0.0.0.0:6000/horreum
```

### Known Issues Found During Testing
- `LoadLegacyTests` did not initialize `folder.group` — fixed locally by adding `folder.group = new NodeGroupEntity(test.name)` after line 340
- `FolderEntity.persist()` called without transaction context — fixed by adding `FolderService.create(FolderEntity)` method and using `folderService.create(folder)` instead
- Collation version mismatch warnings are harmless (backup was created with glibc 2.36, container has 2.41)
- 162 Horreum tests → 176 folders created (some tests have multiple schema paths)
- 37 tests had fingerprint creation failures (missing/mismatched parameter nodes)

Observed: 2026-04-21
