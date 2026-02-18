# Global Travel Hub - Database Design Document

## Executive Summary

This document describes the production-ready PostgreSQL schema for the Global Travel Hub AI travel platform. The design prioritizes:

1. **High-write performance** for chat logs (partitioning strategy)
2. **Analytics optimization** for business intelligence
3. **GDPR compliance** with PII protection
4. **Future scalability** (multi-tenant ready)
5. **Developer ergonomics** (clean constraints, triggers, views)

---

## 1. Design Philosophy

### 1.1 MVP-First, Production-Ready

The schema avoids over-engineering while incorporating critical production features:
- UUID primary keys (distributed system ready)
- Soft deletes (data recovery, GDPR compliance)
- Partitioned tables for time-series data
- JSONB for flexible schema evolution

### 1.2 Separation of Concerns

| Layer | Tables | Purpose |
|-------|--------|---------|
| **Identity** | `users`, `oauth_accounts` | Authentication & profile |
| **Chat** | `chat_sessions`, `chat_messages` | AI conversation state |
| **Cache** | `flight_search_cache`, `hotel_search_cache` | External API optimization |
| **Booking** | `bookings`, `booking_items`, `flight_bookings`, `hotel_bookings` | Transaction management |
| **Analytics** | `analytics_events` | Business intelligence |

---

## 2. Key Design Decisions

### 2.1 UUID vs Auto-Increment

**Decision:** UUID primary keys

**Rationale:**
- Enables distributed writes without coordination
- Safe to expose in URLs/frontend without enumeration attacks
- Required for future microservices split
- Easier data migration between environments

**Trade-off:** 
- 16 bytes vs 4-8 bytes storage
- Slightly slower index performance (mitigated with proper indexing)

### 2.2 Table Partitioning for Chat Messages

**Decision:** Monthly range partitioning on `chat_messages`

**Schema:**
```sql
CREATE TABLE chat_messages (...) PARTITION BY RANGE (created_at);
CREATE TABLE chat_messages_y2024m01 PARTITION OF chat_messages ...;
```

**Benefits:**
- Query performance: Partition pruning eliminates irrelevant data
- Maintenance: Can archive/drop old partitions efficiently
- Vacuum: Smaller tables = faster autovacuum
- Index size: Indexes are partition-local

**Implementation Notes:**
- Use `pg_partman` extension for automated partition management
- Set up monthly cron job to create future partitions
- Consider hot/cold storage (SSD for recent, S3 for old via foreign data wrappers)

### 2.3 OAuth Account Separation

**Decision:** Separate `oauth_accounts` table instead of columns in users

**Rationale:**
- Users can link multiple OAuth providers (Google + Apple)
- Easier to add new providers without schema changes
- Token storage isolation
- Better audit trail per provider

### 2.4 Cache Hash Strategy

**Decision:** SHA256 hash of normalized search parameters

**Implementation:**
```python
import hashlib
import json

def compute_cache_hash(params: dict) -> str:
    # Normalize: sort keys, lowercase strings, remove nulls
    normalized = json.dumps(params, sort_keys=True, default=str)
    return hashlib.sha256(normalized.encode()).hexdigest()
```

**Benefits:**
- O(1) lookup time
- Consistent hashing across parameter reordering
- Collision-resistant

### 2.5 Polymorphic Booking Items

**Decision:** `booking_items` table with type discriminator + nullable FKs

**Alternative considered:** Single `booking_items` with JSONB for all fields

**Why this approach:**
- Referential integrity for flight/hotel details
- Query performance: Can JOIN to specific tables
- Type safety: Constraints ensure valid references
- Extensibility: Easy to add `car_booking_id`, `activity_booking_id`, etc.

### 2.6 GDPR Compliance Design

