-- ============================================================================
-- GLOBAL TRAVEL HUB - DATABASE MAINTENANCE PROCEDURES
-- Run these as scheduled jobs (pg_cron or external scheduler)
-- ============================================================================

-- ============================================================================
-- 1. PARTITION MANAGEMENT
-- ============================================================================

-- Function to create future partitions
CREATE OR REPLACE FUNCTION create_monthly_partition(
    p_table_name TEXT,
    p_year INTEGER,
    p_month INTEGER
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    partition_name := p_table_name || '_y' || p_year || 'm' || LPAD(p_month::TEXT, 2, '0');
    start_date := make_date(p_year, p_month, 1);
    end_date := start_date + INTERVAL '1 month';
    
    -- Check if partition exists
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' AND tablename = partition_name
    ) THEN
        RETURN 'Partition ' || partition_name || ' already exists';
    END IF;
    
    -- Create partition
    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        p_table_name,
        start_date,
        end_date
    );
    
    RETURN 'Created partition: ' || partition_name;
END;
$$;

-- Create partitions for next 3 months (run monthly)
DO $$
DECLARE
    current_date_val DATE := CURRENT_DATE;
    i INTEGER;
    year_val INTEGER;
    month_val INTEGER;
BEGIN
    FOR i IN 1..3 LOOP
        year_val := EXTRACT(YEAR FROM current_date_val + (i || ' months')::INTERVAL)::INTEGER;
        month_val := EXTRACT(MONTH FROM current_date_val + (i || ' months')::INTERVAL)::INTEGER;
        
        -- Create for chat_messages
        PERFORM create_monthly_partition('chat_messages', year_val, month_val);
        
        -- Create for analytics_events
        PERFORM create_monthly_partition('analytics_events', year_val, month_val);
    END LOOP;
END $$;

-- ============================================================================
-- 2. CACHE MAINTENANCE (Run hourly)
-- ============================================================================

-- Procedure to clean expired cache entries
CREATE OR REPLACE PROCEDURE cleanup_expired_cache()
LANGUAGE plpgsql
AS $$
DECLARE
    flight_deleted INTEGER;
    hotel_deleted INTEGER;
BEGIN
    -- Delete expired flight cache
    DELETE FROM flight_search_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS flight_deleted = ROW_COUNT;
    
    -- Delete expired hotel cache
    DELETE FROM hotel_search_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS hotel_deleted = ROW_COUNT;
    
    -- Log cleanup (optional: insert to maintenance_log table)
    RAISE NOTICE 'Cache cleanup complete: % flight, % hotel entries removed', 
        flight_deleted, hotel_deleted;
END;
$$;

-- Run cleanup
CALL cleanup_expired_cache();

-- ============================================================================
-- 3. GDPR DATA PURGE (Run daily)
-- ============================================================================

-- Hard delete users soft-deleted > 30 days ago
CREATE OR REPLACE PROCEDURE gdpr_purge_old_data()
LANGUAGE plpgsql
AS $$
DECLARE
    users_purged INTEGER;
    sessions_purged INTEGER;
BEGIN
    -- Anonymize and purge old user data
    WITH purged_users AS (
        DELETE FROM users 
        WHERE deleted_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO users_purged FROM purged_users;
    
    -- Delete old archived chat sessions
    WITH purged_sessions AS (
        DELETE FROM chat_sessions
        WHERE status = 'deleted' 
          AND updated_at < NOW() - INTERVAL '30 days'
        RETURNING id
    )
    SELECT COUNT(*) INTO sessions_purged FROM purged_sessions;
    
    RAISE NOTICE 'GDPR purge complete: % users, % sessions removed',
        users_purged, sessions_purged;
END;
$$;

-- ============================================================================
-- 4. DATABASE STATISTICS REFRESH (Run daily)
-- ============================================================================

-- Analyze all tables for query planner
ANALYZE users;
ANALYZE chat_sessions;
ANALYZE chat_messages;
ANALYZE bookings;
ANALYZE booking_items;
ANALYZE flight_bookings;
ANALYZE hotel_bookings;
ANALYZE flight_search_cache;
ANALYZE hotel_search_cache;

-- ============================================================================
-- 5. INDEX MAINTENANCE (Run weekly)
-- ============================================================================

-- Reindex concurrently to avoid locks
REINDEX INDEX CONCURRENTLY idx_users_email;
REINDEX INDEX CONCURRENTLY idx_chat_messages_session_created;
REINDEX INDEX CONCURRENTLY idx_bookings_user;
REINDEX INDEX CONCURRENTLY idx_flight_cache_hash;
REINDEX INDEX CONCURRENTLY idx_hotel_cache_hash;

-- ============================================================================
-- 6. VACUUM (Run weekly or use autovacuum tuning)
-- ============================================================================

-- Vacuum tables with high update/delete activity
VACUUM ANALYZE chat_messages;
VACUUM ANALYZE analytics_events;
VACUUM ANALYZE flight_search_cache;
VACUUM ANALYZE hotel_search_cache;
