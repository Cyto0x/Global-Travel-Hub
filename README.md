# Global Travel Hub - Data Layer

Production-ready PostgreSQL schema for the AI travel platform.

---

## Files

| File | Purpose | Run Order |
|------|---------|-----------|
| `init.sql` | Core database schema | 1 |
| `init-security.sh` | Applies security.sql with env-injected role passwords | 2 |
| `security.sql` | Roles, permissions, RLS | 2 |
| `seed_data.sql` | Development test data | 3 |
| `maintenance.sql` | Automated maintenance procedures | 4 (recurring) |
| `analytics_queries.sql` | Dashboard & BI queries | - |
| `DESIGN_DOCUMENT.md` | Architecture documentation | - |
| `SECURITY_PROTOCOL.md` | Security baseline and controls | - |
| `SECURITY_GAP_REPORT.md` | Current security assessment | - |
| `SECURITY_ACTION_PLAN.md` | Prioritized hardening plan | - |
| `security_verification.sql` | SQL security checks | - |
| `scripts/security_smoke_test.sh` | One-command security validation | - |

---

## Quick Setup (Docker - Recommended)

```bash
# 1. Copy env template and set secure values
cp .env.example .env

# 2. Start services
docker compose up -d

# 3. Run security smoke test
./scripts/security_smoke_test.sh
```

## Quick Setup (Manual SQL)

```bash
# 1. Create database
createdb global_travel_hub

# 2. Run schema
psql -U postgres -d global_travel_hub -f init.sql

# 3. Setup security (requires psql vars for role passwords)
psql -U postgres -d global_travel_hub \
  -v gth_app_password='your_app_password' \
  -v gth_readonly_password='your_readonly_password' \
  -v gth_admin_password='your_admin_password' \
  -f security.sql

# 4. Load test data
psql -U postgres -d global_travel_hub -f seed_data.sql
```

---

## Maintenance Schedule

| Task | Frequency | Script/Command |
|------|-----------|----------------|
| Create partitions | Monthly | `maintenance.sql` - Partition section |
| Cache cleanup | Hourly | `CALL cleanup_expired_cache();` |
| GDPR purge | Daily | `CALL gdpr_purge_old_data();` |
| Statistics refresh | Daily | `ANALYZE` commands |
| Index maintenance | Weekly | `REINDEX INDEX CONCURRENTLY` |
| Vacuum | Weekly | `VACUUM ANALYZE` |

---

## Schema Overview

```
users
├── oauth_accounts
├── chat_sessions
│   └── chat_messages (partitioned monthly)
├── bookings
│   └── booking_items
│       ├── flight_bookings
│       └── hotel_bookings
├── flight_search_cache
├── hotel_search_cache
└── analytics_events (partitioned monthly)
```

---

## Connection Info

```
Database: global_travel_hub
Application User: gth_app
Read-only User: gth_readonly
Admin User: gth_admin
Direct PostgreSQL: localhost:5432
PgBouncer: localhost:6432
Redis: internal Docker network only (auth required)
```

---

## Key Features

- **UUID Primary Keys** - Distributed system ready
- **Table Partitioning** - Chat messages & analytics partitioned monthly
- **GDPR Compliant** - Soft deletes, consent tracking, data purge
- **Row-Level Security** - Multi-tenant ready
- **Hybrid Cache** - PostgreSQL + Redis support
- **LangGraph Integration** - Thread ID, checkpoint namespace

---

## Production Notes

1. **Use secure values in `.env`** (do not keep placeholders)
2. **Enable SSL** for all connections
3. **Setup pg_cron** or external scheduler for maintenance tasks
4. **Create read replica** for analytics queries
5. **Configure PgBouncer** for connection pooling
6. **Monitor partition sizes** and create future partitions in advance

## Security Verification

```bash
# Full smoke test (DB roles/RLS, Redis auth, PgBouncer path)
./scripts/security_smoke_test.sh

# SQL-only verification inside running postgres container
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 \
  -U ${POSTGRES_USER:-gth_user} \
  -d ${POSTGRES_DB:-global_travel_hub} \
  -f - < security_verification.sql
```

---

## Troubleshooting

### Check partitions
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name LIKE 'chat_messages_y%';
```

### Check RLS status
```sql
SELECT relname, relrowsecurity, relforcerowsecurity 
FROM pg_class 
WHERE relname IN ('users', 'chat_sessions', 'chat_messages', 'bookings', 'booking_items', 'oauth_accounts');
```

### Cache performance
```sql
SELECT * FROM cache_performance;
```
