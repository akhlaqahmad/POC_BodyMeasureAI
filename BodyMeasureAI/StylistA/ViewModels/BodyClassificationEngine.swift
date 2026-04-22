//
//  BodyClassificationEngine.swift
//  BodyMeasureAI
//
//  Classifies body from M1, M2, M3, V1, V2 and user height.
//  Returns only the positive message string — never the shape label — to the UI.
//

import Foundation

/// Classification result: vertical type, petite flag, and the single positive message for UI.
struct BodyClassificationOutput {
    let verticalType: String
    let isPetite: Bool
    let positiveMessage: String
}

/// Runs body classification from measurements. Never exposes shape labels to UI.
final class BodyClassificationEngine {

    // MARK: - Thresholds (cm)

    private static let horizontalTolerance: Double = 7.62   // ~3 inches
    private static let verticalTolerance: Double = 6.35     // ~2.5 inches
    private static let broadShoulderMargin: Double = 15.0   // men: M1 > M2 + 15
    private static let petiteHeightCm: Double = 165.0

    /// Classifies and returns vertical type, isPetite, and positive message only.
    func classify(
        m1: Double, m2: Double, m3: Double,
        v1: Double, v2: Double,
        userHeightCm: Double,
        gender: Gender,
        waistProminenceScore: Double = 0.0
    ) -> BodyClassificationOutput {
        switch gender {
        case .female:
            return classifyWomen(
                m1: m1, m2: m2, m3: m3, v1: v1, v2: v2,
                userHeightCm: userHeightCm, usesGenderedLanguage: true
            )
        case .male:
            return classifyMen(m1: m1, m2: m2, m3: m3, waistProminenceScore: waistProminenceScore)
        case .nonBinary:
            // Uses the 5-shape logic (more nuanced than the male path) but with
            // gender-neutral phrasing so nothing in the output reads as feminine.
            return classifyWomen(
                m1: m1, m2: m2, m3: m3, v1: v1, v2: v2,
                userHeightCm: userHeightCm, usesGenderedLanguage: false
            )
        }
    }

    // MARK: - Women

    private func classifyWomen(
        m1: Double, m2: Double, m3: Double,
        v1: Double, v2: Double,
        userHeightCm: Double,
        usesGenderedLanguage: Bool
    ) -> BodyClassificationOutput {
        let vertical = verticalType(v1: v1, v2: v2)
        let isPetite = userHeightCm < Self.petiteHeightCm

        // Horizontal shape (we never return the label; only pick the message)
        let message: String
        if isHourglass(m1: m1, m2: m2, m3: m3) {
            message = usesGenderedLanguage
                ? "Your beautiful proportions mean we can highlight your natural waist and celebrate your balanced curves."
                : "Your proportions allow us to highlight your natural waistline and show off balanced shape."
        } else if isRectangle(m1: m1, m2: m2, m3: m3) {
            message = usesGenderedLanguage
                ? "Your elegant frame gives us the opportunity to create soft curves and define a graceful waistline."
                : "Your frame gives us room to add soft shape and define a clean waistline."
        } else if isInvertedTriangle(m1: m1, m2: m2) {
            message = usesGenderedLanguage
                ? "We'll focus on balancing your confident shoulders with styles that enhance your lower half."
                : "We'll balance your strong shoulders with styles that add definition below."
        } else if isTriangle(m1: m1, m2: m2) {
            message = usesGenderedLanguage
                ? "Your gorgeous hips give us a chance to draw attention upward and create beautiful balance."
                : "We'll draw attention upward to balance your lower half and create a cleaner line."
        } else if isRound(m1: m1, m2: m2, m3: m3) {
            message = usesGenderedLanguage
                ? "Now that we know your lovely shape, we can choose styles that enhance your best features."
                : "Now that we know your shape, we can choose styles that highlight your best features."
        } else {
            message = usesGenderedLanguage
                ? "Your elegant frame gives us the opportunity to create soft curves and define a graceful waistline."
                : "Your frame gives us room to add soft shape and define a clean waistline."
        }

        let petiteNote = " As a petite frame, vertical lines and clean single-colour dressing will add beautiful length."
        let finalMessage = message + (isPetite ? petiteNote : "")

        return BodyClassificationOutput(
            verticalType: vertical,
            isPetite: isPetite,
            positiveMessage: finalMessage
        )
    }

    /// Hourglass: abs(M1-M2) <= 7.62 AND M3 < M1 AND M3 < M2 AND (M1-M3 > 7.62 AND M2-M3 > 7.62)
    private func isHourglass(m1: Double, m2: Double, m3: Double) -> Bool {
        let t = Self.horizontalTolerance
        guard abs(m1 - m2) <= t else { return false }
        guard m3 < m1 && m3 < m2 else { return false }
        return (m1 - m3) > t && (m2 - m3) > t
    }

    /// Rectangle: abs(M1-M2) <= 7.62 AND NOT clearly defined waist (i.e. not hourglass)
    private func isRectangle(m1: Double, m2: Double, m3: Double) -> Bool {
        guard abs(m1 - m2) <= Self.horizontalTolerance else { return false }
        return !isHourglass(m1: m1, m2: m2, m3: m3)
    }

    /// Inverted Triangle: M1 > M2 + 7.62
    private func isInvertedTriangle(m1: Double, m2: Double) -> Bool {
        m1 > m2 + Self.horizontalTolerance
    }

    /// Triangle: M2 > M1 + 7.62
    private func isTriangle(m1: Double, m2: Double) -> Bool {
        m2 > m1 + Self.horizontalTolerance
    }

    /// Round: M3 > M1 + 7.62 OR M3 > M2 + 7.62
    private func isRound(m1: Double, m2: Double, m3: Double) -> Bool {
        let t = Self.horizontalTolerance
        return m3 > m1 + t || m3 > m2 + t
    }

    /// Vertical: Balanced, Long Torso, or Short Torso (we only use for JSON; message is horizontal-based)
    private func verticalType(v1: Double, v2: Double) -> String {
        let t = Self.verticalTolerance
        if abs(v1 - v2) <= t { return "balanced" }
        if v1 > v2 + t { return "longTorso" }
        return "shortTorso"
    }

    // MARK: - Men

    private func classifyMen(m1: Double, m2: Double, m3: Double, waistProminenceScore: Double) -> BodyClassificationOutput {
        let message: String
        if m1 > m2 + Self.broadShoulderMargin {
            message = "Let's balance your strong upper body with styles that add subtle structure below."
        } else if m2 > m1 + Self.broadShoulderMargin {
            message = "We'll choose cuts that strengthen your upper profile and bring everything into sleek proportion."
        } else if waistProminenceScore > 0.5 {
            message = "We'll focus on clean lines and cuts that smooth and flatter your midsection."
        } else if m3 > m1 + Self.horizontalTolerance || m3 > m2 + Self.horizontalTolerance {
            message = "We'll add shape where it counts, using smart tailoring for a crisp, confident look."
        } else {
            message = "Great proportions — let's tailor the fit and style to suit your life and personality."
        }
        return BodyClassificationOutput(
            verticalType: "balanced",
            isPetite: false,
            positiveMessage: message
        )
    }
}
