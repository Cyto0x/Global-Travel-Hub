-- ============================================================================
-- GLOBAL TRAVEL HUB - SECURITY VERIFICATION CHECKS
-- Run after init.sql + security.sql are applied
-- ============================================================================

-- 1) Roles exist and are not superusers
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb
FROM pg_roles
WHERE rolname IN ('gth_app', 'gth_readonly', 'gth_admin')
ORDER BY rolname;

-- 2) RLS enabled and forced on user-facing tables
SELECT relname, relrowsecurity AS rls_enabled, relforcerowsecurity AS rls_forced
FROM pg_class
WHERE relname IN ('users', 'chat_sessions', 'chat_messages', 'bookings', 'booking_items', 'oauth_accounts')
ORDER BY relname;

-- 3) Policies present on protected tables
SELECT tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('users', 'chat_sessions', 'chat_messages', 'bookings', 'oauth_accounts')
ORDER BY tablename, policyname;

-- 4) Check least privilege patterns on oauth_accounts access
SELECT
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'oauth_accounts'
ORDER BY grantee, privilege_type;

-- Column-level detail (should not show broad readonly token visibility)
SELECT
    grantee,
    privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name = 'oauth_accounts'
  AND column_name IN ('access_token', 'refresh_token')
ORDER BY grantee, column_name, privilege_type;

-- 5) Encryption helper functions and trigger exist
SELECT proname
FROM pg_proc
WHERE proname IN (
    'set_field_encryption_key',
    'encrypt_text_field',
    'decrypt_text_field',
    'encrypt_oauth_tokens_trigger'
)
ORDER BY proname;

SELECT tgname, tgrelid::regclass AS table_name, tgenabled
FROM pg_trigger
WHERE tgname = 'tr_encrypt_oauth_tokens';

-- 6) Token storage shape check (enc:: prefix expected when populated)
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE access_token IS NOT NULL) AS access_token_rows,
    COUNT(*) FILTER (WHERE access_token LIKE 'enc::%') AS encrypted_access_token_rows,
    COUNT(*) FILTER (WHERE refresh_token IS NOT NULL) AS refresh_token_rows,
    COUNT(*) FILTER (WHERE refresh_token LIKE 'enc::%') AS encrypted_refresh_token_rows
FROM oauth_accounts;
