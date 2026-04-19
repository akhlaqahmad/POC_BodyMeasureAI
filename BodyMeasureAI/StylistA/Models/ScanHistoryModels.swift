//
//  ScanHistoryModels.swift
//  BodyMeasureAI
//
//  Codable wire-format models for GET /api/my/sessions. Kept separate from
//  the capture-time models (BodyScanResult etc.) because those use tuples
//  that don't play nicely with Codable.
//

import Foundation

struct ScanHistoryResponse: Decodable {
    let sessions: [ScanHistoryItem]
}

struct ScanHistoryItem: Decodable, Identifiable {
    let id: String
    let scanTimestamp: Date
    let captureConfidence: Double
    let bodyMeasurements: BodyMeasurementsDTO?
    let bodyClassification: BodyClassificationDTO?
    let garments: [GarmentDTO]

    struct BodyMeasurementsDTO: Decodable {
        let shoulder: Double
        let hip: Double
        let waist: Double
        let torsoHeight: Double
        let legLength: Double
        let waistProminenceScore: Double

        private enum CodingKeys: String, CodingKey {
            case shoulder = "M1_shoulderCircumferenceCm"
            case hip = "M2_hipCircumferenceCm"
            case waist = "M3_waistCircumferenceCm"
            case torsoHeight = "V1_torsoHeightCm"
            case legLength = "V2_legLengthCm"
            case waistProminenceScore
        }
    }

    struct BodyClassificationDTO: Decodable {
        let verticalType: String
        let isPetite: Bool
        let positiveMessage: String
        let petiteStylingNote: String?
    }

    struct GarmentDTO: Decodable, Identifiable {
        let id: String
        let category: String
        let subcategory: String
        let primaryColors: [String]
        let pattern: String
        let silhouette: String
        let neckline: String?
        let sleeveLength: String?
        let garmentLength: String
        let visualWeight: String
        let classificationConfidence: Double
    }
}
