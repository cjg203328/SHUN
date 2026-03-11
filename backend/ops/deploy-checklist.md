# Deployment Checklist

## Pre-Deploy
- Ensure `.env` values are complete and secrets are replaced.
- Ensure PostgreSQL and Redis are reachable from app host.
- Run DB migration:
  - `npm run db:migrate:check`
  - `npm run db:migrate`
- Build verification:
  - `npm run build`
  - `npm run test:integration`

## Deploy
- Start/Restart API service.
- Confirm health with:
  - `GET /api/v1/auth/otp/send` request validation behavior
  - `GET /api/docs` (staging only)

## Post-Deploy
- Check logs: request id appears for each request.
- Verify login/profile/settings flows from client.
- Monitor error rate and response latency for 30 minutes.