| Requirement | Implementation |
|-------------|----------------|
| **Data Minimization** | Minimal PII in `users` table; booking contact info is snapshot |
| **Consent Tracking** | `data_processing_consent`, `consent_granted_at`, `marketing_consent` |
| **Right to Deletion** | `deleted_at` soft delete; actual purge after retention period |
| **Data Portability** | JSONB fields store structured data for easy export |
| **Audit Trail** | `analytics_events` tracks all data access (implement in app layer) |

### 2.7 LangGraph Integration

**Chat Session State Management:**

```python
# Integration with LangGraph
from langgraph.checkpoint.postgres import PostgresSaver

checkpointer = PostgresSaver(conn_string)

# When creating a session
thread_id = str(uuid.uuid4())
chat_session = await db.chat_sessions.create({
    "user_id": user_id,
    "thread_id": thread_id,
    "checkpoint_ns": "travel_agent"
})

# LangGraph uses thread_id for state persistence
workflow = create_travel_agent(checkpointer=checkpointer)
config = {"configurable": {"thread_id": thread_id}}
```

---

## 3. Index Strategy

### 3.1 High-Impact Indexes

| Table | Index | Purpose |
|-------|-------|---------|
| `users` | `email` (unique, partial) | Login lookup (excludes deleted) |
| `chat_messages` | `(session_id, created_at DESC)` | Conversation display |
| `flight_search_cache` | `search_hash` (unique) | Cache lookup |
| `flight_search_cache` | `expires_at` (partial) | TTL cleanup job |
| `bookings` | `(user_id, created_at DESC)` | User booking history |
| `bookings` | `booking_reference` | Customer service lookup |

### 3.2 Partition-Aware Indexing

For partitioned tables (`chat_messages`, `analytics_events`):
- Indexes are created per partition, not on parent
- Include partition key in all indexes for partition pruning
- Example: `ON chat_messages(session_id, created_at DESC)`

### 3.3 BRIN Indexes for Time-Series

For very large time-series tables, consider BRIN (Block Range Index):

```sql
CREATE INDEX idx_chat_messages_time_brin 
ON chat_messages USING BRIN (created_at);
```

**Benefits:**
- Tiny index size (KB vs MB)
- Fast sequential scan hints
- Ideal for append-only time-series data

---

## 4. Scaling Roadmap

### 4.1 Phase 1: Single Database (Current)
- Vertical scaling (bigger instance)
- Connection pooling (PgBouncer)
- Read replicas for analytics queries

### 4.2 Phase 2: Multi-Tenant (Near Future)

**Row-Level Security (RLS) already implemented:**

```sql
-- Set tenant context per connection
SET app.current_tenant_id = 'tenant-123';

-- Query automatically filters
SELECT * FROM bookings; -- Only sees tenant-123's data
```

**Tenant Isolation Strategies:**

| Strategy | Pros | Cons | When to Use |
|----------|------|------|-------------|
| **RLS** | Simple, shared resources | Limited isolation | Start here |
| **Schema per Tenant** | Better isolation, shared DB | Schema management overhead | 10-100 tenants |
| **Database per Tenant** | Maximum isolation | Higher cost, complexity | Enterprise customers |

### 4.3 Phase 3: Service Decomposition

**Future Microservices Split:**

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  User Service   │     │  Chat Service   │     │ Booking Service │
│  (users, oauth) │     │ (sessions, msg) │     │(bookings, cache)│
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │    Event Bus (Kafka)      │
                    └───────────────────────────┘
```

**Data Migration Strategy:**
1. Set up CDC (Change Data Capture) with Debezium
2. Replicate to new service databases
3. Gradual traffic shifting
4. Original DB becomes read-only
5. Clean migration complete

### 4.4 Phase 4: Advanced Optimizations

#### Hot/Cold Storage for Chat Messages

```sql
-- Recent data (hot) on SSD
-- Old data (cold) on S3 via postgres_fdw

