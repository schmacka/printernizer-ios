# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Printernizer iOS is a companion app for the Printernizer 3D printer monitoring system. It allows users to monitor and control their 3D printers remotely.

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
├── App/                  # App entry point and root views
├── Models/               # Data models (Printer, PrintJob)
├── Views/
│   ├── Printer/          # Printer list and detail views
│   ├── PrintJob/         # Print job monitoring views
│   ├── Settings/         # App settings
│   └── Components/       # Reusable UI components
├── ViewModels/           # @MainActor observable view models
└── Services/             # API and WebSocket services
```

## Key Patterns

- **ViewModels** are `@MainActor` classes using `@Published` properties
- **APIService** is passed via `@EnvironmentObject` from the app root
- **Models** conform to `Identifiable`, `Codable`, and `Equatable`
- **Preview data** is provided via static `.preview` properties on models

## Services

- `APIService`: REST API communication with the Printernizer backend
- `WebSocketService`: Real-time updates for printer status and job progress

## Configuration

- Server URL stored in `@AppStorage("serverURL")`
- Bundle identifier: `com.printernizer.ios`
- Minimum deployment target: iOS 17.0
