# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Printernizer iOS is a companion app for the Printernizer 3D printer monitoring system. It aims for feature parity with the web app (see `PARITY_PLAN.md` for the phased parity work), allowing users to monitor and control their 3D printers on the local network.

**Key Features:**
- Dashboard with analytics overview, live printer cards, and recent jobs
- Real-time printer monitoring with temperature display (WebSocket + poll fallback)
- Printer management: add/edit/delete, network discovery, connect/disconnect
- Camera preview (polling + MJPEG stream), snapshot gallery, camera diagnostics
- Print jobs: history, filters, creation (incl. business jobs), CSV export, cancel
- Orders (business): status flow, payment, customers, order sources, linked jobs/files
- Library: browse/search/filter, upload, tags, server-side slicing (slice & print), print-to-printer
- Materials: full CRUD, consumption tracking + history, stats, CSV/Excel export
- Ideas board with URL import from MakerWorld/Printables
- Timelapses: gallery, playback (AVKit), process/pin/delete
- Files: printer file downloads, watch folder management
- Generator embedded via WKWebView (geometry engine is browser-side JSCAD)
- Unified search, curated Tools links, server log viewer
- Settings: QR pairing, server application settings, notification channels (Discord/Slack/ntfy), backup, update check
- Local notifications for print completed/failed and printer offline
- German localization via `Resources/Localizable.xcstrings`

## Build Commands

```bash
# Build the project
xcodebuild -scheme Printernizer -configuration Debug build

# Run all tests
xcodebuild -scheme Printernizer -configuration Debug test

# Run a single test class
xcodebuild -scheme Printernizer -only-testing:PrinternizerTests/PrinterTests test

# Run a single test method
xcodebuild -scheme Printernizer -only-testing:PrinternizerTests/PrinterTests/testPrinterStatusDisplayName test

# Build for release
xcodebuild -scheme Printernizer -configuration Release build
```

New source files must be registered in `Printernizer.xcodeproj/project.pbxproj` (explicit file lists, no folder sync): PBXBuildFile + PBXFileReference entries, group children, and the Sources build phase.

## Architecture

SwiftUI + MVVM with the following structure:

```
Printernizer/Sources/
├── App/                  # App entry point (PrinternizerApp, ContentView with AppTab enum)
├── Models/               # Data models (Printer, PrintJob)
├── Views/
│   ├── Camera/           # Camera preview, MJPEG stream, snapshots, diagnostics
│   ├── Components/       # Reusable UI components (PrinterCardView, ProgressRingView)
│   ├── Dashboard/        # Dashboard tab
│   ├── Files/            # Printer files & watch folders
│   ├── Generator/        # WKWebView-embedded generator + presets
│   ├── Ideas/            # Idea board
│   ├── Jobs/             # Job list/detail/form (Jobs | Orders segmented tab)
│   ├── Library/          # Library grid, detail, tags, slicing, stats
│   ├── Materials/        # Materials inventory, form, consumption
│   ├── More/             # More tab hub, Search, Tools
│   ├── Orders/           # Business orders, customers, order sources
│   ├── Printer/          # Printer list/detail/form/discovery
│   ├── PrintJob/         # Current-job display component
│   ├── Settings/         # App + server settings, channels, logs, QR scanner
│   └── Timelapses/       # Timelapse gallery + player
├── ViewModels/           # @MainActor observable view models (shared/screen-level)
├── Services/             # API, WebSocket, and domain services
└── Utilities/            # Formatters (EUR/weights/dates), MultipartFormData
```

## Key Patterns

- **ViewModels** are `@MainActor` classes using `@Published` properties (screen-local view models often live in the same file as their view)
- **APIService and WebSocketService** are passed via `@EnvironmentObject` from the app root
- **Domain Services** are instantiated per-view/per-view-model
- **APIConfiguration** centralizes the server URL, `/api/v1` base path, and snake_case JSON coders — never hardcode API paths in services
- **Models** conform to `Identifiable`, `Codable`, and (where useful) `Equatable`
- **Preview data** is provided via static `.preview` properties on models
- **Async/await** used throughout for API calls
- **JSON encoding** uses snake_case conversion for backend compatibility; DTO fields for evolving backend schemas are decoded optionally (all-optional fields except identity)
- **DTO tests**: new response models get decode tests in `PrinternizerTests` with JSON fixtures mirroring real backend payloads

