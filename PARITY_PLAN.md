# Web-App Feature Parity Plan

Goal: bring Printernizer iOS as close as possible to the Printernizer web app
(`/projects/printernizer-repos/printernizer` — FastAPI backend + JS SPA).

Work through phases **in order**. Each phase must build (`xcodebuild -scheme Printernizer -configuration Debug build`) and pass tests before checking it off. Follow existing patterns: `APIConfiguration` for all URLs/coders, per-view domain services modeled on `MaterialService`, `@MainActor` ViewModels, all-optional Codable DTO fields with `static .preview`, snake_case handled by the shared coders. Never hardcode API paths.

## Phase 1.0 — Navigation redesign
- [x] Restructure `Sources/App/ContentView.swift` tabs: **Dashboard, Printers, Jobs, Library, More**
- [x] `Views/More/MoreView.swift`: `NavigationStack` + `List` of `NavigationLink`s (Materials, Settings now; later rows added per phase). Use `enum AppTab` + `enum MoreDestination: Hashable`
- [x] `Views/Dashboard/DashboardView.swift` stub (filled in Phase 1.2)

Note: `MaterialListView` and `SettingsView` no longer own a `NavigationStack` — they are pushed destinations; MoreView provides the stack. Build verification pending on macOS (no Xcode toolchain in this environment).

## Phase 1.1 — Printer management CRUD + discovery
Endpoints: `POST /printers`, `PUT/DELETE /printers/{id}`, `GET /printers/discover`, `GET /printers/discover/interfaces`, `POST /printers/test-connection`, `POST /printers/{id}/{connect,disconnect,download-current-job}`, `POST /printers/{id}/monitoring/{start,stop}`
- [x] New `Services/PrinterService.swift` (CRUD + discovery + controls; `PrinterCreateRequest`, `PrinterUpdateRequest`, `DiscoveredPrinter` DTOs)
- [x] `Views/Printer/PrinterFormView.swift` — shared create/edit form (type picker; per-type fields: Bambu access code+serial, Prusa API key, external webcam URL; `SecureField` for secrets; Test Connection button). Mirror field logic from web `frontend/js/printer-form.js`
- [x] `Views/Printer/PrinterDiscoveryView.swift` — interface picker, scan w/ progress, tap result → prefilled form
- [x] `PrinterListView`: toolbar + menu (add/discover), delete via context menu w/ confirmation (card list uses ScrollView, not List, so no swipe actions)
- [x] `PrinterDetailView`: Edit sheet, connect/disconnect, download-current-job, statistics grid + recent jobs sections (recent jobs now surfaced through `PrinterDetails`)

Note: monitoring start/stop deferred — backend auto-monitors connected printers; connect/disconnect covers the practical need. DTO decode/encode tests added in `PrinterServiceModelTests`.

## Phase 1.2 — Dashboard
Endpoints: `GET /analytics/overview`, `GET /printers`, `GET /jobs?limit=5`, `GET /files/statistics`
- [x] `Services/AnalyticsService.swift` (overview/summary/business, all-optional DTOs, period picker support)
- [x] `ViewModels/DashboardViewModel.swift` — composes analytics + printers + recent jobs; consumes WS `printer_status` and `job_update` (refreshes recent jobs)
- [x] `Views/Dashboard/DashboardView.swift` — stat tiles (printers online, jobs, completed, files), live printer cards (reuses `PrinterCardView` + `StatCard`), recent jobs (reuses `JobRowView`), period menu, WS + polling fallback

## Phase 1.3 — Materials CRUD + consumption
`MaterialService.createMaterial/updateMaterial/getTypes` already exist — UI only. Add service methods: `POST /materials/consumption`, `GET /materials/consumption/history`, `GET /materials/report`
- [x] `Sources/Utilities/Formatters.swift` — shared EUR `NumberFormatter`, ISO8601 date helpers, duration/weight formatters
- [x] `Views/Materials/MaterialFormView.swift` — create/edit sheet; pickers fed by `getTypes()`; `ColorPicker` → hex; edit mode restricted to backend-updatable fields
- [x] `MaterialListView`: toolbar + (add), consumption history entry, low-stock filter
- [x] `MaterialDetailView`: Edit button, Record Consumption sheet (job picker), per-material history link
- [x] `Views/Materials/ConsumptionHistoryView.swift` + `RecordConsumptionView.swift`

Fixed along the way: `MaterialStats` DTO never decoded against the real backend (`low_stock` is a list of IDs, `by_type` is nested) so the stats header was always empty; weights are kilograms per backend contract, display updated accordingly. `MaterialCreateRequest` was missing the required `remaining_weight`.

## Phase 1.4 — Business: job creation + Orders/Customers
Endpoints: `POST /jobs`, `PUT/DELETE /jobs/{id}`, `GET /jobs/export`; `/orders` CRUD + `POST/DELETE /orders/{id}/jobs[/{job_id}]` + `/orders/{id}/files[/{order_file_id}]`; `/customers` CRUD; `/order-sources` CRUD
- [ ] Extend `JobService`: createJob (is_business, customer, costs), updateJob, deleteJob, exportJobs (temp-file + share sheet — copy `MaterialService.exportMaterials` pattern)
- [ ] `Views/Jobs/JobFormView.swift` — business toggle → customer field, cost preview (display backend-computed EUR/VAT only, never recompute client-side; use `Formatters.eur`)
- [ ] `JobListView`: segmented **Jobs | Orders**; surface existing `printer_id`/`is_business` filters
- [ ] `Services/OrderService.swift` (orders, customers, order-sources; DTOs from backend `src/models/order.py`)
- [ ] `Views/Orders/OrderListView.swift` (status filter new/planned/printed/delivered), `OrderDetailView.swift` (advance status, linked jobs/files w/ unlink, attach-library-file picker reusing library rows), `OrderFormView.swift`, `CustomerListView.swift`, `OrderSourcesView.swift`

