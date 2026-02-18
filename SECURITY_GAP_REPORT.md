# Global Travel Hub - Security Gap Report (Database Scope)

Version: 1.0  
Assessment Date: February 18, 2026  
Reference Baseline: `SECURITY_PROTOCOL.md`

## 1. Executive Summary
Current status is **partially compliant** with the security protocol.  
Strong foundations exist (RLS script, role separation script, audit table, GDPR-oriented fields), but several controls are not enforced in the default runtime path.

Overall rating: **Partial**

## 2. Control-by-Control Status

| Control Area | Status | Evidence | Gap |
|---|---|---|---|
| Data classification defined | Pass | `SECURITY_PROTOCOL.md` | Implemented as policy; needs operational enforcement mapping in backend docs |
| PII encrypted at field level | Fail | `init.sql:21`, `init.sql:70`, `init.sql:71`, `init.sql:118` | PII/token/chat content stored in plaintext columns |
| Encryption extension available | Partial | `init.sql:8` | `pgcrypto` enabled but not used for protected columns |
| Backup encryption policy | Partial | `DESIGN_DOCUMENT.md` backup section | Backup frequency exists, encryption enforcement not explicit in deployable scripts |
| Least-privilege app role exists | Partial | `security.sql:11`, `security.sql:24`, `security.sql:25` | App role has broad CRUD on all tables |
| Separate admin role exists | Pass | `security.sql:17`, `security.sql:33` | Exists and separated logically |
| No superuser from app layer | Fail | `docker-compose.yml:8`, `docker-compose.yml:46` | Compose path uses `gth_user` account; app-role usage not enforced |
| RLS implemented for ownership | Partial | `security.sql:77`-`security.sql:139` | Strong in `security.sql`, but not auto-applied by default compose init |
| FORCE RLS enabled | Partial | `security.sql:133`-`security.sql:139` | Present in script, not guaranteed in startup flow |
| Redis authentication | Fail | `docker-compose.yml:32` | No password/ACL configured |
| Redis public exposure | Fail | `docker-compose.yml:29` | Exposed on host port `6379` |
| Redis TTL policy for sessions/chats | Partial | `DESIGN_DOCUMENT.md` Redis example uses `setex` | Pattern exists in docs, not enforced by infrastructure policy |
| Avoid raw PII in Redis | Fail | No enforceable rule in compose/scripts | No explicit protection gate for PII caching |
| Security role script integrated into init path | Fail | `docker-compose.yml:15`-`docker-compose.yml:16` | `security.sql` not mounted in docker-entrypoint init scripts |
| Audit structure available | Partial | `security.sql:149`-`security.sql:166` | Audit table exists, but no change triggers wired to protected tables |

## 3. Key Risk Findings (Top 6)
1. **High:** Sensitive values are stored plaintext (email, tokens, chat content).
2. **High:** Redis is exposed and unauthenticated.
3. **High:** Security script is not part of default compose bootstrap.
4. **High:** Runtime identity/connection is not provably least privilege in compose defaults.
5. **Medium:** RLS is defined but not consistently guaranteed in effective runtime path.
6. **Medium:** Backup process exists, but encryption/control evidence is incomplete.

## 4. Immediate Compliance Delta
To reach protocol-aligned MVP compliance without redesign:
- Integrate `security.sql` into bootstrap path.
- Enforce least-privileged runtime credentials.
- Secure Redis (auth + private network scope).
- Add token/PII encryption handling path in backend write/read flow.
- Add explicit encrypted-backup control and restore test evidence.

## 5. Current Readiness Decision
Decision: **Not ready for security sign-off yet**  
Reason: Mandatory controls for encryption, runtime least privilege, and Redis hardening are not fully enforced by default deployment path.
