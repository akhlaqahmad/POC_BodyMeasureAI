//
//  JSONExportService.swift
//  BodyMeasureAI
//
//  Reusable export: session JSON and validation CSV to temp files for share sheet.
//

import Foundation
import UIKit

/// Validation row for CSV export.
struct ValidationEntry {
    let measurement: String
    let estimatedCm: Double
    let manualCm: Double
    let errorCm: Double
    let pass: Bool
}

enum JSONExportService {

    /// Writes session as pretty-printed JSON to temp file; returns URL for share sheet.
    static func exportJSON(session: ScanSessionModel) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "scan_result_\(formatter.string(from: session.sessionTimestamp)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        guard let data = session.prettyPrintedJSON()?.data(using: .utf8) else { return url }
        try? data.write(to: url)
        return url
    }

    /// Writes validation results to CSV; returns URL for share sheet.
    static func exportCSV(results: [ValidationEntry]) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "validation_report_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        var csv = "Measurement,Estimated_cm,Manual_cm,Error_cm,Pass\n"
        for r in results {
            csv += "\(r.measurement),\(r.estimatedCm),\(r.manualCm),\(r.errorCm),\(r.pass ? "PASS" : "FAIL")\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
