import XCTest
@testable import Printernizer

final class PrinterTests: XCTestCase {

    func testPrinterStatusAPIMapping() {
        // Backend PrinterStatus enum: online, offline, printing, paused, error, unknown
        XCTAssertEqual(PrinterStatus(apiValue: "online"), .idle)
        XCTAssertEqual(PrinterStatus(apiValue: "idle"), .idle)
        XCTAssertEqual(PrinterStatus(apiValue: "printing"), .printing)
        XCTAssertEqual(PrinterStatus(apiValue: "paused"), .paused)
        XCTAssertEqual(PrinterStatus(apiValue: "error"), .error)
        XCTAssertEqual(PrinterStatus(apiValue: "offline"), .offline)
        XCTAssertEqual(PrinterStatus(apiValue: "unknown"), .offline)
        XCTAssertEqual(PrinterStatus(apiValue: "PRINTING"), .printing)
    }

    func testPrinterStatusDisplayName() {
        XCTAssertEqual(PrinterStatus.idle.displayName, "Idle")
        XCTAssertEqual(PrinterStatus.printing.displayName, "Printing")
        XCTAssertEqual(PrinterStatus.paused.displayName, "Paused")
        XCTAssertEqual(PrinterStatus.error.displayName, "Error")
        XCTAssertEqual(PrinterStatus.offline.displayName, "Offline")
    }

    func testPrinterEquatable() {
        let printer1 = Printer(id: "1", name: "Test", status: .idle, model: "Model", currentJobProgress: nil)
        let printer2 = Printer(id: "1", name: "Test", status: .idle, model: "Model", currentJobProgress: nil)

        XCTAssertEqual(printer1, printer2)
    }

    func testPrinterPreview() {
        let preview = Printer.preview

        XCTAssertEqual(preview.id, "1")
        XCTAssertEqual(preview.name, "Ender 3 V2")
        XCTAssertEqual(preview.status, .printing)
        XCTAssertNotNil(preview.currentJobProgress)
    }
}

final class PrintJobTests: XCTestCase {

    func testFormattedElapsedTime() {
        let job = PrintJob(
            id: "1",
            fileName: "test.gcode",
            progress: 0.5,
            elapsedSeconds: 3660,
            estimatedTotalSeconds: 7200,
            currentLayer: 50,
            totalLayers: 100,
            filamentUsedMm: 1500
        )

        XCTAssertEqual(job.formattedElapsedTime, "1h 1m")
    }

    func testFormattedTimeRemaining() {
        let job = PrintJob(
            id: "1",
            fileName: "test.gcode",
            progress: 0.5,
            elapsedSeconds: 3600,
            estimatedTotalSeconds: 7200,
            currentLayer: 50,
            totalLayers: 100,
            filamentUsedMm: 1500
        )

        XCTAssertEqual(job.formattedTimeRemaining, "1h 0m")
    }

    func testFormattedFilamentUsedMeters() {
        let job = PrintJob(
            id: "1",
            fileName: "test.gcode",
            progress: 0.5,
            elapsedSeconds: 3600,
            estimatedTotalSeconds: 7200,
            currentLayer: 50,
            totalLayers: 100,
            filamentUsedMm: 2500
        )

        XCTAssertEqual(job.formattedFilamentUsed, "2.5m")
    }

    func testFormattedFilamentUsedMillimeters() {
        let job = PrintJob(
            id: "1",
            fileName: "test.gcode",
            progress: 0.5,
            elapsedSeconds: 3600,
            estimatedTotalSeconds: 7200,
            currentLayer: 50,
            totalLayers: 100,
            filamentUsedMm: 500
        )

        XCTAssertEqual(job.formattedFilamentUsed, "500mm")
    }

    func testRemainingSecondsCalculation() {
        let job = PrintJob(
            id: "1",
            fileName: "test.gcode",
            progress: 0.5,
            elapsedSeconds: 1800,
            estimatedTotalSeconds: 3600,
            currentLayer: 50,
            totalLayers: 100,
            filamentUsedMm: 1000
        )

        XCTAssertEqual(job.remainingSeconds, 1800)
    }

    func testRemainingSecondsNilWhenNoEstimate() {
        let job = PrintJob(
            id: "1",
            fileName: "test.gcode",
            progress: 0.5,
            elapsedSeconds: 1800,
            estimatedTotalSeconds: nil,
            currentLayer: 50,
            totalLayers: 100,
            filamentUsedMm: 1000
        )

        XCTAssertNil(job.remainingSeconds)
        XCTAssertNil(job.formattedTimeRemaining)
    }
}

// MARK: - API Decoding Tests
// Payload samples mirror the shapes served by the Printernizer backend
// (v2.4x): snake_case keys, envelope objects, and extra fields the app
// doesn't decode.

final class APIDecodingTests: XCTestCase {

    private let decoder = APIConfiguration.makeDecoder()