## Phase 1.5 — Generator (WKWebView)
Native JSCAD/three.js port is infeasible; embed the web page.
- [ ] `Views/Generator/GeneratorWebView.swift` — `UIViewRepresentable` `WKWebView` loading `{serverURL}/#generator`; loading/error states; inject CSS to hide web navbar if shown
- [ ] `Services/GeneratorService.swift` (`GET /generator/status`, `GET/POST /generator/presets`, `DELETE /generator/presets/{id}`)
- [ ] `Views/Generator/GeneratorPresetsView.swift` — native preset list + delete fallback
- [ ] Add Generator row to More

## Phase 2.1 — Ideas board
Endpoints: `/ideas` CRUD, `PATCH /ideas/{id}/status`, `POST /ideas/import`, `GET /ideas/tags/all`, `/ideas/stats/overview`, `GET /ideas/url/validate`, `POST /ideas/url/preview`, `GET /ideas/url/platforms`
- [ ] `Services/IdeaService.swift`
- [ ] `Views/Ideas/IdeaListView.swift` (segmented status filter idea/planned/printing/completed/archived; business/personal filter), `IdeaDetailView.swift`, `IdeaFormView.swift` (paste URL → `/ideas/url/preview` auto-fill)
- [ ] Add Ideas row to More

## Phase 2.2 — Library power features (upload, tags, slicing)
Endpoints: `POST /files/upload` (multipart), `POST /library/files/{checksum}/reprocess`, `GET /library/statistics`; `/tags` CRUD + assign/remove; `GET /slicing`, `GET /slicing/{id}/profiles`, `POST /slicing/library/{checksum}/slice`, `POST /slicing/slice-and-print`, `GET /slicing/jobs/{id}`
- [ ] `MultipartFormData` helper + `LibraryService.upload` via `fileImporter` (remember `startAccessingSecurityScopedResource`)
- [ ] `Services/TagService.swift`; editable tag chips in `LibraryFileDetailView` (create/assign/remove)
- [ ] `Services/SlicingService.swift`; Slice action in file detail → profile picker → poll `/slicing/jobs/{id}` with progress sheet; Slice & Print
- [ ] Surface existing `listFiles(fileType:sourceType:hasThumbnail:)` filters as a filter sheet; reprocess button; `LibraryStatsView`

## Phase 2.3 — Timelapses
Endpoints: `GET /timelapses`, `/timelapses/stats`, `GET /timelapses/{id}/video`, `POST /{id}/process`, `DELETE /{id}`, `PATCH /{id}/{link,pin}`, `POST /timelapses/bulk-delete`
- [ ] `Services/TimelapseService.swift`
- [ ] `Views/Timelapses/TimelapseListView.swift` (grid, multi-select bulk delete, pin/link actions), `TimelapsePlayerView.swift` (`VideoPlayer` + `AVPlayer` on the absolute video URL via `APIConfiguration.url`; verify ATS/local-networking in Info.plist)
- [ ] Add Timelapses row to More

## Phase 3 — Long tail (in order; each independently shippable)
- [ ] 3.1 Files & downloads: `Services/FileService.swift`, `Views/Files/` — `GET /files`, download w/ `/downloads/{id}/progress` polling, watch-folder list/add/remove, G-code analysis view
- [ ] 3.2 Settings management: `Services/SettingsService.swift` — `GET/PUT /settings/application` form, gcode-optimization, ffmpeg-check row
- [ ] 3.3 Notification channels: `/notifications` CRUD + test (Discord/Slack/ntfy) as Settings subscreen (keep local `NotificationService` untouched)
- [ ] 3.4 Search: `GET /search` + suggestions + history — searchable screen in More
- [ ] 3.5 Tools links + System (backup trigger, update-check, usage stats)
- [ ] 3.6 Debug/logs viewer (`GET/DELETE /logs/*`, `/debug/*`) behind developer-mode toggle
- [ ] 3.7 Camera extras: MJPEG stream parsing (fall back to snapshot polling), diagnostics screen, external webcam URL in printer form
- [ ] 3.8 Ideas share extension (separate target, App Group for server URL)
- [ ] 3.9 German localization pass (`String(localized:)` retrofit + de strings)

## Rules for every phase
1. Build gate: `xcodebuild -scheme Printernizer -configuration Debug build` must pass.
2. Tests: extend `PrinternizerTests` with DTO decode tests (JSON fixtures), formatter tests, enum-mapping tests; `xcodebuild -scheme Printernizer -configuration Debug test`.
3. Every new view gets `#Preview` with `.preview` fixtures.
4. New services use one shared `APIError` (in `APIService.swift`), not new per-service error enums.
5. Commit after each completed phase with a descriptive message; check the phase's boxes in this file in the same commit.
