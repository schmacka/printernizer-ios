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

final class AnalyticsModelTests: XCTestCase {

    func testOverviewDecoding() throws {
        let json = """
        {
            "jobs": {"total_jobs": 12, "completed_jobs": 10, "failed_jobs": 1, "success_rate": 83.3},
            "files": {"total_files": 42, "downloaded_files": 30, "local_files": 5},
            "printers": {"total_printers": 3, "online_printers": 2}
        }
        """.data(using: .utf8)!

        let overview = try APIConfiguration.makeDecoder().decode(AnalyticsOverview.self, from: json)
        XCTAssertEqual(overview.jobs?.totalJobs, 12)
        XCTAssertEqual(overview.jobs?.successRate, 83.3)
        XCTAssertEqual(overview.files?.totalFiles, 42)
        XCTAssertEqual(overview.printers?.onlinePrinters, 2)
    }

    func testOverviewDecodingWithMissingSections() throws {
        let json = """
        {"jobs": {"total_jobs": 0}}
        """.data(using: .utf8)!

        let overview = try APIConfiguration.makeDecoder().decode(AnalyticsOverview.self, from: json)
        XCTAssertEqual(overview.jobs?.totalJobs, 0)
        XCTAssertNil(overview.files)
        XCTAssertNil(overview.printers)
    }
}

final class MaterialModelTests: XCTestCase {

    func testMaterialStatsDecoding() throws {
        let json = """
        {
            "total_spools": 5,
            "total_weight": 5.0,
            "total_remaining": 3.2,
            "total_value": 125.5,
            "remaining_value": 80.25,
            "by_type": {"PLA": {"count": 3, "total_weight": 3.0, "remaining": 2.0}},
            "by_brand": {"PRUSAMENT": {"count": 2, "total_weight": 2.0, "remaining": 1.2}},
            "by_color": {"BLACK": 2, "RED": 3},
            "low_stock": ["mat-1", "mat-2"],
            "consumption_30d": 0.6
        }
        """.data(using: .utf8)!

        let stats = try APIConfiguration.makeDecoder().decode(MaterialStats.self, from: json)
        XCTAssertEqual(stats.totalSpools, 5)
        XCTAssertEqual(stats.lowStock?.count, 2)
        XCTAssertEqual(stats.byColor?["RED"], 3)
        XCTAssertEqual(stats.consumption30d, 0.6)
    }

    func testConsumptionHistoryDecoding() throws {
        let json = """
        {
            "items": [
                {
                    "id": "c-1",
                    "job_id": "job-1",
                    "material_id": "mat-1",
                    "material_type": "PLA",
                    "brand": "PRUSAMENT",
                    "color": "BLACK",
                    "weight_used": 42.5,
                    "cost": 1.1,
                    "timestamp": "2026-07-01T12:00:00",
                    "printer_id": "printer-1",
                    "file_name": "benchy.gcode",
                    "print_time_hours": 1.5
                }
            ],
            "total_count": 1,
            "page": 1,
            "limit": 50,
            "total_pages": 1
        }
        """.data(using: .utf8)!

        let history = try APIConfiguration.makeDecoder().decode(ConsumptionHistoryResponse.self, from: json)
        XCTAssertEqual(history.items.first?.weightUsed, 42.5)
        XCTAssertEqual(history.totalPages, 1)
    }
}

final class FormatterTests: XCTestCase {

    func testWeightKg() {
        XCTAssertEqual(Formatters.weightKg(1.5), "1.50 kg")
        XCTAssertEqual(Formatters.weightKg(0.75), "750 g")
    }

    func testWeightGrams() {
        XCTAssertEqual(Formatters.weightGrams(500), "500 g")
        XCTAssertEqual(Formatters.weightGrams(1500), "1.50 kg")
    }

    func testParseISODateVariants() {
        XCTAssertNotNil(Formatters.parseISODate("2026-07-18T10:00:00Z"))
        XCTAssertNotNil(Formatters.parseISODate("2026-07-18T10:00:00.123456Z"))
        XCTAssertNotNil(Formatters.parseISODate("2026-07-18T10:00:00"))
        XCTAssertNil(Formatters.parseISODate("not-a-date"))
    }
}

final class OrderModelTests: XCTestCase {

