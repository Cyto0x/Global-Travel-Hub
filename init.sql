-- ============================================================================
-- GLOBAL TRAVEL HUB - PRODUCTION DATABASE SCHEMA
-- PostgreSQL 15+ with partitioning and JSONB optimization
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CORE USER MANAGEMENT
-- ============================================================================

CREATE TYPE user_role AS ENUM ('user', 'admin', 'support');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'deleted');

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Authentication
    email VARCHAR(255) NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    hashed_password VARCHAR(255), -- Nullable for OAuth-only users
    
    -- Profile (GDPR: minimal PII)
    full_name VARCHAR(100),
    avatar_url TEXT,
    phone VARCHAR(20),
    
    -- Status & Role
    role user_role DEFAULT 'user',
    status user_status DEFAULT 'active',
    
    -- GDPR Compliance
    data_processing_consent BOOLEAN DEFAULT FALSE,
    consent_granted_at TIMESTAMPTZ,
    marketing_consent BOOLEAN DEFAULT FALSE,
    
    -- Security
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    last_ip_address INET,
    
    -- Multi-tenant readiness (future)
    tenant_id UUID,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ, -- Soft delete for GDPR
    
    -- Constraints
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT valid_consent CHECK (
        (data_processing_consent = FALSE AND consent_granted_at IS NULL) OR
        (data_processing_consent = TRUE AND consent_granted_at IS NOT NULL)
    )
);

-- Separate table for OAuth accounts (supports multiple providers per user)
CREATE TYPE oauth_provider AS ENUM ('google', 'apple', 'facebook');

CREATE TABLE oauth_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider oauth_provider NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    provider_email VARCHAR(255),
    access_token TEXT,
    refresh_token TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_provider_account UNIQUE (provider, provider_user_id)
);

-- ============================================================================
-- CHAT SYSTEM (Optimized for high-write throughput)
-- ============================================================================

CREATE TYPE chat_session_status AS ENUM ('active', 'archived', 'deleted');

CREATE TABLE chat_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Session metadata
    title VARCHAR(255),
    status chat_session_status DEFAULT 'active',
    
    -- AI Agent state (LangGraph checkpoint compatibility)
    thread_id UUID, -- Maps to LangGraph thread
    checkpoint_ns VARCHAR(255), -- Namespace for state management
    
    -- Session context
    context JSONB DEFAULT '{}', -- Travel preferences, current booking flow, etc.
    
    -- Analytics
    message_count INTEGER DEFAULT 0,
    total_tokens_used INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

-- Chat messages with range partitioning for high-write performance
CREATE TYPE message_role AS ENUM ('user', 'ai', 'system', 'tool');

CREATE TABLE chat_messages (
    id UUID NOT NULL,
    session_id UUID NOT NULL,
    
    -- Message content
    role message_role NOT NULL,
    content TEXT NOT NULL,
    
    -- AI-specific fields
    model VARCHAR(50), -- e.g., 'gpt-4', 'claude-3'
    tokens_prompt INTEGER,
    tokens_completion INTEGER,
    tokens_total INTEGER,
    latency_ms INTEGER,
    
    -- Tool calls (for function calling)
    tool_calls JSONB,
    tool_call_id VARCHAR(100),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    -- Partition key (monthly partitions)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create monthly partitions (automated via cron or application)
CREATE TABLE chat_messages_y2024m01 PARTITION OF chat_messages
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE chat_messages_y2024m02 PARTITION OF chat_messages
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE chat_messages_y2024m03 PARTITION OF chat_messages
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
-- ... continue pattern or use automated partition management

-- Default partition for overflow
CREATE TABLE chat_messages_default PARTITION OF chat_messages DEFAULT;

-- ============================================================================
-- SEARCH CACHE (Reduce external API calls)
-- ============================================================================

-- Flight search cache
CREATE TABLE flight_search_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Search parameters hash for quick lookup
    search_hash VARCHAR(64) NOT NULL UNIQUE, -- SHA256 of normalized params
    
    -- Search criteria
    origin VARCHAR(3) NOT NULL, -- IATA code
    destination VARCHAR(3) NOT NULL,
    departure_date DATE NOT NULL,
    return_date DATE,
    passengers_adults INTEGER DEFAULT 1,
    passengers_children INTEGER DEFAULT 0,
    passengers_infants INTEGER DEFAULT 0,
    cabin_class VARCHAR(20) DEFAULT 'economy',
    
    -- Cached results
    results JSONB NOT NULL,
    result_count INTEGER DEFAULT 0,
    
    -- Cache metadata
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count INTEGER DEFAULT 1,
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hotel search cache
CREATE TABLE hotel_search_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    search_hash VARCHAR(64) NOT NULL UNIQUE,
    
    -- Search criteria
    location VARCHAR(100) NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    guests INTEGER DEFAULT 1,
    rooms INTEGER DEFAULT 1,
    
    -- Filters (stored for cache invalidation context)
    star_rating INTEGER[],
    price_min DECIMAL(10,2),
    price_max DECIMAL(10,2),
    amenities VARCHAR(50)[],
    
    -- Cached results
    results JSONB NOT NULL,
    result_count INTEGER DEFAULT 0,
    
    -- Cache metadata
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count INTEGER DEFAULT 1,
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- BOOKING SYSTEM
-- ============================================================================

CREATE TYPE booking_status AS ENUM (
    'pending', 'confirmed', 'cancelled', 'completed', 'refunded'
);
CREATE TYPE booking_item_type AS ENUM ('flight', 'hotel');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    
    -- Booking reference (user-facing)
    booking_reference VARCHAR(20) NOT NULL UNIQUE, -- e.g., 'GTH-ABC123'
    
    -- Status
    status booking_status DEFAULT 'pending',
    payment_status payment_status DEFAULT 'pending',
    
    -- Financials
    total_amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    discount_amount DECIMAL(12,2) DEFAULT 0,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Contact info (snapshot at booking time)
    contact_email VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(20),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    special_requests TEXT,
    
    -- AI attribution (which chat session led to this booking)
    chat_session_id UUID REFERENCES chat_sessions(id),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ
);

