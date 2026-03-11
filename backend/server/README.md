# Sunliao Backend Server (Phase B Scaffold)

## Implemented Modules
- `auth`: otp send/verify, refresh token, logout.
- `users`: current user profile read/update, avatar/background upload-token + binary upload.
- `settings`: current user settings read/update.
- `friends`: uid search, friend request, accept/reject, block/unblock, blocked list.
- `match`: quota query, start/cancel match.
- `chat`: direct thread, message send, image upload-token stub, read receipt, recall, soft-delete thread.
- `chat-gateway`: websocket events for join/send/read/typing and ack push.

## Code Structure
```
src/
  common/                # cross-cutting
  modules/
    auth/
      controller/
      application/
      dto/
      domain/
    users/
      controller/
      application/
      dto/
    settings/
      controller/
      application/
      dto/
    shared/
      domain/
      repository/
```

## Run (after dependencies installed)
```bash
cd backend/server
npm install
npm run start:dev
```

## API Docs
- Swagger URL: `http://localhost:3000/api/docs`

## WebSocket
- Namespace: `/ws`
- Client events: `thread.join`, `msg.send.text`, `msg.send.image`, `msg.read`, `typing`
- Server events: `msg.ack`, `msg.new`, `msg.read_by_peer`, `thread.updated`

## Driver Switch
- `USER_STORE_DRIVER=memory|postgres` (default: `memory`)
- `AUTH_RUNTIME_DRIVER=memory|redis` (default: `memory`)

## Test
```bash
npm run test:integration
```

## DB Migration
```bash
npm run db:migrate:check
npm run db:migrate
```

## Notes
- Driver abstraction is ready. Use memory for local fast dev, then switch to postgres/redis in staging.