    func testOrderResponseDecoding() throws {
        let json = """
        {
            "id": "order-1",
            "title": "Vase Set",
            "customer_id": "cust-1",
            "source_id": null,
            "status": "planned",
            "quoted_price": 45.0,
            "payment_status": "unpaid",
            "notes": "Deliver soon",
            "due_date": "2026-07-25",
            "created_at": "2026-07-18T10:00:00",
            "updated_at": "2026-07-18T10:00:00",
            "customer": {"id": "cust-1", "name": "Anna", "email": null, "phone": null, "address": null, "notes": null, "order_count": 3, "created_at": "2026-01-01T00:00:00", "updated_at": "2026-01-01T00:00:00"},
            "source": {"id": "src-1", "name": "Etsy", "is_active": true, "created_at": "2026-01-01T00:00:00", "updated_at": "2026-01-01T00:00:00"},
            "jobs": [{"id": "job-1", "job_name": "Vase 1", "status": "completed"}],
            "files": [{"id": "of-1", "order_id": "order-1", "file_id": "abc", "url": null, "filename": "vase.stl", "file_type": "stl", "created_at": "2026-01-01T00:00:00"}],
            "material_cost_eur": 6.5,
            "energy_cost_eur": 1.2
        }
        """.data(using: .utf8)!

        let order = try APIConfiguration.makeDecoder().decode(OrderResponse.self, from: json)
        XCTAssertEqual(order.status, .planned)
        XCTAssertEqual(order.status.next, .printed)
        XCTAssertEqual(order.paymentStatus, .unpaid)
        XCTAssertEqual(order.customer?.name, "Anna")
        XCTAssertEqual(order.jobs?.first?.displayName, "Vase 1")
        XCTAssertEqual(order.files?.first?.filename, "vase.stl")
        XCTAssertEqual(order.materialCostEur, 6.5)
    }

    func testOrderStatusFlow() {
        XCTAssertEqual(OrderStatus.new.next, .planned)
        XCTAssertEqual(OrderStatus.planned.next, .printed)
        XCTAssertEqual(OrderStatus.printed.next, .delivered)
        XCTAssertNil(OrderStatus.delivered.next)
        XCTAssertNil(OrderStatus.cancelled.next)
    }

    func testJobCreateRequestEncoding() throws {
        let request = JobCreateRequest(
            printerId: "printer-1",
            jobName: "Test",
            filename: nil,
            fileId: nil,
            estimatedDuration: nil,
            materialCost: 2.5,
            isBusiness: true,
            customerName: "Anna"
        )

        let data = try APIConfiguration.makeEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["printer_id"] as? String, "printer-1")
        XCTAssertEqual(object["is_business"] as? Bool, true)
        XCTAssertEqual(object["customer_name"] as? String, "Anna")
        XCTAssertNil(object["filename"])
    }
}

final class IdeaModelTests: XCTestCase {

    func testIdeaListDecoding() throws {
        let json = """
        {
            "ideas": [{
                "id": "idea-1",
                "title": "Articulated Dragon",
                "description": null,
                "source_type": "makerworld",
                "source_url": "https://makerworld.com/models/12345",
                "thumbnail_path": null,
                "category": "Toys",
                "priority": 4,
                "status": "planned",
                "is_business": false,
                "estimated_print_time": 240,
                "material_notes": null,
                "customer_info": null,
                "planned_date": null,
                "completed_date": null,
                "metadata": {"model_id": "12345"},
                "tags": ["dragon"],
                "created_at": "2026-07-18T10:00:00",
                "updated_at": "2026-07-18T10:00:00"
            }],
            "page": 1,
            "page_size": 20,
            "has_more": false
        }
        """.data(using: .utf8)!

        let response = try APIConfiguration.makeDecoder().decode(IdeaListResponse.self, from: json)
        XCTAssertEqual(response.ideas.count, 1)
        XCTAssertEqual(response.ideas[0].ideaStatus, .planned)
        XCTAssertEqual(response.ideas[0].tags, ["dragon"])
        XCTAssertEqual(response.hasMore, false)
    }

    func testIdeaStatusFallback() {
        let idea = IdeaResponse(
            id: "x", title: "t", description: nil, sourceType: nil, sourceUrl: nil,
            thumbnailPath: nil, category: nil, priority: nil, status: "bogus",
            isBusiness: nil, estimatedPrintTime: nil, materialNotes: nil,
            customerInfo: nil, plannedDate: nil, completedDate: nil, tags: nil,
            createdAt: nil, updatedAt: nil
        )
        XCTAssertEqual(idea.ideaStatus, .idea)
    }
}

final class LibraryPowerFeatureTests: XCTestCase {