    func testJobListResponseDecoding() throws {
        let json = """
        {
            "jobs": [{
                "id": "job-1",
                "printer_id": "printer-1",
                "printer_type": "bambu_lab",
                "job_name": "benchy",
                "filename": "benchy.gcode",
                "status": "running",
                "start_time": "2026-07-01T10:00:00Z",
                "end_time": null,
                "estimated_duration": 3600,
                "actual_duration": null,
                "progress": 42.5,
                "material_used": null,
                "material_cost": null,
                "power_cost": null,
                "is_business": false,
                "customer_name": null,
                "order_id": null,
                "created_at": "2026-07-01T10:00:00Z",
                "updated_at": "2026-07-01T10:30:00Z",
                "progress_percent": 42.5,
                "cost_eur": null,
                "started_at": "2026-07-01T10:00:00Z",
                "completed_at": null
            }],
            "total_count": 1,
            "pagination": {"page": 1, "limit": 50, "total_items": 1, "total_pages": 1}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(JobListResponse.self, from: json)
        XCTAssertEqual(response.jobs.count, 1)
        XCTAssertEqual(response.jobs[0].jobName, "benchy")
        XCTAssertEqual(response.jobs[0].progress, 42.5)
        XCTAssertEqual(response.pagination.totalPages, 1)
    }

    func testLibraryFileListResponseDecoding() throws {
        let json = """
        {
            "files": [{
                "id": "1",
                "checksum": "abc123",
                "filename": "benchy.stl",
                "display_name": "3D Benchy",
                "file_size": 1500000,
                "file_type": "stl",
                "status": "ready",
                "role": "model",
                "parent_checksum": null,
                "analysis_error": null,
                "has_thumbnail": true,
                "added_to_library": "2026-07-01T10:00:00Z",
                "model_width": 60.0,
                "model_depth": 31.0,
                "model_height": 48.0,
                "layer_height": 0.2,
                "infill_density": 15.0,
                "compatible_printers": null,
                "sources": "[{\\"type\\": \\"watch_folder\\"}]"
            }],
            "pagination": {"page": 1, "limit": 50, "total_items": 1, "total_pages": 1}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(LibraryFileListResponse.self, from: json)
        XCTAssertEqual(response.files.count, 1)
        XCTAssertEqual(response.files[0].checksum, "abc123")
        XCTAssertEqual(response.files[0].displayTitle, "3D Benchy")
        XCTAssertTrue(response.files[0].isModel)
        XCTAssertFalse(response.files[0].isPrintFile)
        XCTAssertEqual(response.files[0].formattedDimensions, "60 × 31 × 48 mm")
        XCTAssertEqual(response.pagination?.totalPages, 1)
    }

    func testLibraryPrintFilesResponseDecoding() throws {
        let json = """
        {
            "printfiles": [{
                "checksum": "def456",
                "filename": "benchy.gcode",
                "display_name": null,
                "file_size": 900000,
                "file_type": "gcode",
                "status": "ready",
                "role": "printfile",
                "parent_checksum": "abc123",
                "has_thumbnail": false,
                "profile_id": "profile-1",
                "target_printer_id": "printer-1",
                "estimated_print_time": 5400.0,
                "filament_used": 13.5,
                "sliced_at": "2026-07-02T09:00:00Z",
                "profile_name": "0.2mm Quality"
            }],
            "count": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(LibraryPrintFilesResponse.self, from: json)
        XCTAssertEqual(response.printfiles.count, 1)
        XCTAssertEqual(response.printfiles[0].profileName, "0.2mm Quality")
        XCTAssertEqual(response.printfiles[0].formattedPrintTime, "1h 30m")
        XCTAssertEqual(response.printfiles[0].displayTitle, "benchy.gcode")
    }

    func testMaterialStatsDecoding() throws {
        let json = """
        {
            "total_spools": 12,
            "total_weight": 9500.0,
            "total_remaining": 6200.0,
            "total_value": 240.0,
            "remaining_value": 155.0,
            "by_type": {"PLA": 8, "PETG": 4},
            "by_brand": {"Prusament": 6},
            "by_color": {"black": 5},
            "low_stock": 2,
            "consumption_30d": 850.0,
            "consumption_rate": 28.3
        }
        """.data(using: .utf8)!

        let stats = try decoder.decode(MaterialStats.self, from: json)
        XCTAssertEqual(stats.totalSpools, 12)
        XCTAssertEqual(stats.lowStock, 2)
        XCTAssertEqual(stats.byType?["PLA"], 8)
    }

    func testSystemInfoDecoding() throws {
        let json = """
        {
            "version": "2.42.0",
            "environment": "production",
            "timezone": "Europe/Berlin",
            "database_size_mb": 42.5,
            "uptime_seconds": 86400.0
        }
        """.data(using: .utf8)!

        let info = try decoder.decode(SystemInfo.self, from: json)
        XCTAssertEqual(info.version, "2.42.0")
        XCTAssertEqual(info.timezone, "Europe/Berlin")
    }

    func testPrinterListResponseDecoding() throws {
        let json = """
        {
            "printers": [{
                "id": "printer-1",
                "name": "Bambu A1",
                "printer_type": "bambu_lab",
                "status": "printing",
                "ip_address": "192.168.1.50",
                "connection_config": {},
                "location": null,
                "description": null,
                "is_enabled": true,
                "last_seen": null,
                "current_job": {
                    "name": "benchy.gcode",
                    "status": "printing",
                    "progress": 42,
                    "started_at": null,
                    "estimated_remaining": 1800,
                    "layer_current": 50,
                    "layer_total": 120
                },
                "temperatures": {"bed": 60.0, "nozzle": 215.0},
                "filaments": [],
                "total_jobs": 10,
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-07-01T00:00:00Z"
            }],
            "total_count": 1,
            "pagination": {"page": 1, "limit": 50, "total_items": 1, "total_pages": 1}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIPrinterListResponse.self, from: json)
        XCTAssertEqual(response.printers.count, 1)
        XCTAssertEqual(response.printers[0].currentJob?.progress, 42)
        XCTAssertEqual(response.printers[0].temperatures?.nozzle, 215.0)
    }

    func testAPIConfigurationURLBuilding() {
        UserDefaults.standard.set("http://printer.local:8000", forKey: "serverURL")
        defer { UserDefaults.standard.removeObject(forKey: "serverURL") }

        XCTAssertEqual(
            APIConfiguration.url("printers")?.absoluteString,
            "http://printer.local:8000/api/v1/printers"
        )
        XCTAssertEqual(
            APIConfiguration.url("jobs", queryItems: [URLQueryItem(name: "page", value: "2")])?.absoluteString,
            "http://printer.local:8000/api/v1/jobs?page=2"
        )
        XCTAssertEqual(
            APIConfiguration.websocketURL()?.absoluteString,
            "ws://printer.local:8000/ws"
        )
    }
}

final class PrinterServiceModelTests: XCTestCase {