-- Booking items (polymorphic association for flights and hotels)
CREATE TABLE booking_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    
    item_type booking_item_type NOT NULL,
    item_sequence INTEGER NOT NULL, -- Order in itinerary
    
    -- Polymorphic foreign keys
    flight_booking_id UUID,
    hotel_booking_id UUID,
    
    -- Price snapshot (denormalized for historical accuracy)
    item_price DECIMAL(12,2) NOT NULL,
    item_currency VARCHAR(3) DEFAULT 'USD',
    
    -- Constraints
    CONSTRAINT valid_item_reference CHECK (
        (item_type = 'flight' AND flight_booking_id IS NOT NULL AND hotel_booking_id IS NULL) OR
        (item_type = 'hotel' AND hotel_booking_id IS NOT NULL AND flight_booking_id IS NULL)
    ),
    CONSTRAINT unique_booking_sequence UNIQUE (booking_id, item_sequence)
);

-- Flight booking details
CREATE TABLE flight_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Flight details
    booking_reference VARCHAR(20) NOT NULL, -- Airline PNR
    airline_code VARCHAR(3) NOT NULL,
    airline_name VARCHAR(100),
    flight_number VARCHAR(10) NOT NULL,
    
    -- Route
    origin VARCHAR(3) NOT NULL,
    destination VARCHAR(3) NOT NULL,
    
    -- Times
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time TIMESTAMPTZ NOT NULL,
    
    -- Aircraft & Class
    aircraft_type VARCHAR(20),
    cabin_class VARCHAR(20) DEFAULT 'economy',
    
    -- Passengers (stored as JSONB array)
    passengers JSONB NOT NULL DEFAULT '[]',
    passenger_count INTEGER NOT NULL DEFAULT 1,
    
    -- Baggage
    checked_bags INTEGER DEFAULT 0,
    carry_on_included BOOLEAN DEFAULT TRUE,
    
    -- External IDs
    external_booking_id VARCHAR(100),
    external_flight_id VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hotel booking details
CREATE TABLE hotel_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Hotel details
    booking_reference VARCHAR(20) NOT NULL, -- Hotel confirmation number
    hotel_id VARCHAR(50) NOT NULL, -- External hotel ID
    hotel_name VARCHAR(200) NOT NULL,
    hotel_address TEXT,
    hotel_rating DECIMAL(2,1),
    
    -- Room details
    room_type VARCHAR(100) NOT NULL,
    room_description TEXT,
    bed_type VARCHAR(50),
    
    -- Stay details
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    nights INTEGER NOT NULL,
    guests INTEGER NOT NULL DEFAULT 1,
    rooms INTEGER NOT NULL DEFAULT 1,
    
    -- Amenities included
    breakfast_included BOOLEAN DEFAULT FALSE,
    free_cancellation BOOLEAN DEFAULT FALSE,
    cancellation_deadline TIMESTAMPTZ,
    
    -- Guest details
    guests_details JSONB NOT NULL DEFAULT '[]',
    
    -- External IDs
    external_booking_id VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add foreign key constraints after table creation
