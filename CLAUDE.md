# CLAUDE.md — bixi-infra

Agent role: `AG-INFRA` — owns all infrastructure, database schema, and orchestration for the BIXI platform.

> Loaded in addition to the root `../CLAUDE.md`. Root file has system overview, phase strategy, and cross-repo rules.

---

## Scope

| Owns | Does not touch |
|---|---|
| `migrations/` — SQL schema files | Go application code (collector, API) |
| `docker-compose.yml` — TimescaleDB via nerdctl | ML feature engineering or training |
| `Makefile` — up / migrate / reset targets | Frontend |
| `terraform/` — AWS IaC | Business logic in any service |
| `scripts/` — backup, seed, maintenance scripts | |
| `config.yaml` — infra-level configuration | |

---

## Key Commands

```bash
make up        # Start TimescaleDB (requires Rancher Desktop / nerdctl running)
make migrate   # Apply pending migrations in order
make reset     # Wipe DB and re-migrate — DEV ONLY, never production
```

Database connection (dev): `postgres://bixi:bixi@localhost:5434/bixi`

---

## Migration Rules

- One migration file = one atomic schema change
- Never modify a migration that has already been applied — create a new numbered file
- Naming: `NNN_description.sql` (e.g. `002_add_events_table.sql`)
- Every table must include a `system_id` column — multi-city support is non-negotiable from day one
- New time-series tables must be converted to hypertables and have a retention policy applied

---

## What Not to Do

- **Never** `make reset` unless explicitly requested and confirmed to be dev environment
- **Never** drop or rename a column in `station_snapshots` — historical GBFS data is irreplaceable
- **Never** run Terraform commands directly — surface the command for the user to execute
- **Never** commit `.env` or any file containing credentials

---

## Known Pitfalls

### TimescaleDB on port 5434
System PostgreSQL occupies 5432. BIXI TimescaleDB runs on **5434**. Every psql/DATABASE_URL must specify port 5434 explicitly.

### nerdctl requires Rancher Desktop running
`make up` will fail silently if the Rancher Desktop VM is not started. Check with `nerdctl ps` before diagnosing anything else.
