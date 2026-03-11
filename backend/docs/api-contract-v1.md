# API Contract v1 (Draft)

## Base
- Base URL: `/api/v1`
- Auth: `Authorization: Bearer <access_token>`
- Time: ISO-8601 UTC
- Idempotency header for write APIs: `X-Idempotency-Key`

## Auth
- `POST /auth/otp/send`
  - request: `{ "phone": "13800138000" }`
  - response: `{ "request_id": "otp_xxx", "expire_seconds": 60 }`
- `POST /auth/otp/verify`
  - request: `{ "phone": "13800138000", "code": "123456", "request_id": "otp_xxx" }`
  - response: `{ "access_token": "...", "refresh_token": "...", "user": { "user_id": "...", "uid": "SNXXXXXX1234" } }`
- `POST /auth/refresh`
  - request: `{ "refresh_token": "..." }`
  - response: `{ "access_token": "...", "refresh_token": "..." }`
- `POST /auth/logout`
  - request: `{ "device_id": "..." }`

## Profile
- `GET /users/me`
- `PATCH /users/me`
  - mutable fields: `nickname`, `signature`, `status`
- `POST /users/me/avatar/upload-token`
- `POST /users/me/background/upload-token`

## UID Search + Social
- `GET /users/search?uid=SNF0A101`
- `POST /friends/requests`
  - request: `{ "target_user_id": "...", "message": "你好" }`
- `POST /friends/requests/{request_id}/accept`
- `POST /friends/requests/{request_id}/reject`
- `POST /friends/{user_id}/unfollow`
- `POST /friends/{user_id}/block`
- `DELETE /friends/{user_id}/block`
- `GET /friends`
- `GET /friends/requests/pending`
- `GET /users/blocked`

## Match
- `POST /match/start`
  - request: `{ "location": { "lat": 0, "lng": 0 }, "exclude_user_ids": [] }`
  - response: `{ "match_id": "...", "user": {...}, "thread_id": "..." }`
- `POST /match/cancel`
- `GET /match/quota`

## Chat
- `GET /threads`
- `POST /threads/direct`
  - request: `{ "targetUserId": "..." }`
- `GET /threads/{thread_id}/messages?cursor=...&limit=30`
- `POST /threads/{thread_id}/messages/text`
  - request: `{ "content": "hello", "client_msg_id": "..." }`
- `POST /threads/{thread_id}/messages/image`
  - request: `{ "image_key": "...", "burn_after_reading": true, "burn_seconds": 5, "client_msg_id": "..." }`
- `POST /threads/{thread_id}/read`
  - request: `{ "last_read_message_id": "..." }`
- `DELETE /threads/{thread_id}`
- `POST /messages/{message_id}/recall`

## Policy + Intimacy
- `GET /threads/{thread_id}/policy`
  - response: unlock flags + remaining score/time
- `GET /threads/{thread_id}/intimacy`
- `POST /threads/{thread_id}/intimacy/events`
  - server-side events preferred; client only for explicit actions (view burn image etc.)

## WebSocket Events
- Namespace: `/ws`
- Client -> Server:
  - `thread.join`
  - `msg.send.text`
  - `msg.send.image`
  - `msg.read`
  - `typing`
- Server -> Client:
  - `msg.ack`
  - `msg.new`
  - `msg.read_by_peer`
  - `thread.updated`
  - `policy.updated`
  - `error`

## Critical Compatibility Rules
- `is_read` must mean peer-read, not local-open.
- Burn image must auto-destroy at first view end or max 5s.
- Blocked user must not appear in match/search until unblock.
- Stranger unblocked thread visibility window is 1 day unless mutual follow established.