ALTER TABLE booking_items
    ADD CONSTRAINT fk_flight_booking 
        FOREIGN KEY (flight_booking_id) REFERENCES flight_bookings(id),
    ADD CONSTRAINT fk_hotel_booking 
        FOREIGN KEY (hotel_booking_id) REFERENCES hotel_bookings(id);

-- ============================================================================
-- ANALYTICS & EVENT TRACKING
-- ============================================================================

CREATE TYPE analytics_event_type AS ENUM (
    'page_view', 'search_flight', 'search_hotel', 
    'chat_started', 'chat_message', 'booking_initiated',
    'booking_completed', 'cache_hit', 'cache_miss',
    'error_occurred'
);

CREATE TABLE analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    event_type analytics_event_type NOT NULL,
    
    -- Optional user reference (allows anonymous tracking)
    user_id UUID REFERENCES users(id),
    session_id VARCHAR(100),
    
    -- Event data (flexible JSONB)
    event_data JSONB NOT NULL DEFAULT '{}',
    
    -- Request context
    ip_address INET,
    user_agent TEXT,
    
    -- Partition key
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Monthly partitions for analytics
CREATE TABLE analytics_events_y2024m01 PARTITION OF analytics_events
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE analytics_events_y2024m02 PARTITION OF analytics_events
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Default partition
CREATE TABLE analytics_events_default PARTITION OF analytics_events DEFAULT;

-- ============================================================================
-- INDEXES (Performance Optimization)
-- ============================================================================

