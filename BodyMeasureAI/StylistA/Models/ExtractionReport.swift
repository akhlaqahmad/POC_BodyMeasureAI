//
//  ExtractionReport.swift
//  BodyMeasureAI
//
//  Per-scan QA telemetry. Bundled into BodyScanResult.exportJSON as the
//  `extractionReport` block, persisted by the backend into
//  scan_sessions.rawExport. Populated by the LandmarkSlicer caller.
//

import Foundation

struct ExtractionReport {
    /// Bumped when the slicer's blueprint table or interpolation factors
    /// change in a way that affects values. Lets us re-run analytics
    /// across versions.
    let parserVersion: Int
    /// Optional coverage by priority tier — fraction of expected codes
    /// captured. Iff iOS doesn't compute this, the backend derives it from
    /// the persisted measurements + taxonomy on its side.
    let coverage: Coverage?
    /// Soft warnings (anatomical sanity flags, low-confidence values).
    let warnings: [String]
    /// Wall-clock ms for the capture step.
    let captureMs: Int?
    /// Wall-clock ms for the segmentation step.
    let segmentationMs: Int?

    struct Coverage {
        let p0: Double
        let p1: Double
        let p2: Double
    }

    var exportJSON: [String: Any] {
        var out: [String: Any] = [
            "parserVersion": parserVersion,
            "warnings": warnings,
        ]
        if let coverage = coverage {
            out["coverage"] = [
                "P0": coverage.p0,
                "P1": coverage.p1,
                "P2": coverage.p2,
            ]
        }
        if let ms = captureMs { out["captureMs"] = ms }
        if let ms = segmentationMs { out["segmentationMs"] = ms }
        return out
    }
}
