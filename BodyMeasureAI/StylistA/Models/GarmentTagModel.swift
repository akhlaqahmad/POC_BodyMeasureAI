//
//  GarmentTagModel.swift
//  BodyMeasureAI
//
//  Codable struct holding all garment attributes from image analysis.
//

import Foundation

// MARK: - Category

enum GarmentCategory: String, Codable, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"
    case dress = "Dress"
    case outerwear = "Outerwear"
    case shoes = "Shoes"
    case accessory = "Accessory"
    case unknown = "Unknown"
}

// MARK: - Pattern

enum GarmentPattern: String, Codable, CaseIterable {
    case solid = "Solid"
    case striped = "Striped"
    case floral = "Floral"
    case checked = "Checked"
    case geometric = "Geometric"
    case animalPrint = "AnimalPrint"
    case unknown = "Unknown"
}

// MARK: - Silhouette

enum GarmentSilhouette: String, Codable, CaseIterable {
    case tailored = "Tailored"
    case relaxed = "Relaxed"
    case oversized = "Oversized"
    case flowing = "Flowing"
    case bodySkimming = "BodySkimming"
    case unknown = "Unknown"
}

// MARK: - Neckline

enum NecklineType: String, Codable, CaseIterable {
    case vNeck = "VNeck"
    case crew = "Crew"
    case scoop = "Scoop"
    case boat = "Boat"
    case square = "Square"
    case halter = "Halter"
    case highNeck = "HighNeck"
    case collared = "Collared"
    case unknown = "Unknown"
}

// MARK: - Sleeve length (display: "Long sleeve", etc.)

enum SleeveLength: String, Codable, CaseIterable {
    case sleeveless = "Sleeveless"
    case thinStrap = "Thin strap"
    case cap = "Cap sleeve"
    case short = "Short sleeve"
    case elbow = "Elbow"
    case threeQuarter = "Three-quarter"
    case long = "Long sleeve"
    case unknown = "Unknown"
}

// MARK: - Garment length (display: "Hip length", etc.)

enum GarmentLength: String, Codable, CaseIterable {
    case cropped = "Cropped"
    case waistLength = "Waist length"
    case hipLength = "Hip length"
    case midThigh = "Mid-thigh"
    case longline = "Longline"
    case mini = "Mini"
    case aboveKnee = "Above knee"
    case knee = "Knee"
    case midi = "Midi"
    case maxi = "Maxi"
    case unknown = "Unknown"
}

// MARK: - Visual weight

enum VisualWeight: String, Codable, CaseIterable {
    case light = "Light"
    case medium = "Medium"
    case heavy = "Heavy"
    case unknown = "Unknown"
}

// MARK: - Garment measurements (beta)

enum GarmentMeasurementMethod: String, Codable {
    case creditCard = "credit_card"
    case manual
    case unknown
}

struct GarmentMeasurements: Codable {
    var chestWidthCm: Double?
    var garmentLengthCm: Double?
    var shoulderWidthCm: Double?
    var waistWidthCm: Double?
    var method: GarmentMeasurementMethod
    var pixelsPerCm: Double?
    var confidence: Double?
}

enum GarmentFitRating: String, Codable {
    case snug
    case regular
    case relaxed
    case oversized
    case unknown
}

struct GarmentFitAssessment: Codable {
    var overallFit: GarmentFitRating
    var easeChestCm: Double?
    var easeWaistCm: Double?
    var easeHipCm: Double?
    var notes: String?
}

// MARK: - GarmentTagModel

struct GarmentTagModel: Codable {
    var category: GarmentCategory
    var subcategory: String
    var primaryColors: [String]
    var pattern: GarmentPattern
    var silhouette: GarmentSilhouette
    var neckline: NecklineType?
    var sleeveLength: SleeveLength?
    var garmentLength: GarmentLength
    var visualWeight: VisualWeight
    var classificationConfidence: Double
    var measurements: GarmentMeasurements?
    var fitAssessment: GarmentFitAssessment?
}

// MARK: - JSON export (matches spec)

extension GarmentTagModel {

    /// Export dict for "garmentAnalysis" section. Uses display-friendly strings.
    var exportJSON: [String: Any] {
        var out: [String: Any] = [
            "category": category.rawValue,
            "subcategory": subcategory,
            "primaryColors": primaryColors,
            "pattern": pattern.rawValue,
            "silhouette": silhouette.rawValue,
            "garmentLength": garmentLength.rawValue,
            "visualWeight": visualWeight.rawValue,
            "classificationConfidence": classificationConfidence
        ]
        if let n = neckline, n != .unknown { out["neckline"] = n.rawValue }
        if let s = sleeveLength, s != .unknown { out["sleeveLength"] = s.rawValue }
        if let m = measurements {
            var mDict: [String: Any] = ["method": m.method.rawValue]
            if let v = m.chestWidthCm { mDict["chestWidthCm"] = v }
            if let v = m.garmentLengthCm { mDict["garmentLengthCm"] = v }
            if let v = m.shoulderWidthCm { mDict["shoulderWidthCm"] = v }
            if let v = m.waistWidthCm { mDict["waistWidthCm"] = v }
            if let v = m.pixelsPerCm { mDict["pixelsPerCm"] = v }
            if let v = m.confidence { mDict["confidence"] = v }
            out["measurements"] = mDict
        }
        if let f = fitAssessment {
            var fDict: [String: Any] = ["overallFit": f.overallFit.rawValue]
            if let v = f.easeChestCm { fDict["easeChestCm"] = v }
            if let v = f.easeWaistCm { fDict["easeWaistCm"] = v }
            if let v = f.easeHipCm { fDict["easeHipCm"] = v }
            if let v = f.notes { fDict["notes"] = v }
            out["fitAssessment"] = fDict
        }
        return out
    }

    func prettyPrintedJSON() -> String? {
        let wrapper = ["garmentAnalysis": exportJSON] as [String: Any]
        guard let data = try? JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}
