-- ============================================================================
-- GLOBAL TRAVEL HUB - ANALYTICS QUERIES
-- Production-ready queries for admin dashboard and business intelligence
-- ============================================================================

-- ============================================================================
-- USER ANALYTICS
-- ============================================================================

-- 1. Daily/Weekly/Monthly User Growth
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as new_users,
    COUNT(*) FILTER (WHERE oauth_accounts.id IS NOT NULL) as oauth_signups,
    COUNT(*) FILTER (WHERE data_processing_consent = TRUE) as consenting_users
FROM users
LEFT JOIN oauth_accounts ON oauth_accounts.user_id = users.id
WHERE deleted_at IS NULL
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- 2. User Cohort Retention (by signup week)
WITH cohorts AS (
    SELECT 
        id as user_id,
        DATE_TRUNC('week', created_at) as cohort_week
    FROM users
    WHERE created_at >= NOW() - INTERVAL '12 weeks'
),
activity AS (
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('week', created_at) as activity_week
    FROM chat_sessions
    UNION
    SELECT DISTINCT
        user_id,
        DATE_TRUNC('week', created_at) as activity_week
    FROM bookings
)
SELECT 
    c.cohort_week,
    COUNT(DISTINCT c.user_id) as cohort_size,
    COUNT(DISTINCT a.user_id) FILTER (WHERE a.activity_week = c.cohort_week + INTERVAL '1 week') as week_1,
    COUNT(DISTINCT a.user_id) FILTER (WHERE a.activity_week = c.cohort_week + INTERVAL '2 weeks') as week_2,
    COUNT(DISTINCT a.user_id) FILTER (WHERE a.activity_week = c.cohort_week + INTERVAL '4 weeks') as week_4
FROM cohorts c
LEFT JOIN activity a ON c.user_id = a.user_id AND a.activity_week > c.cohort_week
GROUP BY c.cohort_week
ORDER BY c.cohort_week DESC;

-- 3. User Lifetime Value (LTV) by Cohort
SELECT 
    DATE_TRUNC('month', u.created_at) as signup_month,
    COUNT(DISTINCT u.id) as users,
    AVG(COALESCE(spending.total, 0)) as avg_ltv,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY COALESCE(spending.total, 0)) as median_ltv
FROM users u
LEFT JOIN (
    SELECT user_id, SUM(total_amount) as total
    FROM bookings
    WHERE status IN ('confirmed', 'completed')
    GROUP BY user_id
) spending ON spending.user_id = u.id
WHERE u.deleted_at IS NULL
GROUP BY DATE_TRUNC('month', u.created_at)
ORDER BY signup_month DESC;

-- ============================================================================
-- CHAT & AI ANALYTICS
-- ============================================================================

-- 4. Chat Session Metrics
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as new_sessions,
    AVG(message_count) as avg_messages_per_session,
    AVG(total_tokens_used) as avg_tokens_per_session,
    AVG(EXTRACT(EPOCH FROM (updated_at - created_at))/60) as avg_session_duration_minutes
FROM chat_sessions
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- 5. AI Performance Metrics (Latency & Token Usage)
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    model,
    COUNT(*) as message_count,
    AVG(latency_ms) as avg_latency_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms) as p95_latency_ms,
    AVG(tokens_total) as avg_tokens,
    SUM(tokens_total) as total_tokens
FROM chat_messages
WHERE role = 'ai'
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', created_at), model
ORDER BY hour DESC;

-- 6. Chat-to-Booking Conversion Funnel
WITH chat_users AS (
    SELECT DISTINCT 
        user_id,
        DATE_TRUNC('day', created_at) as chat_date
    FROM chat_sessions
    WHERE created_at >= NOW() - INTERVAL '30 days'
),
booking_users AS (
    SELECT DISTINCT 
        user_id,
        DATE_TRUNC('day', created_at) as booking_date
    FROM bookings
    WHERE status IN ('confirmed', 'completed')
      AND created_at >= NOW() - INTERVAL '30 days'
)
SELECT 
    c.chat_date,
    COUNT(DISTINCT c.user_id) as users_with_chat,
    COUNT(DISTINCT b.user_id) as users_who_booked,
    ROUND(
        COUNT(DISTINCT b.user_id)::numeric / 
        NULLIF(COUNT(DISTINCT c.user_id), 0) * 100, 
        2
    ) as conversion_rate_pct
FROM chat_users c
LEFT JOIN booking_users b ON c.user_id = b.user_id 
    AND b.booking_date BETWEEN c.chat_date AND c.chat_date + INTERVAL '7 days'