    func testDiscoveryResultDecoding() throws {
        let json = """
        {
            "discovered": [
                {
                    "type": "bambu_lab",
                    "name": "Bambu A1",
                    "ip": "192.168.1.50",
                    "hostname": null,
                    "model": "A1",
                    "serial": "0309CA123456",
                    "discovered_at": "2026-07-18T10:00:00",
                    "already_added": false
                }
            ],
            "scan_duration_ms": 10432.5,
            "errors": ["SSDP library not available - Bambu Lab discovery disabled"],
            "timestamp": "2026-07-18T10:00:10"
        }
        """.data(using: .utf8)!

        let result = try APIConfiguration.makeDecoder().decode(DiscoveryResult.self, from: json)
        XCTAssertEqual(result.discovered.count, 1)
        let printer = try XCTUnwrap(result.discovered.first)
        XCTAssertEqual(printer.ip, "192.168.1.50")
        XCTAssertEqual(printer.serial, "0309CA123456")
        XCTAssertEqual(printer.alreadyAdded, false)
        XCTAssertEqual(printer.printerType, .bambuLab)
        XCTAssertEqual(result.errors?.count, 1)
    }

    func testPrinterConfigResponseDecoding() throws {
        let json = """
        {
            "id": "printer-1",
            "name": "Werkstatt A1",
            "printer_type": "bambu_lab",
            "status": "online",
            "ip_address": "192.168.1.50",
            "connection_config": {
                "ip_address": "192.168.1.50",
                "api_key": null,
                "access_code": "12345678",
                "serial_number": "0309CA123456",
                "webcam_url": null
            },
            "location": "Werkstatt",
            "description": null,
            "is_enabled": true,
            "last_seen": "2026-07-18T09:59:00",
            "created_at": "2026-01-01T00:00:00",
            "updated_at": "2026-01-01T00:00:00"
        }
        """.data(using: .utf8)!

        let printer = try APIConfiguration.makeDecoder().decode(PrinterConfigResponse.self, from: json)
        XCTAssertEqual(printer.id, "printer-1")
        XCTAssertEqual(printer.printerType, "bambu_lab")
        XCTAssertEqual(printer.connectionConfig?.accessCode, "12345678")
        XCTAssertEqual(printer.connectionConfig?.serialNumber, "0309CA123456")
        XCTAssertEqual(printer.isEnabled, true)
    }

    func testCreateRequestEncodesSnakeCase() throws {
        let request = PrinterCreateRequest(
            name: "Test",
            printerType: .prusaCore,
            connectionConfig: PrinterConnectionConfig(
                ipAddress: "10.0.0.5",
                apiKey: "secret",
                accessCode: nil,
                serialNumber: nil,
                webcamUrl: nil
            ),
            location: nil,
            description: nil
        )

        let data = try APIConfiguration.makeEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["printer_type"] as? String, "prusa_core")
        let config = try XCTUnwrap(object["connection_config"] as? [String: Any])
        XCTAssertEqual(config["ip_address"] as? String, "10.0.0.5")
        XCTAssertEqual(config["api_key"] as? String, "secret")
    }

    func testPrinterTypeDisplayNames() {
        XCTAssertEqual(PrinterType.bambuLab.displayName, "Bambu Lab")
        XCTAssertEqual(PrinterType.prusaCore.displayName, "Prusa")
        XCTAssertEqual(PrinterType.octoprint.displayName, "OctoPrint")
    }
}
