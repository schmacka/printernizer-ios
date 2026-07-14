# Printernizer iOS Modernization Plan

> **Status (July 2026): executed.** All phases below are implemented on this branch. The API contract was verified against the backend source (~v2.42.0) rather than a live instance; notable corrections found during execution: the WebSocket path `/ws` was already correct (the docs were wrong), `/api/v1/system/health` never existed (now `/api/v1/health`), the snapshot download path was wrong, and `MaterialStats` decoded fields the backend doesn't send. Only `printer_status` events are actually pushed over WebSocket by current backends, so notifications and live updates are driven from those. Deliberately deferred: camera diagnostics endpoint (response schema not stable enough to bind), triggering slicing from the app, timelapses, orders/analytics.

**Goal:** Bring the iOS companion app up to date with the current Printernizer backend release (v2.41.x, July 2026) and restore the feature parity the app was designed for.

**Status baseline:** The app currently targets a backend API surface from roughly the v2.1x era. The backend has since shipped ~25 minor releases, including a Library system that supersedes the Files API, slicer integration, tags, a reworked jobs response, and new system-info endpoints. In addition, several parts of the app are wired incompletely (WebSocket never connected, refresh-interval setting unused).

---

## Phase 0 — Ground truth & foundations

Before changing features, verify the actual API contract and remove structural drift.

1. **Verify against the live backend OpenAPI spec.** The backend (FastAPI) serves `/docs` and `/openapi.json`. Every endpoint/DTO change below should be confirmed against a running v2.41.x instance rather than the changelog alone. Known open questions:
   - WebSocket path: iOS code uses `/ws`, this repo's CLAUDE.md says `/api/v1/ws`, backend README says `ws://host:8000/ws`. Confirm and fix one way.
   - Temperature payload shapes: printer list uses flat `{bed, nozzle}` while printer details use nested `{current, target}` readings. Confirm both against current schema.
2. **Centralize the API base path.** The string `v1` is hardcoded in every service (`APIService`, `CameraService`, `JobService`, `FileService`, `MaterialService`). Introduce a single `APIConfiguration` (base URL + `/api/v1` prefix + shared `JSONDecoder`/`JSONEncoder` with snake_case strategies) that all services consume.
3. **Update project docs.** Refresh `CLAUDE.md` (endpoints, WebSocket path) as part of each phase so it stays truthful.
4. **CI/toolchain refresh.**
   - CI pins macOS 14 + Xcode 15.2 + iPhone 15 / iOS 17.2 simulator. Move to a current macOS runner, recent Xcode, and current iOS simulator.
   - Read app version/build from the bundle in `SettingsView` instead of the hardcoded `"1.0.0"` / `"1"` strings; bump `MARKETING_VERSION` when the modernization ships.
   - Fix the About link (`https://github.com/printernizer` → the real repo).

## Phase 1 — Fix what's broken or stale against today's API

1. **Wire up `WebSocketService`.** The service is fully implemented but never instantiated anywhere — real-time updates are dead code and the UI relies on pull-to-refresh. Connect it at app root (alongside `APIService`), subscribe from printer list/detail, and drive `printer_status` / `job_update` / `system_event` into the view models. Add handling for newer event types (`job_auto_created`, `slicing_completed`, `slicing_failed`).
2. **Reconcile `JobResponse` with the current jobs API.**
   - `GET /api/v1/jobs` now returns a structured `{jobs: [...], total: N}` envelope — verify the app's pagination decoding matches.
   - Collapse the duplicated legacy fields (`progress` vs `progressPercent`, `startTime` vs `startedAt`, `materialCost`/`powerCost` vs `costEur`) to whatever the current schema actually emits.
   - Map auto-created jobs (v2.41.6 behavior: `status: "running"`, discovery-time fallback for start time) so they don't render as "not started".
3. **Honor the `refreshInterval` setting.** It's persisted in Settings but nothing reads it; `CameraPreviewView` hardcodes 3 s. Use it for polling fallback (when WebSocket is disconnected) and camera auto-refresh.
4. **Remove or implement `homeAxes`.** Currently a stub throwing 501 with no backend counterpart; delete it unless the current backend added a home endpoint.
5. **Use the new system endpoints.**
   - Switch connection test / add an "About server" section using `GET /api/v1/system/info` (v2.41.7: version, environment, timezone, DB size, uptime). Keep `/api/v1/system/health` as the cheap reachability check if it still exists.
   - Surface the backend version in Settings so users can see client/server compatibility at a glance.

