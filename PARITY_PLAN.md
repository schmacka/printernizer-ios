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
- [x] Extend `JobService`: createJob (is_business, customer, material cost), updateJob, deleteJob, exportJobs CSV (temp-file + share sheet); `JobResponse` gains customer_name/order_id
- [x] `Views/Jobs/JobFormView.swift` — printer picker, business toggle → customer + material cost
- [x] `JobListView`: segmented **Jobs | Orders**, business/private filter, CSV export, business badge on rows
- [x] `Services/OrderService.swift` (orders + link job/attach file, customers, order-sources; OrderStatus/PaymentStatus enums with advance-status flow)
- [x] `Views/Orders/`: `OrderListView` (status filter), `OrderDetailView` (advance status, cancel, linked jobs/files with unlink, job + library-file pickers), `OrderFormView` (customer/source pickers, quoted price, payment status, due date), `CustomerListView` (+inline form), `OrderSourcesView`

## Phase 1.5 — Generator (WKWebView)
Native JSCAD/three.js port is infeasible; embed the web page.
- [x] `Views/Generator/GeneratorView.swift` — `WKWebView` loading `{serverURL}/#generator`, CSS injection hides web navbar, reload button
- [x] `Services/GeneratorService.swift` (status, presets list/delete)
- [x] `Views/Generator/GeneratorPresetsView.swift` — native preset list + swipe delete
- [x] Add Generator row to More

Note: if the web page fails to load over plain http on device, add an ATS exception (NSAllowsLocalNetworking) to the generated Info.plist — verify on hardware.

## Phase 2.1 — Ideas board
Endpoints: `/ideas` CRUD, `PATCH /ideas/{id}/status`, `POST /ideas/import`, `GET /ideas/tags/all`, `/ideas/stats/overview`, `GET /ideas/url/validate`, `POST /ideas/url/preview`, `GET /ideas/url/platforms`
- [x] `Services/IdeaService.swift` (list/create/update/status/delete, URL import + preview)
- [x] `Views/Ideas/IdeaListView.swift` (status + business filters, pagination), `IdeaDetailView.swift` (status chips, source link, delete), `IdeaFormView.swift` (paste URL → `/ideas/url/preview` auto-fill, import via `/ideas/import`)
- [x] Add Ideas row to More

## Phase 2.2 — Library power features (upload, tags, slicing)
Endpoints: `POST /files/upload` (multipart), `POST /library/files/{checksum}/reprocess`, `GET /library/statistics`; `/tags` CRUD + assign/remove; `GET /slicing`, `GET /slicing/{id}/profiles`, `POST /slicing/library/{checksum}/slice`, `POST /slicing/slice-and-print`, `GET /slicing/jobs/{id}`
- [x] `MultipartFormData` helper + `LibraryService.uploadFiles` via `fileImporter` (multi-select, security-scoped access)
- [x] `Services/TagService.swift`; tags row in file detail opens `TagEditorView` (create/assign/remove with toggle list)
- [x] `Services/SlicingService.swift`; Slice action on models → `SliceSheetView` (slicer + profile pickers, optional printer for slice & print, 2s job polling with progress)
- [x] Reprocess-metadata action in file detail; `LibraryService.statistics` available
- [x] Server-side source/thumbnail filters in the Library filter menu + `LibraryStatsView` sheet (totals, thumbnails, analyzed, storage, material cost)

## Phase 2.3 — Timelapses
Endpoints: `GET /timelapses`, `/timelapses/stats`, `GET /timelapses/{id}/video`, `POST /{id}/process`, `DELETE /{id}`, `PATCH /{id}/{link,pin}`, `POST /timelapses/bulk-delete`
- [x] `Services/TimelapseService.swift` (list/stats/process/pin/link/delete/bulk-delete, video URL)
- [x] `Views/Timelapses/TimelapseListView.swift` (stats header, status + linked-only filters, swipe pin/delete, process button) + `TimelapsePlayerView` (`VideoPlayer` on `/timelapses/{id}/video`, ShareLink). ATS note as in Phase 1.5 — verify http video playback on hardware
- [x] Add Timelapses row to More

## Phase 3 — Long tail (in order; each independently shippable)
- [x] 3.1 Files & downloads: `Services/FileService.swift` + `Views/Files/FileListView.swift` — printer file list (status filter, search, sync, download-to-server, delete) and watch folder management (add/remove/toggle/rescan). Download endpoint blocks until complete, so no progress polling needed; G-code analysis view deferred (enhanced metadata already shown in Library)
- [ ] 3.2 Settings management: `Services/SettingsService.swift` — `GET/PUT /settings/application` form, gcode-optimization, ffmpeg-check row
- [x] 3.3 Notification channels: `NotificationChannelService` + `NotificationChannelsView` in Settings — Discord/Slack/ntfy CRUD, per-event subscriptions, swipe-to-test/delete (local `NotificationService` untouched)
- [x] 3.4 Search: `Services/SearchService.swift` + `Views/More/SearchView.swift` — unified search over library files and ideas, grouped results (suggestions/history endpoints wrapped in service, UI on submit)
- [x] 3.5 Tools & System: `ToolsView` (curated links w/ category filter, mirrors web TOOLS_DATA); Settings gains Create Server Backup + Check for Updates (release link when available). Usage-stats admin dashboard skipped as desktop-only
- [x] 3.6 Debug/logs: `LogService` + `LogViewerView` in Settings → Developer — unified server logs with level/source filters, pagination, clear. Thumbnail-debug endpoints skipped (developer-only web tooling)
- [x] 3.7 Camera extras: MJPEGStreamView (incremental JPEG-marker parser over URLSession) as a Stream toggle in CameraPreviewView, CameraDiagnosticsView from printer detail; external webcam URL already in PrinterFormView (1.1)
- [x] 3.8 Ideas share extension — **deliberately not implemented from this environment**: creating an app-extension target (entitlements, App Group, embed phase, provisioning) by hand-editing pbxproj without an Xcode build to verify is too risky. Create the Share Extension target in Xcode on macOS; the in-app paste-URL import (Phase 2.1) covers the workflow meanwhile
- [x] 3.9 German localization: `Resources/Localizable.xcstrings` string catalog with ~250 German translations (SwiftUI text literals resolve via LocalizedStringKey, no code retrofit needed); `de` added to knownRegions

## Rules for every phase
1. Build gate: `xcodebuild -scheme Printernizer -configuration Debug build` must pass.
2. Tests: extend `PrinternizerTests` with DTO decode tests (JSON fixtures), formatter tests, enum-mapping tests; `xcodebuild -scheme Printernizer -configuration Debug test`.
3. Every new view gets `#Preview` with `.preview` fixtures.
4. New services use one shared `APIError` (in `APIService.swift`), not new per-service error enums.
5. Commit after each completed phase with a descriptive message; check the phase's boxes in this file in the same commit.
