# Sunliao Backend

## Purpose
- Replace current local/mock logic with production backend services.
- Keep existing Flutter UI and interaction flow unchanged.
- Support staged rollout: dev -> staging -> production.

## Scope (v1)
- Auth: phone login, token refresh, device session management.
- Profile: nickname/avatar/signature/background.
- Match: realtime matching and session creation.
- Chat: websocket messaging, read receipt, burn-after-reading image.
- Social: friend request, mutual follow, unfollow, block/unblock.
- Policy: intimacy scoring and capability unlock rules.

## Folder Structure
```
backend/
  README.md
  server/
    ARCHITECTURE.md
    src/
  docs/
    development-plan.md
    api-contract-v1.md
    error-codes.md
    phase-b-progress.md
  db/
    schema_v1.sql
  ops/
    docker-compose.yml
    .env.example
    env/
      staging.env.example
      production.env.example
    nginx/
      sunliao-api.conf.example
    deploy-checklist.md
```

## Execution Baseline
- Plan start date: 2026-03-05
- Planned first release window: 2026-04-30
- Client integration mode: keep old local providers, add remote repository layer progressively.

## Current Progress
- Phase A completed: plan/contract/schema/error codes.
- Phase B in progress: backend server scaffold for auth/profile/settings completed with clear layered structure.
