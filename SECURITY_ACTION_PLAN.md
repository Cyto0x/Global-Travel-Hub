# Global Travel Hub - Security Action Plan (Minimal-Change)

Version: 1.0  
Date: February 18, 2026  
Goal: Close critical security gaps without redesigning the schema.

## 1. Prioritization Model
- **P0 (Blockers):** Must complete before security sign-off or external demo with real PII.
- **P1 (Hardening):** Complete immediately after P0 for stable production readiness.
- **P2 (Maturity):** Improves observability, governance, and long-term resilience.

## 2. P0 - Critical Controls (Do First)

### P0.1 Apply security bootstrap by default
- Action: Include `security.sql` in Docker init sequence after `init.sql`.
- Owner: Data Team
- Output: Containers always start with roles, grants, RLS policies, and FORCE RLS.
- Success Criteria: Fresh `docker-compose up` shows policies active on protected tables.

### P0.2 Enforce least-privilege runtime credentials
- Action: Ensure backend/AI runtime uses app role credentials only (not bootstrap/superuser account).
- Owner: Backend + Data Team
- Output: Separate bootstrap/admin credentials from runtime credentials.
- Success Criteria: App can function with app role; admin credentials are not in app runtime env.

### P0.3 Harden Redis access
- Action: Enable Redis auth (password/ACL) and remove public exposure outside local-only trusted setup.
- Owner: Backend/Infra
- Output: Redis reachable only through internal service network; authenticated clients only.
- Success Criteria: Unauthenticated Redis command is rejected.

### P0.4 Token and restricted PII handling policy in code path
- Action: Implement backend-only encryption/decryption path for OAuth tokens and restricted PII writes.
- Owner: Backend
- Output: No raw tokens in logs; encrypted persistence for required stored secrets.
- Success Criteria: Stored secrets are unreadable plaintext at rest in DB dumps.

### P0.5 Backup encryption requirement
- Action: Define and enforce encrypted backup target (disk/object-store encryption + restricted access).
- Owner: Infra/Security
- Output: Written backup runbook with encryption control and key ownership.
- Success Criteria: Backup artifacts verified encrypted and access-restricted.

## 3. P1 - Near-Term Hardening

### P1.1 Tighten grants by table/function
- Action: Reduce broad table-wide CRUD grants for app role to only required objects.
- Owner: Data Team
- Success Criteria: Privilege audit lists only operationally required grants.

### P1.2 Revoke default public privileges
- Action: Revoke permissive `PUBLIC` defaults and set explicit default privileges.
- Owner: Data Team
- Success Criteria: New objects are not unintentionally readable/writable by broad roles.

### P1.3 Enforce TLS for Postgres/Redis in non-local environments
- Action: Document and require TLS connection settings for staging/production.
- Owner: Infra/Backend
- Success Criteria: Non-local connection tests fail without TLS.

### P1.4 TTL policy for chat/session keys
- Action: Define mandatory TTL ranges and key naming standards for Redis.
- Owner: Backend
- Success Criteria: Session/chat keys auto-expire; no indefinite retention.

### P1.5 Data minimization in logs
- Action: Mask/tokenize PII in application logs and monitoring traces.
- Owner: Backend/Security
- Success Criteria: Log review confirms no raw restricted PII exposure.

## 4. P2 - Security Maturity

### P2.1 Add audit triggers on sensitive tables
- Action: Add INSERT/UPDATE/DELETE audit triggers for PII and token-related tables.
- Owner: Data Team
- Success Criteria: Audit entries created for sensitive data changes with actor/time context.

### P2.2 Automated security checks in CI
- Action: Add checks for insecure compose settings, missing RLS policy coverage, and secret leakage.
- Owner: Security/DevOps
- Success Criteria: CI fails when critical security controls regress.

### P2.3 Monthly restore exercise
- Action: Execute and document backup restore drill monthly.
- Owner: Infra/DBA
- Success Criteria: Signed restore report with RTO/RPO notes.

### P2.4 Key rotation runbook
- Action: Define rotation intervals for DB credentials, Redis credentials, and encryption keys.
- Owner: Security/Infra
- Success Criteria: Rotation tested end-to-end with no service outage.

## 5. Execution Timeline (Suggested)
- **Day 1:** P0.1, P0.2, P0.3
- **Day 2:** P0.4, P0.5
- **Day 3-4:** P1.1, P1.2, P1.4
- **Day 5:** P1.3, P1.5 + readiness review

## 6. Acceptance Gate for Security Sign-Off
Security sign-off can be requested once all P0 items are complete and evidenced with:
- Updated config/scripts
- Role/privilege verification queries
- RLS verification results
- Redis auth/network verification
- Backup encryption evidence

## 7. Suggested Owners by Team
- Data Team: bootstrap, grants, RLS, audit triggers
- Backend/AI Team: token handling, runtime credentials, TTL/log minimization
- Security/Architecture: control review, policy enforcement, sign-off
- Infra/DevOps: TLS, backup encryption, restore testing, CI security gates