## Phase 2 — Files → Library migration (largest work item)

The backend's unified Library (v2.40.0+) supersedes the general Files API the app uses today.

1. **New `LibraryService` + models.** Checksum-keyed files with `role` (`model` | `printfile`), `parent_checksum`, and `analysis_error` fields (v2.41.1). Endpoints:
   - `GET /api/v1/library/files` (listing/filtering)
   - `GET /api/v1/library/files/{checksum}/download`
   - `GET /api/v1/library/files/{checksum}/printfiles` — derived print files enriched with slicing job details
   - `POST /api/v1/library/files/{checksum}/print` — send to printer and start
2. **Rework the Files tab into a Library tab.** Model-centric detail view (mirroring the web app's v2.41.5 redesign): metadata, thumbnail, derived print files with printer/profile names, Download and Delete actions, and a "Print" action targeting a selected printer.
3. **Keep watch-folder/source context.** Preserve source badges (printer / upload / watch_folder / library) and thumbnail support; add `.bgcode` awareness (v2.42.0).
4. **Migration strategy.** Confirm whether legacy `/api/v1/files` endpoints still respond on v2.41.x. If yes, ship LibraryService alongside and switch the tab over; if no, this phase is a prerequisite for the app working at all against current backends and should be prioritized accordingly.

## Phase 3 — New backend features worth parity

Ordered by expected user value for a mobile companion:

1. **Slicing (v2.38–2.41).** Read-only first: show slicing profiles (`GET /api/v1/slicing/...`), display slicing status on library print files, and handle `slicing_completed`/`slicing_failed` WebSocket events with local notifications. Triggering slicing from mobile is a stretch goal.
2. **Tags (v2.15+).** Show file tags in the Library tab; add tag-based search (`POST /api/v1/tags/search/files`).
3. **Materials export.** Expose `GET /api/v1/materials/export?format=excel` via a Share Sheet (also ticks off the "Share Sheet" future-feature item).
4. **Camera diagnostics.** Use `GET /api/v1/printers/{id}/camera/diagnostics` (v2.11.7) to give actionable errors when the preview fails, and keep supporting `external-preview` (already implemented).
5. **Printer test-connection.** Use `POST /api/v1/printers/test-connection` (v2.11.0) in Settings/setup flow to validate before saving.

**Explicitly out of scope for this pass** (business/desktop-oriented; revisit later): Orders & customers API, analytics dashboards (`/api/v1/analytics/*`), log viewer, notification channel management (Discord/Slack/ntfy), timelapse management, and the browser-based model generator (JSCAD, deliberately client-web-only since v2.34).

## Phase 4 — App-side polish & lifecycle

1. **Make notification toggles functional.** Settings toggles (print completed/failed, printer offline) are persisted but nothing consumes them. Back them with local notifications driven by WebSocket events while the app runs; true push notifications remain a future feature requiring backend support.
2. **State handling.** Consistent loading/empty/error states across tabs; offline banner driven by WebSocket connection state.
3. **Tests.** Extend `PrinternizerTests` to cover: Library DTO decoding (role/parent_checksum/analysis_error), new jobs envelope, WebSocket message decoding for new event types, and the status-mapping tables.
4. **Release hygiene.** Version bump, changelog for the app, updated screenshots/README.

---

## Suggested sequencing & risk

| Order | Work | Risk if skipped |
|-------|------|-----------------|
| 1 | Phase 0 (verify contract, centralize config, CI) | Building on wrong assumptions; every later phase touches the hardcoded paths |
| 2 | Phase 2 (Library migration) | Files tab may be broken against current backends already |
| 3 | Phase 1 (WebSocket, jobs reconciliation) | App works but feels stale; job statuses render wrong |
| 4 | Phase 3 (feature parity) | Missing functionality, not breakage |
| 5 | Phase 4 (polish) | Quality-of-life |

The single most important early step is Phase 0.1: pulling `openapi.json` from a live v2.41.x backend and diffing it against the DTOs in `Sources/Services/*.swift`. Everything in this plan that came from release notes should be treated as provisional until confirmed there.
