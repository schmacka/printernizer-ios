import XCTest
@testable import Printernizer

final class PrinterTests: XCTestCase {

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
