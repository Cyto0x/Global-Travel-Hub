# Global Travel Hub - Security Protocol (Database Scope)

Version: 1.0  
Status: Approved baseline for MVP data layer  
Last Updated: February 18, 2026

## 1. Purpose
Define mandatory controls for protecting user data (PII), enforcing least privilege, and handling OAuth-related secrets in the Global Travel Hub database layer without redesigning the full schema.

## 2. Scope
This protocol applies to:
- PostgreSQL schema and roles
- Redis usage for chat/session/cache
- OAuth token persistence patterns
- Backup, restore, and audit controls
- Docker-based local and staging environments

This protocol does not replace cloud/network security standards; it complements them.

## 3. Security Baseline Standards
The project adopts the following practical standards for MVP:
- OWASP ASVS Level 2
- CIS PostgreSQL hardening guidance
- CIS Docker/Container hardening guidance
- OAuth 2.0 / OpenID Connect security best practices
- NIST-aligned key management principles (centralized secrets, rotation, audit)

## 4. Data Classification
### 4.1 Restricted PII (highest protection)
- `users.email`
- `users.phone`
- `bookings.contact_email`
- `chat_messages.content` (may contain personal travel intent/details)
- OAuth secrets (`oauth_accounts.access_token`, `oauth_accounts.refresh_token`)

### 4.2 Sensitive Business Data
- `bookings.booking_reference`
- Payment and booking metadata
- IP address and user-agent fields

### 4.3 Internal Data
- Aggregated analytics metrics
- Non-PII operational metadata

## 5. Authentication and Identity Boundaries
- End-user authentication must be delegated to Auth0 or Firebase Auth (OIDC/OAuth provider).
- Database is not an identity provider.
- Backend/FastAPI and AI services must connect to PostgreSQL using least-privilege credentials only.
- Application components must not use PostgreSQL superuser credentials.

## 6. OAuth Token Management Policy
### 6.1 Storage Rules
- Preferred: do not store third-party access tokens unless required for background workflows.
- If storage is required:
- Encrypt tokens before storage (application-layer envelope encryption preferred).
- Store only minimal token metadata required for operations (provider, expiry, scope, token reference).
- Never expose raw token values in logs, traces, analytics tables, or admin dashboards.

### 6.2 Lifecycle Controls
- Respect provider expiry; expired tokens are unusable by policy.
- Rotate/refresh tokens according to provider requirements.
- Revoke and delete tokens when user disconnects provider or account is deleted.
- Purge stale tokens on a scheduled job.

### 6.3 Access Controls
- Only backend service account code path may decrypt/use tokens.
- Read access to token columns is denied to analytics/read-only roles.

## 7. Encryption Controls
### 7.1 Encryption at Rest
- PostgreSQL data volume encryption is mandatory (host/cloud disk encryption).
- Redis persistence volume encryption is mandatory when persistence is enabled.
- Backup artifacts must be encrypted with AES-256 equivalent controls.

### 7.2 Encryption in Transit
- TLS is required for PostgreSQL client connections in staging/production.
- TLS is required for Redis where network boundaries are not fully private.
- Plaintext DB traffic is only acceptable in isolated local development.

### 7.3 Field-Level Encryption
- Restricted PII and OAuth secrets must be encrypted at column-value level before persistence.
- Key material must never be committed to repository files.
- Keys are stored in secret manager/KMS and rotated on a defined schedule.

## 8. Least Privilege Role Model
The logical role model is:
- `application_role`: runtime CRUD only for required tables and operations
- `admin_role`: migration, maintenance, and incident response
- `readonly_role`: analytics/reporting only

Current repo role names (`gth_app`, `gth_admin`, `gth_readonly`) are accepted as implementation aliases as long as permissions map to this model.

Mandatory controls:
- Revoke broad/default privileges from `PUBLIC`.
- Separate migration role from runtime role.
- Runtime app and AI agent use least-privilege role only.
- No superuser role in application environment variables.

## 9. Row-Level Ownership Enforcement (RLS)
- User-owned tables must enforce per-user data access by `user_id`.
- RLS must be enabled and forced (`FORCE ROW LEVEL SECURITY`) on user-facing tables.
- Cross-user access must only be allowed for explicit admin context.
- Application must set user context at session/transaction start before queries.

Minimum covered entities:
- `users`
- `chat_sessions`
- `chat_messages`
- `bookings`
- `oauth_accounts`

## 10. Redis Security Protocol
- Redis authentication (password/ACL) is required.
- Redis service must not be publicly exposed in staging/production.
- TTL is mandatory for session/chat memory keys.
- Do not store raw PII in Redis unless strictly required and encrypted.
- Disable high-risk commands for non-admin Redis users where applicable.

## 11. Backup, Restore, and Retention
- Backup schedule must include full + incremental/WAL strategy.
- All backup files must be encrypted before offsite transfer/storage.
- Access to backup storage is restricted to admin/security roles.
- Restore verification test is required at least monthly and logged.

## 12. Auditing and Monitoring
Track and retain:
- Role grants/revokes and privileged logins
- Access to Restricted PII tables/columns
- Token decrypt/use operations (without logging token values)
- RLS bypass attempts and failed authorization
- Backup and restore operations

Logs must be immutable/tamper-evident in staging/production.

## 13. Secret Management
- Secrets (DB passwords, Redis credentials, encryption keys, OAuth client secrets) must come from environment/secret manager.
- Hardcoded credentials in SQL, compose files, or repository docs are prohibited for non-local environments.
- Rotate credentials on compromise, role changes, or at defined intervals.

## 14. Minimal-Change Implementation Plan (Current Repo Compatible)
1. Include `security.sql` in startup/init execution path.
2. Ensure backend and AI services use least-privilege app credentials only.
3. Enable Redis auth and remove public Redis exposure outside local development.
4. Enforce TLS for DB and Redis in staging/production.
5. Apply RLS coverage consistently across user-owned tables and force RLS.
6. Enforce encrypted backup policy and monthly restore test.
7. Document and implement token encryption/decryption path in backend service layer.

## 15. Compliance Checklist (MVP Gate)
- [ ] PII fields classified and documented
- [ ] OAuth token storage minimized and encrypted
- [ ] Least-privilege runtime role enforced
- [ ] No superuser credentials used by application layer
- [ ] RLS enabled + forced on user-owned tables
- [ ] Redis auth enabled and non-public in non-local environments
- [ ] TTL policy for session/chat keys implemented
- [ ] Encrypted backups enabled
- [ ] Monthly restore test evidence available
- [ ] Security review sign-off by Architecture & Security team

## 16. Ownership
- Security protocol owner: Architecture & Security team
- Runtime enforcement owner: Backend/AI team
- Schema and RLS enforcement owner: Data team
- Audit evidence owner: DevOps/SRE (or designated ops owner)