GROUP BY c.chat_date
ORDER BY c.chat_date DESC;

-- 7. Popular Travel Intent from Chat Context
SELECT 
    context->>'destination' as destination,
    context->>'intent' as intent,
    COUNT(*) as session_count
FROM chat_sessions
WHERE context ? 'destination'
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY context->>'destination', context->>'intent'
ORDER BY session_count DESC
LIMIT 20;

-- ============================================================================
-- CACHE PERFORMANCE ANALYTICS
-- ============================================================================

-- 8. Cache Hit Rate & Savings
WITH cache_stats AS (
    SELECT 
        'flight' as type,
        COUNT(*) FILTER (WHERE last_accessed_at > created_at + INTERVAL '1 minute') as hits,
        COUNT(*) as total,
        AVG(hit_count) as avg_hits,
        SUM(hit_count) as total_hits
    FROM flight_search_cache
    WHERE created_at >= NOW() - INTERVAL '7 days'
    UNION ALL
    SELECT 
        'hotel' as type,
        COUNT(*) FILTER (WHERE last_accessed_at > created_at + INTERVAL '1 minute') as hits,
        COUNT(*) as total,
        AVG(hit_count) as avg_hits,
        SUM(hit_count) as total_hits
    FROM hotel_search_cache
    WHERE created_at >= NOW() - INTERVAL '7 days'
)
SELECT 
    type,
    hits,
    total - hits as misses,
    ROUND(hits::numeric / NULLIF(total, 0) * 100, 2) as hit_rate_pct,
    avg_hits,
    total_hits
FROM cache_stats;

-- 9. Most Valuable Cache Entries (by hit count)
SELECT 
    origin,
    destination,
    departure_date,
    hit_count,
    EXTRACT(EPOCH FROM (NOW() - created_at))/3600 as hours_since_creation
FROM flight_search_cache
ORDER BY hit_count DESC
LIMIT 20;

-- 10. Cache Size & Storage Analysis
SELECT 
    'flight_search_cache' as table_name,
    pg_size_pretty(pg_total_relation_size('flight_search_cache')) as total_size,
    COUNT(*) as row_count,
    pg_size_pretty(pg_column_size(results)) as avg_result_size
FROM flight_search_cache
UNION ALL
SELECT 
    'hotel_search_cache' as table_name,
    pg_size_pretty(pg_total_relation_size('hotel_search_cache')) as total_size,
    COUNT(*) as row_count,
    pg_size_pretty(pg_column_size(results)) as avg_result_size
FROM hotel_search_cache;

-- ============================================================================
-- BOOKING & REVENUE ANALYTICS
-- ============================================================================

-- 11. Revenue Dashboard (Daily)
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_bookings,
    COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_bookings,
    SUM(total_amount) FILTER (WHERE status = 'confirmed') as revenue,
    AVG(total_amount) FILTER (WHERE status = 'confirmed') as avg_order_value,
    SUM(tax_amount) FILTER (WHERE status = 'confirmed') as tax_collected
FROM bookings
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- 12. Revenue by Product Mix
SELECT 
    bi.item_type,
    COUNT(DISTINCT bi.booking_id) as bookings_with_item,
    COUNT(*) as item_count,
    SUM(bi.item_price) as total_revenue,
    AVG(bi.item_price) as avg_item_price
FROM booking_items bi
JOIN bookings b ON b.id = bi.booking_id
WHERE b.status IN ('confirmed', 'completed')
  AND b.created_at >= NOW() - INTERVAL '30 days'
GROUP BY bi.item_type;

-- 13. Top Routes by Booking Volume
SELECT 
    fb.origin,
    fb.destination,
    fb.origin || '-' || fb.destination as route,
    COUNT(*) as bookings,
    AVG(fb_passenger.price) as avg_price,
    SUM(fb_passenger.price) as total_revenue
FROM flight_bookings fb
JOIN booking_items bi ON bi.flight_booking_id = fb.id
JOIN bookings b ON b.id = bi.booking_id
CROSS JOIN LATERAL (
    SELECT (p->>'price')::decimal as price
    FROM jsonb_array_elements(fb.passengers) as p
) as fb_passenger
WHERE b.status IN ('confirmed', 'completed')
  AND b.created_at >= NOW() - INTERVAL '90 days'
GROUP BY fb.origin, fb.destination
ORDER BY bookings DESC
LIMIT 20;

