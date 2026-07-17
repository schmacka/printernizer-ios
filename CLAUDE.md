# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Printernizer iOS is a companion app for the Printernizer 3D printer monitoring system. It provides full feature parity with the web app, allowing users to monitor and control their 3D printers on local network.

**Key Features:**
- Real-time printer monitoring with temperature display (WebSocket + poll fallback)
- Camera preview with auto-refresh and snapshot gallery
- Print job history with filtering and details
- Library (checksum-addressed models and sliced print files) with thumbnails, tags, print-to-printer
- Materials inventory tracking with CSV/Excel export
- Local notifications for print completed/failed and printer offline

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

## Architecture

SwiftUI + MVVM with the following structure:

```
Printernizer/Sources/
├── App/                  # App entry point (PrinternizerApp, ContentView)
├── Models/               # Data models (Printer, PrintJob)
├── Views/
│   ├── Camera/           # Camera preview and snapshots
│   ├── Components/       # Reusable UI components
│   ├── Files/            # File list and detail views
│   ├── Jobs/             # Job history views
│   ├── Materials/        # Materials inventory views
│   ├── Printer/          # Printer list and detail views
│   └── Settings/         # App settings
├── ViewModels/           # @MainActor observable view models
└── Services/             # API, WebSocket, and domain services
```

## Key Patterns

- **ViewModels** are `@MainActor` classes using `@Published` properties
- **APIService and WebSocketService** are passed via `@EnvironmentObject` from the app root
- **Domain Services** (CameraService, JobService, LibraryService, MaterialService) are instantiated per-view
- **APIConfiguration** centralizes the server URL, `/api/v1` base path, and snake_case JSON coders — never hardcode API paths in services
- **Models** conform to `Identifiable`, `Codable`, and `Equatable`
- **Preview data** is provided via static `.preview` properties on models
- **Async/await** used throughout for API calls
- **JSON encoding** uses snake_case conversion for backend compatibility; DTO fields for evolving backend schemas (especially Library) are decoded optionally

## Services

| Service | Purpose |
|---------|---------|
| `APIConfiguration` | Central URL building (`/api/v1`) and JSON coder factories |
| `APIService` | Core REST API for printers (list, details, controls), health check, system info |
| `WebSocketService` | Real-time updates via `/ws`; printer subscriptions, reconnect, ping |
| `CameraService` | Camera preview, snapshots |
| `JobService` | Print job history, filtering, cancellation |
| `LibraryService` | Library files (checksum-based): list/search, thumbnails, printfiles, print, tags, delete |
| `MaterialService` | Materials inventory, stats, CSV/Excel export |
| `NotificationService` | Local notifications from printer status transitions |

## Main Navigation

ContentView uses TabView with 5 tabs:
1. **Printers** - PrinterListView
2. **Jobs** - JobListView
3. **Library** - LibraryListView
4. **Materials** - MaterialListView
5. **Settings** - SettingsView

## Backend API

The app connects to a Printernizer backend (FastAPI) on local network:
- Base URL stored in `@AppStorage("serverURL")`
- REST endpoints: `/api/v1/printers`, `/api/v1/jobs`, `/api/v1/files`, `/api/v1/library`, `/api/v1/materials`, `/api/v1/health`, `/api/v1/system/info`
- WebSocket: `/ws` (not under `/api/v1`); only `printer_status` events are pushed by current backends, and only for printers subscribed via `subscribe_printer`
- All URL building goes through `APIConfiguration` (Services/APIConfiguration.swift)

## Configuration

- Server URL stored in `@AppStorage("serverURL")`
- Refresh interval stored in `@AppStorage("refreshInterval")`
- Bundle identifier: `com.printernizer.ios`
- Minimum deployment target: iOS 17.0

## CI/CD

The only GitHub Actions workflow is CodeQL security scanning (`.github/workflows/codeql.yml`). There is no build/test CI workflow; build and run tests locally with the commands under [Build Commands](#build-commands).

## Future Features

- Push notifications while the app is closed (requires backend changes; local notifications for live status transitions exist)
- Remote access (requires authentication)
- Trigger slicing from the app (read-only slicing info is shown on library print files)
- Timelapse browsing
