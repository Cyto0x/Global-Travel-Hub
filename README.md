# Global Travel Hub - Data Layer

Production-ready PostgreSQL schema for the AI travel platform.

---

## Files

| File | Purpose | Run Order |
|------|---------|-----------|
| `schema.sql` | Core database schema | 1 |
| `security.sql` | Roles, permissions, RLS | 2 |
| `seed_data.sql` | Development test data | 3 |
| `maintenance.sql` | Automated maintenance procedures | 4 (recurring) |
| `analytics_queries.sql` | Dashboard & BI queries | - |
| `DESIGN_DOCUMENT.md` | Architecture documentation | - |

---

## Quick Setup

```bash
# 1. Create database
createdb global_travel_hub

# 2. Run schema
psql -U postgres -d global_travel_hub -f schema.sql

# 3. Setup security
psql -U postgres -d global_travel_hub -f security.sql

# 4. Load test data (optional)
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

1. **Change default passwords** in `security.sql` before running
2. **Enable SSL** for all connections
3. **Setup pg_cron** or external scheduler for maintenance tasks
4. **Create read replica** for analytics queries
5. **Configure PgBouncer** for connection pooling
6. **Monitor partition sizes** and create future partitions in advance

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
WHERE relname IN ('users', 'chat_sessions', 'bookings');
```

### Cache performance
```sql
SELECT * FROM cache_performance;
```
