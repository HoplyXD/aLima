# aLima Backend

Node/Express proxy that sits between the Godot client and external services
(scanner cache, Portal API, buyer-banter LLMs). All secrets live here; the
Godot client only calls `{backend_url}/api/*`.

## Quick start

```powershell
Push-Location server
npm install
Copy-Item .env.example .env   # edit .env locally; NEVER commit .env
npm run dev                   # starts on PORT (default 3000)
Pop-Location
```

For a full local stack, also run the mock Portal:

```powershell
Push-Location mock-portal
npm install
npm start                 # default port 3001
Pop-Location
```

Then point the server at it in `server/.env`:

```text
PORTAL_BASE_URL=http://localhost:3001
```

## Environment variables

See `server/.env.example` for the full list. Key variables:

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | 3000 | HTTP port for the backend |
| `PORTAL_BASE_URL` | http://localhost:3001 | Upstream Portal (mock or live) |
| `PORTAL_TIMEOUT_MS` | 5000 | Portal request timeout |
| `SCAN_CACHE_PATH` | ./data/scanner_cache.json | Cached scanner responses |
| `PORTAL_CACHE_PATH` | ./cache/portal_cache.json | Cached Portal discovery responses |
| `MUSEUM_CACHE_PATH` | ./cache/museum_cache.json | Cached museum records |
| `RATE_LIMIT_SCAN` | 30 | Requests per 15 min for `/api/scan` |
| `RATE_LIMIT_PORTAL` | 10 | Requests per 15 min for `/api/portal/*` |
| `RATE_LIMIT_MUSEUM` | 20 | Requests per 15 min for `/api/portal/museum` |
| `RATE_LIMIT_NEGOTIATE` | 20 | Requests per 15 min for `/api/negotiate` |
| `LLM_PROVIDER` | anthropic | `anthropic`, `local`, or `auto` |
| `ANTHROPIC_API_KEY` | (blank) | Cloud Claude key (server-side only) |
| `LOCAL_LLM_URL` | http://localhost:11434/v1/chat/completions | Ollama-compatible endpoint |

## Endpoints

### Scanner

- `POST /api/scan` — return a cached scanner response for a template/condition.

### Portal proxy

- `POST /api/portal/discovery` — proxy fragment discovery to the Portal; returns
  a fact card. Idempotent per `player_id:fragment_id`.
- `POST /api/portal/museum` — record a Gold discovery or Master Artifact assembly
  in the Portal. Idempotent per `player_id:artifact_id`.
- `GET /api/portal/museum?player_id=...` — list this player's museum entries.
- `GET /api/portal/museum/:id?player_id=...` — get one museum entry by id.

All Portal endpoints validate inputs, enforce per-route rate limits, time out
after `PORTAL_TIMEOUT_MS`, and fall back to deterministic cached/local records
when the upstream Portal is unreachable or returns a malformed response.

### Buyer banter

- `GET /api/negotiate/status` — quick liveness check.
- `POST /api/negotiate` — persona-driven buyer reply with contextual moderation.
  Falls back to deterministic offline banter when no provider is usable.

## Testing

```powershell
Push-Location server
npm test        # runs Jest with --runInBand --forceExit
Pop-Location
```

As of 2026-07-11 the suite passes `33/34`; the single failure is a pre-existing
`negotiate.test.js` fallback-flag test that expects `fallback: true` when no API
key is configured but currently receives `fallback: false`. It is unrelated to
the museum work.

## Live Portal integration

To verify against a live City-Wide Portal endpoint:

1. Obtain the real `PORTAL_BASE_URL` and any required API-key/header contract.
2. Set them in `server/.env` (do not commit the file).
3. Run `server/npm test` and the Godot portal/museum GUT suites.
4. Confirm idempotency, timeout recovery, and malformed-response fallback still
   behave correctly with the live upstream.

Mock-only or cache-only behavior does **not** satisfy full-game completion
(see `CLAUDE.md` §4-O).

## Layout

```text
server/
├── src/
│   ├── app.js                 # Express app + middleware wiring
│   ├── index.js               # entry point
│   ├── config.js              # env loading + defaults
│   ├── middleware/
│   │   ├── rate_limiter.js    # per-route rate limits
│   │   └── validate.js        # request validators
│   ├── routes/
│   │   ├── scan.js            # POST /api/scan
│   │   ├── portal.js          # /api/portal/* discovery + museum
│   │   └── negotiate.js       # POST /api/negotiate
│   └── services/
│       ├── scan_service.js    # cached scanner lookup
│       ├── portal_service.js  # Portal proxy + fallback + museum
│       └── negotiate_service.js # LLM banter + fallback
├── tests/                     # Jest suites
├── data/                      # fixture/cache data
├── cache/                     # runtime cache (gitignored)
└── .env.example               # template; copy to .env
```
