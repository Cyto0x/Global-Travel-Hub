-- ============================================================================
-- GLOBAL TRAVEL HUB - DATABASE SECURITY SETUP
-- Roles, permissions, and RLS activation
-- ============================================================================

-- ============================================================================
-- 1. CREATE ROLES
-- ============================================================================

-- Application role (used by FastAPI backend)
CREATE ROLE gth_app WITH LOGIN PASSWORD 'change_this_in_production';

-- Read-only role (for analytics, BI tools)
CREATE ROLE gth_readonly WITH LOGIN PASSWORD 'change_this_in_production';

-- Admin role (for migrations, maintenance)
CREATE ROLE gth_admin WITH LOGIN PASSWORD 'change_this_in_production';

-- ============================================================================
-- 2. GRANT PERMISSIONS
-- ============================================================================

-- gth_app: Full CRUD on all tables
GRANT USAGE ON SCHEMA public TO gth_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO gth_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO gth_app;

-- gth_readonly: SELECT only
GRANT USAGE ON SCHEMA public TO gth_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO gth_readonly;

-- gth_admin: Full access including DDL
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gth_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO gth_admin;
GRANT CREATE ON SCHEMA public TO gth_admin;

-- Future tables automatically get permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gth_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO gth_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO gth_readonly;

-- ============================================================================
-- 3. ENABLE ROW LEVEL SECURITY (Multi-tenant preparation)
-- ============================================================================

-- Note: RLS policies are already created in schema.sql
-- This section enables them and sets up application context

-- Function to set current user ID (call from application)
CREATE OR REPLACE FUNCTION set_app_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::TEXT, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to set current user role (call from application)
CREATE OR REPLACE FUNCTION set_app_role(role_name TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.user_role', role_name, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to set tenant context
CREATE OR REPLACE FUNCTION set_app_tenant(tenant_id UUID)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', tenant_id::TEXT, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. RLS POLICIES
-- ============================================================================

-- Users: Can only see own record (unless admin)
DROP POLICY IF EXISTS user_isolation ON users;
CREATE POLICY user_isolation ON users
    FOR ALL
    USING (
        id = COALESCE(current_setting('app.current_user_id', TRUE), '00000000-0000-0000-0000-000000000000')::UUID
        OR current_setting('app.user_role', TRUE) = 'admin'
    );

-- Chat sessions: User sees own, admin sees all
DROP POLICY IF EXISTS chat_session_isolation ON chat_sessions;
CREATE POLICY chat_session_isolation ON chat_sessions
    FOR ALL
    USING (
        user_id = COALESCE(current_setting('app.current_user_id', TRUE), '00000000-0000-0000-0000-000000000000')::UUID
        OR current_setting('app.user_role', TRUE) = 'admin'
    );

-- Bookings: User sees own, admin sees all
DROP POLICY IF EXISTS booking_isolation ON bookings;
CREATE POLICY booking_isolation ON bookings
    FOR ALL
    USING (
        user_id = COALESCE(current_setting('app.current_user_id', TRUE), '00000000-0000-0000-0000-000000000000')::UUID
        OR current_setting('app.user_role', TRUE) = 'admin'
    );

-- Chat messages: Access via session ownership
DROP POLICY IF EXISTS chat_message_isolation ON chat_messages;
CREATE POLICY chat_message_isolation ON chat_messages
    FOR ALL
    USING (
        session_id IN (
            SELECT id FROM chat_sessions 
            WHERE user_id = COALESCE(current_setting('app.current_user_id', TRUE), '00000000-0000-0000-0000-000000000000')::UUID
        )
        OR current_setting('app.user_role', TRUE) = 'admin'
    );

-- OAuth accounts: Only own accounts
DROP POLICY IF EXISTS oauth_isolation ON oauth_accounts;
CREATE POLICY oauth_isolation ON oauth_accounts
    FOR ALL
    USING (
        user_id = COALESCE(current_setting('app.current_user_id', TRUE), '00000000-0000-0000-0000-000000000000')::UUID
        OR current_setting('app.user_role', TRUE) = 'admin'
    );

-- Enable RLS on all user-facing tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_accounts ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owner (important!)
ALTER TABLE users FORCE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE chat_messages FORCE ROW LEVEL SECURITY;
ALTER TABLE bookings FORCE ROW LEVEL SECURITY;
ALTER TABLE booking_items FORCE ROW LEVEL SECURITY;
ALTER TABLE oauth_accounts FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. AUDIT LOGGING (Optional - track data changes)
-- ============================================================================

-- Enable audit extension if available
-- CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Or use simple trigger-based audit
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL, -- INSERT, UPDATE, DELETE
    old_data JSONB,
    new_data JSONB,
    changed_by UUID,
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for efficient querying
CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_changed_at ON audit_log(changed_at DESC);

-- Grant permissions
GRANT INSERT ON audit_log TO gth_app;
GRANT SELECT ON audit_log TO gth_admin;
