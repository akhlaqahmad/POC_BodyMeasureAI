//
//  BodyProportionModel.swift
//  BodyMeasureAI
//
//  Data model holding all body measurements from a single capture.
//

import Foundation

/// All measurements from one body capture. No garment or classification data.
struct BodyProportionModel {
    /// M1: Shoulder circumference estimate (cm) — elliptical approximation
    var m1ShoulderCircumferenceCm: Double
    /// M2: Hip circumference estimate (cm) — elliptical approximation
    var m2HipCircumferenceCm: Double
    /// M3: Waist circumference estimate (cm) — elliptical approximation
    var m3WaistCircumferenceCm: Double
    /// V1: Torso height — top of head to widest hip point (cm)
    var v1TorsoHeightCm: Double
    /// V2: Leg length — widest hip point to floor (cm)
    var v2LegLengthCm: Double
    /// Waist prominence score 0.0–1.0 (monocular heuristic proxy for belly depth)
    var waistProminenceScore: Double
    /// Confidence of this capture (0.0–1.0)
    var captureConfidence: Double
    /// When the capture was taken
    var timestamp: Date
}