-- 14. Hotel Performance by Location
SELECT 
    hb.hotel_name,
    LEFT(hb.hotel_address, 50) as location,
    COUNT(*) as bookings,
    AVG(hb.nights) as avg_nights,
    AVG(bi.item_price / hb.nights / hb.rooms) as avg_nightly_rate,
    SUM(bi.item_price) as total_revenue
FROM hotel_bookings hb
JOIN booking_items bi ON bi.hotel_booking_id = hb.id
JOIN bookings b ON b.id = bi.booking_id
WHERE b.status IN ('confirmed', 'completed')
  AND b.created_at >= NOW() - INTERVAL '90 days'
GROUP BY hb.hotel_name, hb.hotel_address
ORDER BY total_revenue DESC
LIMIT 20;

-- 15. Booking Conversion Time (from chat to booking)
SELECT 
    DATE_TRUNC('day', b.created_at) as date,
    AVG(EXTRACT(EPOCH FROM (b.created_at - cs.created_at))/3600) as avg_hours_to_book,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (b.created_at - cs.created_at))/3600
    ) as median_hours_to_book
FROM bookings b
JOIN chat_sessions cs ON cs.id = b.chat_session_id
WHERE b.created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', b.created_at)
ORDER BY date DESC;

-- ============================================================================
-- OPERATIONAL ANALYTICS
-- ============================================================================

-- 16. Error Rate & System Health
SELECT 
    event_type,
    DATE_TRUNC('hour', created_at) as hour,
    COUNT(*) as event_count,
    event_data->>'error_code' as error_code,
    COUNT(DISTINCT user_id) as affected_users
FROM analytics_events
WHERE event_type = 'error_occurred'
  AND created_at >= NOW() - INTERVAL '24 hours'
GROUP BY event_type, DATE_TRUNC('hour', created_at), event_data->>'error_code'
ORDER BY hour DESC, event_count DESC;

-- 17. Peak Usage Hours (for capacity planning)
SELECT 
    EXTRACT(hour FROM created_at) as hour_of_day,
    EXTRACT(dow FROM created_at) as day_of_week,
    COUNT(*) as chat_sessions,
    COUNT(DISTINCT user_id) as unique_users
FROM chat_sessions
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY EXTRACT(hour FROM created_at), EXTRACT(dow FROM created_at)
ORDER BY day_of_week, hour_of_day;

-- 18. GDPR Compliance: Data Retention Audit
SELECT 
    'users' as table_name,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as soft_deleted,
    COUNT(*) FILTER (WHERE deleted_at < NOW() - INTERVAL '30 days') as ready_for_purge,
    MIN(deleted_at) as oldest_deletion
FROM users
UNION ALL
SELECT 
    'chat_sessions' as table_name,
    COUNT(*) FILTER (WHERE status = 'deleted'),
    COUNT(*) FILTER (WHERE status = 'deleted' AND updated_at < NOW() - INTERVAL '30 days'),
    MIN(updated_at)
FROM chat_sessions
WHERE status = 'deleted';

-- ============================================================================
-- REAL-TIME DASHBOARD QUERIES (optimized with materialized views)
-- ============================================================================

-- 19. Today's Real-time Stats (fast query for dashboard)
SELECT 
    (SELECT COUNT(*) FROM users WHERE DATE(created_at) = CURRENT_DATE) as new_users_today,
    (SELECT COUNT(*) FROM chat_sessions WHERE DATE(created_at) = CURRENT_DATE) as chat_sessions_today,
    (SELECT COUNT(*) FROM bookings WHERE DATE(created_at) = CURRENT_DATE AND status = 'confirmed') as bookings_today,
    (SELECT COALESCE(SUM(total_amount), 0) FROM bookings WHERE DATE(created_at) = CURRENT_DATE AND status = 'confirmed') as revenue_today,
    (SELECT COUNT(*) FROM chat_messages WHERE DATE(created_at) = CURRENT_DATE) as messages_today,
    (SELECT AVG(latency_ms) FROM chat_messages WHERE DATE(created_at) = CURRENT_DATE AND role = 'ai') as avg_ai_latency_today;

-- 20. Monthly Recurring Revenue (MRR) Estimate
WITH monthly_bookings AS (
    SELECT 
        DATE_TRUNC('month', created_at) as month,
        SUM(total_amount) as revenue
    FROM bookings
    WHERE status IN ('confirmed', 'completed')
    GROUP BY DATE_TRUNC('month', created_at)
)
SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) as previous_month,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) / 
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100,
        2
    ) as growth_pct
FROM monthly_bookings
ORDER BY month DESC
LIMIT 12;
