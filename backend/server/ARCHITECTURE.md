# Backend Architecture Rules

## Layering
- `controller`: HTTP contract only (validation, mapping, status code).
- `application`: business use cases and orchestration.
- `repository`: data persistence abstraction and implementation.
- `domain`: pure domain types and rules (no framework dependency).
- `common`: cross-cutting concerns (error code, guard, response envelope).

## Readability Rules
- One responsibility per class/file.
- No business logic inside controllers.
- Use explicit DTOs for request/response.
- Use typed enums/constants for status and error codes.
- Keep method names verb-first (`sendOtp`, `verifyOtp`, `updateProfile`).

## Current Phase
- Phase B scaffold: Auth + Users + Settings
- Storage adapters:
  - User/Settings: `memory` or `postgres` (switch by `USER_STORE_DRIVER`)
  - OTP/Session: `memory` or `redis` (switch by `AUTH_RUNTIME_DRIVER`)
