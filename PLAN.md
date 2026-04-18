# iOS ↔ Backend Integration Plan

Living document. Updated as we implement.

## Goal

Persist every completed scan session from the iOS POC into the Neon Postgres
database fronted by `POC_BodyMeasureAI-backend`. Admin UI reads from that DB,
so every scan becomes visible in the admin within seconds.

## Source of truth

- **iOS export shape:** `ScanSessionModel.exportJSON` (and `BodyScanResult.exportJSON`
  when no garment is attached) in
  [BodyMeasureAI/StylistA/Models](BodyMeasureAI/StylistA/Models).
- **Backend endpoint:** `POST /api/sessions` in
  `../POC_BodyMeasureAI-backend/src/app/api/sessions/route.ts`. Zod-validates
  the exact JSON shape above.
- **DB schema:** `../POC_BodyMeasureAI-backend/src/db/schema.ts` — Postgres
  tables + enums mirror the Swift models.

No schema translation in the app — we upload the existing JSON dict as-is.

## Architecture (thin-client)

```
FinalScanResultView  ──▶  AppCoordinator.uploadSession()
                              │
                              ▼
                       BackendAPIClient.upload(session:)
                              │  URLSession POST, JSON body
                              ▼
                 POST http://<host>/api/sessions  ◀─ configurable via
                                                    BackendConfig.baseURL
```

Fire-and-forget with a status signal on `AppCoordinator` so the results screen
can later render a “Synced / Failed” badge. No retry queue in POC — offline
uploads can be added later by buffering into `UserDefaults` or Core Data.

## Tasks

- [x] Draft this plan
- [x] `BackendConfig.swift` — DEBUG=localhost, RELEASE=Vercel URL, `BACKEND_BASE_URL` Info.plist override
- [x] `BackendAPIClient.swift` — `upload(session:)` and `upload(bodyOnly:)`
- [x] `AppCoordinator` — `@Published uploadStatus`, `uploadCompletedSession()`, `uploadBodyOnlyIfNeeded()`, per-session idempotency
- [x] `FinalScanResultView.onAppear` fires upload + `SyncStatusBadge` UI
- [x] `ResultsView.onAppear` fires body-only upload
- [x] `ContentView` injects `coordinator` as `@EnvironmentObject`
- [x] `Info.plist` — ATS exception for `localhost` (release uses HTTPS so no exception needed)
- [x] Backend deployed to Vercel: https://bodymeasureai-admin.vercel.app
- [x] `productionBaseURL` set to the Vercel URL
- [ ] Smoke test on simulator (DEBUG → localhost) and TestFlight (RELEASE → Vercel)
- [ ] Rotate Neon DB password (was leaked in chat earlier) and update `.env` + Vercel env

## Configuration

Base URL is resolved at runtime by `BackendConfig.swift`:

1. `BACKEND_BASE_URL` Info.plist key — optional per-scheme override (e.g. for
   staging or LAN-IP testing on a physical device).
2. Compile-time default:
   - **DEBUG builds** → `http://localhost:3000`
   - **RELEASE builds** → `productionBaseURL` constant in `BackendConfig.swift`
     (currently a `CHANGE_ME` placeholder — set before shipping).

The ATS exception in `Info.plist` only whitelists `localhost`, so production
HTTPS calls remain fully secured.

### Running the smoke test

1. In one terminal: `cd POC_BodyMeasureAI-backend && npm run dev` (ensure
   `.env` has the Neon `DATABASE_URL` from `npx neonctl@latest init`).
2. Build and run the iOS app in the **simulator** (localhost only works there).
3. Complete a scan and reach either `ResultsView` or `FinalScanResultView`.
   Watch the `SYNCING → SYNCED` badge.
4. Open http://localhost:3000/sessions — the row should be at the top.

### Physical device

`localhost` won't resolve. Either:

- Set `BACKEND_BASE_URL` in `Info.plist` (or scheme env vars) to your Mac's
  LAN IP, e.g. `http://192.168.1.42:3000`, AND add the same IP as an
  `NSExceptionDomains` entry in `Info.plist`.
- Or deploy the backend (Vercel + Neon) and point `BACKEND_BASE_URL` to the
  HTTPS URL — no ATS exception needed.

## Open questions / decisions deferred

- **Auth:** no API keys on the endpoint yet. Fine for local POC; add a
  simple bearer token before any real deployment.
- **Idempotency:** backend generates its own `sessionId` (ignoring the iOS UUID).
  Client can't safely retry without duplicating. If we add retry, switch
  to client-supplied UUID + `ON CONFLICT DO NOTHING` on the server.
- **Offline:** today the upload is fire-and-forget. For reliability, buffer
  failed payloads locally and replay on next launch.
- **Validation CSV:** `validation_entries` table exists but nothing uploads to
  it yet. ValidationModeView currently only produces a local CSV — separate
  endpoint + client method if we want it persisted.
