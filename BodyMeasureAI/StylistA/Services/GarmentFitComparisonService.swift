//
//  GarmentFitComparisonService.swift
//  BodyMeasureAI
//
//  Compares a garment's physical measurements against a BodyScanResult and
//  returns a fit assessment (snug / regular / relaxed / oversized).
//

import Foundation

final class GarmentFitComparisonService {

    /// Ease (garment width minus body half-circumference × 2) thresholds, cm.
    /// Negative ease means the garment is smaller than the body — clothing
    /// can't actually be smaller than the wearer in a static sense, so we
    /// treat negative values as snug/oversized depending on sign.
    private struct EaseBand {
        let snugUpper: Double      // ≤ this → snug
        let regularUpper: Double   // ≤ this → regular
        let relaxedUpper: Double   // ≤ this → relaxed; above → oversized
    }

    /// Per-measurement thresholds; roughly aligned with RTW ease conventions.
    private let band = EaseBand(snugUpper: 3, regularUpper: 7, relaxedUpper: 12)

    /// Compare a garment's physical dimensions to the body. Returns nil when
    /// the garment has no measurements to compare against.
    func compare(
        garmentMeasurements: GarmentMeasurements?,
        body: BodyProportionModel
    ) -> GarmentFitAssessment? {
        guard let g = garmentMeasurements else { return nil }

        // Garment width (flat-lay) ≈ half of circumference, so compare
        // `g.chestWidthCm * 2` against the body circumference.
        let easeChest = ease(garmentWidthCm: g.chestWidthCm, bodyCircumferenceCm: body.m1ShoulderCircumferenceCm)
        let easeWaist = ease(garmentWidthCm: g.waistWidthCm,  bodyCircumferenceCm: body.m3WaistCircumferenceCm)
        let easeHip   = ease(garmentWidthCm: nil,             bodyCircumferenceCm: body.m2HipCircumferenceCm)

        // Pick the most informative signal available, preferring chest for
        // tops and waist/hip for bottoms/dresses. POC: use whichever ease
        // value we have first.
        let signalEase = easeChest ?? easeWaist ?? easeHip
        let overallFit: GarmentFitRating = rating(forEaseCm: signalEase)

        let notes: String? = {
            guard let e = signalEase else { return "Insufficient data for fit assessment" }
            return String(format: "Ease %.1f cm — %@", e, overallFit.rawValue)
        }()

        return GarmentFitAssessment(
            overallFit: overallFit,
            easeChestCm: easeChest,
            easeWaistCm: easeWaist,
            easeHipCm: easeHip,
            notes: notes
        )
    }

    /// Ease = garment circumference (2 × flat width) − body circumference.
    private func ease(garmentWidthCm: Double?, bodyCircumferenceCm: Double) -> Double? {
        guard let g = garmentWidthCm, g > 0 else { return nil }
        return (g * 2) - bodyCircumferenceCm
    }

    private func rating(forEaseCm ease: Double?) -> GarmentFitRating {
        guard let e = ease else { return .unknown }
        if e < 0 { return .snug } // garment smaller than body → snug at best
        if e <= band.snugUpper { return .snug }
        if e <= band.regularUpper { return .regular }
        if e <= band.relaxedUpper { return .relaxed }
        return .oversized
    }
}
