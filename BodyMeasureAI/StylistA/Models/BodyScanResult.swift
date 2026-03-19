//
//  BodyScanResult.swift
//  BodyMeasureAI
//
//  Full result of a body scan: measurements + classification (positive message only).
//

import Foundation

/// Multi-angle capture bundle (front/side/back). Stored for export and UI display.
struct MultiAngleMeasurements {
    let front: BodyProportionModel
    let side: BodyProportionModel
    let back: BodyProportionModel
}

/// Result published to the UI after a successful capture: measurements + classification message.
struct BodyScanResult {
    let measurements: BodyProportionModel
    let positiveMessage: String
    let verticalType: String
    let isPetite: Bool
    let userHeightCm: Double
    let gender: String
    /// Optional garment analysis (Part 2); included in export when set.
    var garmentAnalysis: GarmentTagModel? = nil
    /// Optional 3-angle measurements (front/side/back) from MultiAngleBodyScanView.
    var multiAngleMeasurements: MultiAngleMeasurements? = nil

    /// JSON structure for export (matches spec). Includes garmentAnalysis when present.
    var exportJSON: [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = iso.string(from: measurements.timestamp)
        var out: [String: Any] = [
            "sessionId": UUID().uuidString,
            "scanTimestamp": timestampString,
            "userInputs": [
                "heightCm": userHeightCm,
                "gender": gender
            ] as [String: Any],
            "bodyMeasurements": bodyMeasurementsExport,
            "bodyClassification": bodyClassificationExport,
            "captureConfidence": measurements.captureConfidence
        ] as [String: Any]
        if let garment = garmentAnalysis {
            out["garmentAnalysis"] = garment.exportJSON
        }
        if let angles = multiAngleMeasurements {
            out["multiAngleBodyMeasurements"] = [
                "front": bodyMeasurementsExport(for: angles.front),
                "side": bodyMeasurementsExport(for: angles.side),
                "back": bodyMeasurementsExport(for: angles.back)
            ]
            out["multiAngleCaptureConfidence"] = [
                "front": angles.front.captureConfidence,
                "side": angles.side.captureConfidence,
                "back": angles.back.captureConfidence
            ]
        }
        return out
    }

    private var bodyMeasurementsExport: [String: Any] {
        bodyMeasurementsExport(for: measurements)
    }

    private func bodyMeasurementsExport(for m: BodyProportionModel) -> [String: Any] {
        [
            "M1_shoulderCircumferenceCm": m.m1ShoulderCircumferenceCm,
            "M2_hipCircumferenceCm": m.m2HipCircumferenceCm,
            "M3_waistCircumferenceCm": m.m3WaistCircumferenceCm,
            "V1_torsoHeightCm": m.v1TorsoHeightCm,
            "V2_legLengthCm": m.v2LegLengthCm,
            "waistProminenceScore": m.waistProminenceScore
        ]
    }

    private var bodyClassificationExport: [String: Any] {
        var c: [String: Any] = [
            "verticalType": verticalType,
            "isPetite": isPetite,
            "positiveMessage": positiveMessage
        ]
        if isPetite {
            c["petiteStylingNote"] =
                "Vertical lines and clean single-colour dressing add beautiful length."
        }
        return c
    }

    /// Pretty-printed JSON string for display and share.
    func prettyPrintedJSON() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: exportJSON, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}
