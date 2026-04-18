//
//  ScanSessionModel.swift
//  BodyMeasureAI
//
//  Combined model for full session: body + classification + garment. Produces final JSON.
//

import Foundation

/// Single combined model for full scan session output (body + garment).
struct ScanSessionModel {
    let sessionId: String
    let sessionTimestamp: Date
    let userInputs: (heightCm: Double, gender: String)
    let bodyMeasurements: BodyProportionModel
    let bodyClassification: (positiveMessage: String, verticalType: String, isPetite: Bool)
    let garmentAnalysis: GarmentTagModel
    let captureConfidence: Double

    init(
        sessionId: String = UUID().uuidString,
        sessionTimestamp: Date = Date(),
        userInputs: (heightCm: Double, gender: String),
        bodyMeasurements: BodyProportionModel,
        bodyClassification: (positiveMessage: String, verticalType: String, isPetite: Bool),
        garmentAnalysis: GarmentTagModel,
        captureConfidence: Double
    ) {
        self.sessionId = sessionId
        self.sessionTimestamp = sessionTimestamp
        self.userInputs = userInputs
        self.bodyMeasurements = bodyMeasurements
        self.bodyClassification = bodyClassification
        self.garmentAnalysis = garmentAnalysis
        self.captureConfidence = captureConfidence
    }

    /// Build from body scan result + garment result.
    static func from(bodyResult: BodyScanResult, garmentResult: GarmentTagModel) -> ScanSessionModel {
        ScanSessionModel(
            sessionTimestamp: bodyResult.measurements.timestamp,
            userInputs: (bodyResult.userHeightCm, bodyResult.gender),
            bodyMeasurements: bodyResult.measurements,
            bodyClassification: (bodyResult.positiveMessage, bodyResult.verticalType, bodyResult.isPetite),
            garmentAnalysis: garmentResult,
            captureConfidence: bodyResult.measurements.captureConfidence
        )
    }

    /// Final combined JSON (matches spec exactly).
    var exportJSON: [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = iso.string(from: sessionTimestamp)
        return [
            "sessionId": sessionId,
            "scanTimestamp": timestampString,
            "userInputs": [
                "heightCm": userInputs.heightCm,
                "gender": userInputs.gender
            ] as [String: Any],
            "bodyMeasurements": bodyMeasurementsExport,
            "bodyClassification": bodyClassificationExport,
            "garmentAnalysis": garmentAnalysis.exportJSON,
            "captureConfidence": captureConfidence
        ] as [String: Any]
    }

    private var bodyMeasurementsExport: [String: Any] {
        [
            "M1_shoulderCircumferenceCm": bodyMeasurements.m1ShoulderCircumferenceCm,
            "M2_hipCircumferenceCm": bodyMeasurements.m2HipCircumferenceCm,
            "M3_waistCircumferenceCm": bodyMeasurements.m3WaistCircumferenceCm,
            "V1_torsoHeightCm": bodyMeasurements.v1TorsoHeightCm,
            "V2_legLengthCm": bodyMeasurements.v2LegLengthCm,
            "waistProminenceScore": bodyMeasurements.waistProminenceScore
        ]
    }

    private var bodyClassificationExport: [String: Any] {
        var c: [String: Any] = [
            "verticalType": bodyClassification.verticalType,
            "isPetite": bodyClassification.isPetite,
            "positiveMessage": bodyClassification.positiveMessage
        ]
        if bodyClassification.isPetite {
            c["petiteStylingNote"] =
                "Vertical lines and clean single-colour dressing add beautiful length."
        }
        return c
    }

    func prettyPrintedJSON() -> String? {
        let json = exportJSON
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}
