# Backend Development Plan (v1)

## 1) Goals
- Ship a deployable backend for app launch without breaking current UI/UX.
- Remove all core mock behaviors in Auth/Match/Chat/Friend/Profile flows.
- Reach production-ready baseline for stability, observability, and rollback.

## 2) Current Baseline (from Flutter code)
- `AuthProvider`: local code check + mock token.
- `MatchProvider`: local mock pool + local count.
- `ChatProvider`: local message store + simulated send/reply.
- `FriendProvider`: local friend/block/request state.
- `ProfileProvider`: local profile persistence.
- `Feature unlock`: intimacy score + duration checks are local.

## 3) Architecture Decisions
- API service: NestJS (TypeScript) + REST + WebSocket gateway.
- DB: PostgreSQL (source of truth).
- Cache/session/rate-limit: Redis.
- Object storage: S3-compatible bucket (avatar/background/chat image).
- Reverse proxy: Nginx.
- Deploy: Docker Compose (staging), Kubernetes optional (production phase 2).

## 4) Phased Delivery

## Phase A: Contract + Data Model (2026-03-05 -> 2026-03-09)
- Freeze backend domain model and state machine.
- Output:
  - API contract v1.
  - Error code catalog.
  - SQL schema v1 + indexes.
- Exit criteria:
  - Client and backend use identical field names and enums.
  - All major flows have deterministic state transitions.

## Phase B: Auth + Profile + Settings (2026-03-10 -> 2026-03-16)
- Implement:
  - Phone OTP send/verify.
  - Access token + refresh token.
  - UID generation and uniqueness guarantee.
  - Profile CRUD, avatar/background upload token.
  - Settings sync (notification, vibration, theme mode flags).
- Exit criteria:
  - Reinstall requires login.
  - Token refresh and logout invalidation pass tests.

## Phase C: Social Graph (2026-03-17 -> 2026-03-23)
- Implement:
  - UID search.
  - Friend request, accept/reject.
  - Mutual follow/unfollow.
  - Block/unblock with recovery constraints.
- Exit criteria:
  - Blocked users cannot be matched or searched.
  - Unblock behavior matches product rules for friend/stranger.

## Phase D: Match + Chat Realtime (2026-03-24 -> 2026-04-06)
- Implement:
  - Matching queue and candidate filtering.
  - Conversation creation/expiry.
  - Text/image message send, delivery ack, read receipt.
  - Thread list unread counters and pagination.
  - Burn-after-reading image lifecycle (press-to-view + 5s max + destroy).
- Exit criteria:
  - End-to-end message state is consistent across two clients.
  - Read status means peer-read only.

## Phase E: Policy Engine + Voice Gate (2026-04-07 -> 2026-04-13)
- Implement:
  - Intimacy accumulation events.
  - Stage-1 unlock (profile view/background/tabs).
  - Stage-2 unlock (mutual follow + voice permission).
  - Central `FeaturePolicy` evaluation API.
- Exit criteria:
  - Policy is server-authoritative and configurable.
  - Unlock prompts include exact remaining requirement.

## Phase F: Hardening + Launch Prep (2026-04-14 -> 2026-04-30)
- Implement:
  - Observability dashboards (latency/error/online users/message lag).
  - Load testing and security hardening.
  - Data backup, migration rollback scripts.
  - Blue/green release and emergency rollback.
- Exit criteria:
  - P95 API latency < 300ms (core APIs).
  - Message delivery success >= 99.95%.
  - Zero P0 defects in launch checklist.

## 5) Testing Strategy
- Unit tests: domain services, policy engine, state transitions.
- Integration tests: auth, friendship, block/unblock, message read flow.
- E2E tests: two-client chat and match scenarios.
- Performance:
  - Match API concurrency test.
  - WebSocket fan-out test.
  - DB index hit-ratio and slow query review.

## 6) Release Gates
- Gate 1: Contract sign-off.
- Gate 2: Staging completion with client real API switch.
- Gate 3: Production canary (5% traffic, 24h).
- Gate 4: Full rollout + post-release verification.

## 7) Immediate Tasks (this week)
1. Create backend service repo skeleton and CI pipeline.
2. Implement auth/profile endpoints first.
3. Add DB migration framework and apply schema_v1.
4. Provide mock-compatible response adapters for current Flutter providers.