    func testMultipartFormDataStructure() {
        var form = MultipartFormData()
        form.addField(name: "is_business", value: "false")
        form.addFile(name: "files", filename: "benchy.stl", data: Data("solid benchy".utf8))
        let body = String(decoding: form.finalized(), as: UTF8.self)

        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"is_business\""))
        XCTAssertTrue(body.contains("name=\"files\"; filename=\"benchy.stl\""))
        XCTAssertTrue(body.contains("solid benchy"))
        XCTAssertTrue(body.hasSuffix("--\(form.boundary)--\r\n"))
    }

    func testTagListDecoding() throws {
        let json = """
        {
            "tags": [
                {"id": "tag-1", "name": "vase", "color": "#6b7280", "description": null, "usage_count": 4, "created_at": "2026-01-01", "updated_at": "2026-01-01"}
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try APIConfiguration.makeDecoder().decode(TagListResponse.self, from: json)
        XCTAssertEqual(response.tags.first?.name, "vase")
        XCTAssertEqual(response.tags.first?.usageCount, 4)
    }

    func testSlicingJobDecoding() throws {
        let json = """
        {
            "id": "sj-1",
            "file_checksum": "abc",
            "filename": "benchy.stl",
            "slicer_id": "prusaslicer",
            "slicer_name": "PrusaSlicer",
            "profile_id": "p-1",
            "profile_name": "0.2mm Quality",
            "target_printer_id": null,
            "status": "completed",
            "priority": 5,
            "progress": 100,
            "estimated_print_time": 5400,
            "filament_used": 13.5,
            "error_message": null,
            "retry_count": 0,
            "auto_upload": false,
            "auto_start": false,
            "created_at": "2026-07-18T10:00:00",
            "updated_at": "2026-07-18T10:05:00"
        }
        """.data(using: .utf8)!

        let job = try APIConfiguration.makeDecoder().decode(SlicingJobResponse.self, from: json)
        XCTAssertTrue(job.isFinished)
        XCTAssertTrue(job.isSuccessful)
        XCTAssertEqual(job.estimatedPrintTime, 5400)
    }
}

final class TimelapseModelTests: XCTestCase {

    func testTimelapseListDecoding() throws {
        let json = """
        [
            {
                "id": "tl-1",
                "source_folder": "/timelapses/benchy",
                "output_video_path": "/timelapses/benchy.mp4",
                "status": "completed",
                "job_id": "job-1",
                "folder_name": "benchy_2026-07-18",
                "image_count": 480,
                "video_duration": 16.0,
                "file_size_bytes": 24500000,
                "error_message": null,
                "pinned": true,
                "video_exists": true,
                "age_days": 2,
                "created_at": "2026-07-16T08:00:00",
                "updated_at": "2026-07-16T09:00:00"
            }
        ]
        """.data(using: .utf8)!

        let timelapses = try APIConfiguration.makeDecoder().decode([TimelapseResponse].self, from: json)
        XCTAssertEqual(timelapses.count, 1)
        XCTAssertEqual(timelapses[0].displayName, "benchy_2026-07-18")
        XCTAssertEqual(timelapses[0].pinned, true)
        XCTAssertEqual(timelapses[0].formattedSize, "24.5 MB")
    }

    func testTimelapseStatsDecoding() throws {
        let json = """
        {
            "total_videos": 12,
            "total_size_bytes": 1500000000,
            "discovered_count": 1,
            "pending_count": 0,
            "processing_count": 2,
            "completed_count": 9,
            "failed_count": 0,
            "cleanup_candidates_count": 3,
            "total_size_mb": 1430.51,
            "total_size_gb": 1.4
        }
        """.data(using: .utf8)!

        let stats = try APIConfiguration.makeDecoder().decode(TimelapseStats.self, from: json)
        XCTAssertEqual(stats.totalVideos, 12)
        XCTAssertEqual(stats.totalSizeGb, 1.4)
    }
}

final class FileServiceModelTests: XCTestCase {

    func testPrinterFileListDecoding() throws {
        let json = """
        {
            "files": [{
                "id": "printer-1_benchy.3mf",
                "printer_id": "printer-1",
                "filename": "benchy.3mf",
                "source": "printer",
                "status": "available",
                "file_size": 2500000,
                "file_type": "3mf",
                "downloaded_at": null,
                "created_at": "2026-07-18T10:00:00",
                "has_thumbnail": true
            }],
            "total_count": 1,
            "pagination": {"page": 1, "limit": 50, "total_items": 1, "total_pages": 1}
        }
        """.data(using: .utf8)!

        let response = try APIConfiguration.makeDecoder().decode(PrinterFileListResponse.self, from: json)
        XCTAssertEqual(response.files.count, 1)
        XCTAssertTrue(response.files[0].isDownloadable)
        XCTAssertEqual(response.files[0].formattedSize, "2.5 MB")
    }

    func testWatchFolderSettingsDecoding() throws {
        let json = """
        {
            "watch_folders": [{
                "id": "wf-1",
                "folder_path": "/models/incoming",
                "is_active": true,
                "recursive": true,
                "folder_name": "incoming",
                "description": null,
                "file_count": 12,
                "is_valid": true,
                "validation_error": null,
                "source": "database",
                "auto_tag": false
            }],
            "enabled": true,
            "recursive": true,
            "supported_extensions": [".stl", ".3mf"]
        }
        """.data(using: .utf8)!

        let settings = try APIConfiguration.makeDecoder().decode(WatchFolderSettings.self, from: json)
        XCTAssertEqual(settings.watchFolders.count, 1)
        XCTAssertEqual(settings.watchFolders[0].fileCount, 12)
        XCTAssertEqual(settings.enabled, true)
    }
}