## Services

| Service | Purpose |
|---------|---------|
| `APIConfiguration` | Central URL building (`/api/v1`) and JSON coder factories |
| `APIService` | Printers list/details/print-controls, health, system info, backup, update check |
| `PrinterService` | Printer CRUD, network discovery, test-connection, connect/disconnect |
| `WebSocketService` | Real-time updates via `/ws`; printer subscriptions, reconnect, ping |
| `AnalyticsService` | Dashboard overview, summary, business analytics |
| `CameraService` | Camera status/preview/stream URL, snapshots, diagnostics |
| `JobService` | Job list/create/update/delete/cancel, CSV export |
| `OrderService` | Orders, customers, order sources (business features) |
| `LibraryService` | Library files: list/search/filter, thumbnails, printfiles, print, upload, reprocess, statistics |
| `TagService` | Tag CRUD and file assignment |
| `SlicingService` | Slicers, profiles, slice / slice-and-print jobs |
| `MaterialService` | Materials CRUD, consumption, stats, CSV/Excel export |
| `IdeaService` | Idea board CRUD, URL import/preview |
| `TimelapseService` | Timelapse list/stats/process/pin/link/delete, video URL |
| `FileService` | Printer file discovery/downloads, watch folders |
| `SearchService` | Unified search |
| `GeneratorService` | Generator status + presets |
| `NotificationChannelService` | Server webhook channels (Discord/Slack/ntfy) |
| `ServerSettingsService` | Server application settings, ffmpeg check |
| `LogService` | Unified server logs |
| `NotificationService` | Local notifications from printer status transitions |

## Main Navigation

ContentView uses TabView with 5 tabs (`AppTab` enum):
1. **Dashboard** - DashboardView (analytics tiles, live printers, recent jobs)
2. **Printers** - PrinterListView
3. **Jobs** - JobListView (segmented Jobs | Orders)
4. **Library** - LibraryListView
5. **More** - MoreView (Search, Materials, Ideas, Timelapses, Files, Generator, Tools, Settings via `MoreDestination`)

`MaterialListView` and `SettingsView` are pushed destinations (no own `NavigationStack`); MoreView provides the stack.

## Backend API

The app connects to a Printernizer backend (FastAPI) on local network:
- Base URL stored in `@AppStorage("serverURL")`
- REST endpoints under `/api/v1`: printers, jobs, orders, customers, order-sources, files, library, tags, slicing, materials, ideas, timelapses, search, analytics, notifications, settings, generator, logs, system, health, update-check
- WebSocket: `/ws` (not under `/api/v1`); only `printer_status` events are pushed by current backends, and only for printers subscribed via `subscribe_printer`
- All URL building goes through `APIConfiguration` (Services/APIConfiguration.swift)
- The backend source lives at `/projects/printernizer-repos/printernizer` in the dev environment — check its routers/models for exact payload shapes before writing DTOs

## Configuration

- Server URL stored in `@AppStorage("serverURL")`
- Refresh interval stored in `@AppStorage("refreshInterval")`
- Bundle identifier: `com.printernizer.ios`
- Minimum deployment target: iOS 17.0
- Localization: string catalog at `Printernizer/Resources/Localizable.xcstrings` (en source, de translations)

## CI/CD

The only GitHub Actions workflow is CodeQL security scanning (`.github/workflows/codeql.yml`). There is no build/test CI workflow; build and run tests locally with the commands under [Build Commands](#build-commands).

## Future Features

- Push notifications while the app is closed (requires backend changes; local notifications and server webhook channels exist)
- Remote access (requires authentication)
- Ideas share extension (requires an Xcode-created extension target with App Group)
- Timelapse job-linking UI (service method exists; backend auto-links most recordings)