-- Query remains the same - planner handles routing
SELECT * FROM chat_messages 
WHERE session_id = 'xxx' AND created_at > '2024-01-01';
```

#### Materialized Views for Analytics

```sql
CREATE MATERIALIZED VIEW mv_daily_metrics AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as bookings,
    SUM(total_amount) as revenue
FROM bookings
WHERE status = 'confirmed'
GROUP BY DATE(created_at);

-- Refresh strategy
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_metrics;
```

---

## 5. Operational Procedures

### 5.1 Backup Strategy

| Type | Frequency | Retention | Tool |
|------|-----------|-----------|------|
| Full | Daily | 30 days | pg_dump / WAL-G |
| Incremental (WAL) | Continuous | 7 days | pg_basebackup |
| Cross-region | Weekly | 90 days | S3 replication |

### 5.2 Cache Maintenance

```sql
-- TTL Cleanup Job (run every hour)
DELETE FROM flight_search_cache WHERE expires_at < NOW();
DELETE FROM hotel_search_cache WHERE expires_at < NOW();

-- Vacuum after bulk deletes
VACUUM ANALYZE flight_search_cache;
```

### 5.3 Partition Management

```sql
-- Create next month's partition (automated)
CREATE TABLE chat_messages_y2024m04 
PARTITION OF chat_messages
FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

-- Detach old partition for archiving
ALTER TABLE chat_messages DETACH PARTITION chat_messages_y2023m01;
```

### 5.4 GDPR Data Export

```sql
-- Full user data export
SELECT jsonb_build_object(
    'user', to_jsonb(u.*),
    'oauth_accounts', COALESCE(jsonb_agg(DISTINCT oa.*) FILTER (WHERE oa.id IS NOT NULL), '[]'),
    'chat_sessions', COALESCE(jsonb_agg(DISTINCT cs.*) FILTER (WHERE cs.id IS NOT NULL), '[]'),
    'bookings', COALESCE(jsonb_agg(DISTINCT b.*) FILTER (WHERE b.id IS NOT NULL), '[]')
)
FROM users u
LEFT JOIN oauth_accounts oa ON oa.user_id = u.id
LEFT JOIN chat_sessions cs ON cs.user_id = u.id
LEFT JOIN bookings b ON b.user_id = u.id
WHERE u.id = 'user-uuid-here'
GROUP BY u.id;
```

### 5.5 GDPR Right to be Forgotten

```sql
-- Soft delete (immediate)
UPDATE users 
SET deleted_at = NOW(), 
    email = 'deleted-' || id || '@deleted.com',
    full_name = NULL,
    phone = NULL,
    hashed_password = NULL
WHERE id = 'user-uuid';

-- Hard delete after retention period (30 days)
-- Run as scheduled job
DELETE FROM users WHERE deleted_at < NOW() - INTERVAL '30 days';
```

---

## 6. Connection & Pooling Recommendations

### 6.1 PgBouncer Configuration

```ini
[databases]
global_travel_hub = host=localhost port=5432 dbname=global_travel_hub