-- Users indexes
CREATE UNIQUE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_tenant ON users(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_users_created_at ON users(created_at);

-- OAuth indexes
CREATE INDEX idx_oauth_user ON oauth_accounts(user_id);

-- Chat session indexes
CREATE INDEX idx_chat_sessions_user ON chat_sessions(user_id);
CREATE INDEX idx_chat_sessions_status ON chat_sessions(status);
CREATE INDEX idx_chat_sessions_thread ON chat_sessions(thread_id);
CREATE INDEX idx_chat_sessions_updated ON chat_sessions(updated_at DESC);

-- Chat message indexes (optimized for partition pruning)
CREATE INDEX idx_chat_messages_session ON chat_messages(session_id, created_at DESC);
CREATE INDEX idx_chat_messages_role ON chat_messages(role) WHERE role = 'ai';

-- Cache indexes (TTL cleanup)
CREATE INDEX idx_flight_cache_expires ON flight_search_cache(expires_at) 
    WHERE expires_at < NOW();
CREATE INDEX idx_flight_cache_hash ON flight_search_cache(search_hash);
CREATE INDEX idx_flight_cache_route ON flight_search_cache(origin, destination, departure_date);
CREATE INDEX idx_flight_cache_hits ON flight_search_cache(hit_count DESC);

CREATE INDEX idx_hotel_cache_expires ON hotel_search_cache(expires_at) 
    WHERE expires_at < NOW();
CREATE INDEX idx_hotel_cache_hash ON hotel_search_cache(search_hash);
CREATE INDEX idx_hotel_cache_location ON hotel_search_cache(location, check_in, check_out);

-- Booking indexes
CREATE INDEX idx_bookings_user ON bookings(user_id, created_at DESC);
CREATE INDEX idx_bookings_reference ON bookings(booking_reference);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_chat_session ON bookings(chat_session_id);
CREATE INDEX idx_bookings_created ON bookings(created_at DESC);

CREATE INDEX idx_booking_items_booking ON booking_items(booking_id);

CREATE INDEX idx_flight_bookings_route ON flight_bookings(origin, destination);
CREATE INDEX idx_flight_bookings_departure ON flight_bookings(departure_time);
CREATE INDEX idx_flight_bookings_reference ON flight_bookings(booking_reference);

CREATE INDEX idx_hotel_bookings_checkin ON hotel_bookings(check_in);
CREATE INDEX idx_hotel_bookings_hotel ON hotel_bookings(hotel_id);

-- Analytics indexes (partition-friendly)
CREATE INDEX idx_analytics_type_time ON analytics_events(event_type, created_at);
CREATE INDEX idx_analytics_user ON analytics_events(user_id, created_at DESC) 
    WHERE user_id IS NOT NULL;
CREATE INDEX idx_analytics_session ON analytics_events(session_id, created_at);

-- ============================================================================
-- TRIGGERS (Auto-update timestamps)
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER tr_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER tr_oauth_accounts_updated_at
    BEFORE UPDATE ON oauth_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER tr_chat_sessions_updated_at
    BEFORE UPDATE ON chat_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Chat messages counter update
CREATE OR REPLACE FUNCTION increment_session_message_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_sessions 
    SET message_count = message_count + 1,
        total_tokens_used = COALESCE(total_tokens_used, 0) + COALESCE(NEW.tokens_total, 0),
        updated_at = NOW()
    WHERE id = NEW.session_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_chat_message_counter
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION increment_session_message_count();

-- ============================================================================
-- VIEWS (Convenience for common queries)
-- ============================================================================

-- Active users with booking stats
CREATE VIEW user_dashboard_stats AS
SELECT 
    u.id,
    u.email,
    u.full_name,
    u.role,
    u.status,
    u.created_at,
    COUNT(DISTINCT cs.id) as chat_session_count,
    COUNT(DISTINCT b.id) as booking_count,
    COALESCE(SUM(b.total_amount), 0) as total_spent,
    MAX(b.created_at) as last_booking_at
FROM users u
LEFT JOIN chat_sessions cs ON cs.user_id = u.id AND cs.status = 'active'
LEFT JOIN bookings b ON b.user_id = u.id AND b.status IN ('confirmed', 'completed')
WHERE u.deleted_at IS NULL
GROUP BY u.id, u.email, u.full_name, u.role, u.status, u.created_at;

-- Booking details view (joined)
CREATE VIEW booking_details AS
SELECT 
    b.id,
    b.booking_reference,
    b.user_id,
    b.status,
    b.total_amount,
    b.currency,
    b.created_at,
    u.email as user_email,
    u.full_name as user_name,
    COUNT(bi.id) as item_count,
    jsonb_agg(
        jsonb_build_object(
            'type', bi.item_type,
            'price', bi.item_price,
            'details', CASE 
                WHEN bi.item_type = 'flight' THEN (
                    SELECT jsonb_build_object(
                        'airline', fb.airline_name,
                        'flight', fb.flight_number,
                        'route', fb.origin || '-' || fb.destination,
                        'departure', fb.departure_time
                    )
                    FROM flight_bookings fb WHERE fb.id = bi.flight_booking_id
                )
                WHEN bi.item_type = 'hotel' THEN (
                    SELECT jsonb_build_object(
                        'hotel', hb.hotel_name,
                        'check_in', hb.check_in,
                        'nights', hb.nights
                    )
                    FROM hotel_bookings hb WHERE hb.id = bi.hotel_booking_id
                )
            END
        )
    ) as items
FROM bookings b
JOIN users u ON u.id = b.user_id
LEFT JOIN booking_items bi ON bi.booking_id = b.id
GROUP BY b.id, b.booking_reference, b.user_id, b.status, 
         b.total_amount, b.currency, b.created_at, u.email, u.full_name;

-- Cache hit rate view
CREATE VIEW cache_performance AS
SELECT 
    'flight' as cache_type,
    COUNT(*) as total_entries,
    SUM(hit_count) as total_hits,
    AVG(hit_count) as avg_hits,
    COUNT(*) FILTER (WHERE expires_at < NOW()) as expired_entries
FROM flight_search_cache
UNION ALL
SELECT 
    'hotel' as cache_type,
    COUNT(*) as total_entries,
    SUM(hit_count) as total_hits,
    AVG(hit_count) as avg_hits,
    COUNT(*) FILTER (WHERE expires_at < NOW()) as expired_entries
FROM hotel_search_cache;

-- ============================================================================
-- ROW LEVEL SECURITY (Multi-tenant preparation)
-- ============================================================================

-- Enable RLS on user-facing tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Example policies (to be refined with auth integration)
CREATE POLICY user_isolation ON users
    FOR ALL
    USING (id = current_setting('app.current_user_id')::UUID OR 
           current_setting('app.user_role') = 'admin');

CREATE POLICY chat_session_isolation ON chat_sessions
    FOR ALL
    USING (user_id = current_setting('app.current_user_id')::UUID OR 
           current_setting('app.user_role') = 'admin');

-- ============================================================================
-- COMMENTS (Documentation)
-- ============================================================================

COMMENT ON TABLE users IS 'Core user accounts with GDPR compliance fields';
COMMENT ON TABLE oauth_accounts IS 'OAuth provider linkage for social login';
COMMENT ON TABLE chat_sessions IS 'AI conversation sessions with LangGraph integration';
COMMENT ON TABLE chat_messages IS 'Partitioned message storage for high-write throughput';
COMMENT ON TABLE flight_search_cache IS 'TTL-based cache for flight search results';
COMMENT ON TABLE hotel_search_cache IS 'TTL-based cache for hotel search results';
COMMENT ON TABLE bookings IS 'Root booking record with financial summary';
COMMENT ON TABLE booking_items IS 'Polymorphic junction for booking components';
COMMENT ON TABLE analytics_events IS 'Partitioned event stream for business intelligence';