[pgbouncer]
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
```

### 6.2 Application Connection Strings

```python
# SQLAlchemy example
DATABASE_URL = (
    "postgresql+asyncpg://user:pass@pgbouncer-host:6432/"
    "global_travel_hub?prepared_statement_cache_size=0"
)
```

---

## 7. Monitoring & Alerts

### 7.1 Key Metrics

| Metric | Warning | Critical | Query |
|--------|---------|----------|-------|
| Connection count | > 150 | > 190 | `SELECT count(*) FROM pg_stat_activity` |
| Replication lag | > 30s | > 5min | `SELECT extract(epoch from now() - pg_last_xact_replay_timestamp())` |
| Cache hit ratio | < 98% | < 95% | `SELECT sum(heap_blks_hit) / sum(heap_blks_hit + heap_blks_read)` |
| Long queries | > 30s | > 5min | `SELECT * FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '30 seconds'` |

### 7.2 Alert Queries

```sql
-- Table bloat estimation
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Unused indexes (candidates for removal)
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes 
WHERE idx_scan = 0 AND indexrelname NOT LIKE 'pg_toast%'
ORDER BY pg_relation_size(indexrelid) DESC;
```

---

## 8. Schema Evolution

### 8.1 Migration Guidelines

1. **Adding columns:** Use `DEFAULT` or allow NULL, then backfill
2. **Removing columns:** Rename first, monitor, then drop in next release
3. **Changing types:** Create new column, dual-write, migrate, switch, drop old
4. **Adding indexes:** Use `CONCURRENTLY` to avoid table locks

```sql
-- Safe index creation
CREATE INDEX CONCURRENTLY idx_users_tenant ON users(tenant_id);
```

### 8.2 Version Control

Store migrations in your FastAPI project:

```
backend/
├── migrations/
│   ├── versions/
│   │   ├── 001_initial_schema.sql
│   │   ├── 002_add_booking_metadata.sql
│   │   └── 003_create_partition_2024m05.sql
│   └── alembic.ini
```

---

## 9. Integration Examples

### 9.1 FastAPI + SQLAlchemy Models

```python
from sqlalchemy import Column, String, DateTime, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import declarative_base, relationship
import uuid
from datetime import datetime

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), nullable=False, unique=True)
    full_name = Column(String(100))
    role = Column(String(20), default="user")
    status = Column(String(20), default="active")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
    
    chat_sessions = relationship("ChatSession", back_populates="user")

class ChatSession(Base):
    __tablename__ = "chat_sessions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    title = Column(String(255))
    status = Column(String(20), default="active")
    thread_id = Column(UUID(as_uuid=True))
    context = Column(JSONB, default={})
    message_count = Column(Integer, default=0)
    
    user = relationship("User", back_populates="chat_sessions")
    messages = relationship("ChatMessage", back_populates="session")
```

### 9.2 Redis Cache Integration

```python
import redis
import json
from datetime import timedelta

redis_client = redis.Redis.from_url("redis://localhost:6379/0")

async def get_cached_flight_search(search_params: dict):
    # Compute hash using same logic as DB
    cache_hash = compute_cache_hash(search_params)
    
    # Check Redis first (faster)
    cached = redis_client.get(f"flight:{cache_hash}")
    if cached:
        return json.loads(cached)
    
    # Check DB cache (longer TTL)
    result = await db.fetch_one(
        "SELECT results FROM flight_search_cache WHERE search_hash = :hash AND expires_at > NOW()",
        {"hash": cache_hash}
    )
    
    if result:
        # Promote to Redis
        redis_client.setex(
            f"flight:{cache_hash}",
            timedelta(minutes=5),
            json.dumps(result["results"])
        )
        # Increment hit count
        await db.execute(
            "UPDATE flight_search_cache SET hit_count = hit_count + 1 WHERE search_hash = :hash",
            {"hash": cache_hash}
        )
        return result["results"]
    
    return None
```

---

## 10. Checklist for Production Deployment

- [ ] Enable SSL/TLS for all connections
- [ ] Configure WAL archiving for PITR
- [ ] Set up monitoring (pg_stat_statements, pg_stat_activity)
- [ ] Create read replica for analytics
- [ ] Configure automated partition creation
- [ ] Set up cache TTL cleanup cron job
- [ ] Enable query logging for slow queries (>1s)
- [ ] Configure connection pooling (PgBouncer)
- [ ] Set up backup verification (restore test monthly)
- [ ] Document runbooks for common issues

---

## 11. Contact & Maintenance

| Role | Responsibility |
|------|---------------|
| **DBA** | Partition management, backup verification |
| **Backend Team** | Query optimization, migration execution |
| **Data Team** | Analytics views, ETL pipeline |
| **Security** | Access control audit, encryption review |

---

*Document Version: 1.0*
*Last Updated: 2024*
*Maintainer: Database Architecture Team*
