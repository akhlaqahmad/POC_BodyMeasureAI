//
//  KeypointNormalizer.swift
//  BodyMeasureAI
//
//  Converts Vision body pose keypoints (normalized 0–1) to real-world cm
//  using user height as scale anchor. All math documented inline.
//

import Foundation
import Vision

/// Converts Vision keypoints (normalized coordinates) to real-world measurements in cm.
/// Uses user-provided height as the scale anchor: head-to-ankle distance in the image
/// is assumed to represent the user's height in cm.
final class KeypointNormalizer {

    // MARK: - Constants

    /// Typical capture distance 2.0–2.5 m. Perspective makes the top of the body
    /// (head/shoulders) appear slightly smaller than the lower body (hips/ankles).
    /// Factor applied to vertical measurements to correct for this.
    /// 1.0 = no correction; slight >1.0 compensates for perspective shortening at top.
    private static let perspectiveCorrectionVertical: Double = 1.02

    /// Minimum confidence (0–1) for a keypoint to be used in scale or measurement.
    /// POC: slightly lower to 0.2 so we can still work in noisier conditions.
    private static let minKeypointConfidence: Float = 0.2

    // MARK: - Public API

    /// User height in cm — used as the scale anchor for all measurements.
    let userHeightCm: Double

    /// Gender is used to pick depth ratios (men carry thickness higher up,
    /// women's hip depth/waist ratio differ slightly). Defaults to
    /// `nonBinary` which uses neutral ratios.
    let gender: Gender

    init(userHeightCm: Double, gender: Gender = .nonBinary) {
        self.userHeightCm = userHeightCm
        self.gender = gender
    }

    /// Depth ratios (body depth ÷ body width) per measurement and gender.
    /// These multiply the real width to get the ellipse minor axis before
    /// feeding into the Ramanujan circumference formula.
    private struct DepthRatios {
        let shoulder: Double
        let hip: Double
        let waist: Double
    }

    private var depthRatios: DepthRatios {
        switch gender {
        case .male:
            return DepthRatios(shoulder: 0.45, hip: 0.58, waist: 0.45)
        case .female:
            return DepthRatios(shoulder: 0.40, hip: 0.58, waist: 0.40)
        case .nonBinary:
            return DepthRatios(shoulder: 0.42, hip: 0.58, waist: 0.42)
        }
    }

    /// Converts a body pose observation into a BodyProportionModel with M1, M2, M3, V1, V2 in cm.
    /// - Parameters:
    ///   - observation: Vision body pose result (normalized 0–1 coordinates).
    ///   - overallConfidence: Optional overall confidence 0–1 for the capture.
    /// - Returns: BodyProportionModel with measurements in cm, or nil if keypoints are insufficient.
    func normalize(
        _ observation: VNHumanBodyPoseObservation,
        overallConfidence: Double = 1.0
    ) -> BodyProportionModel? {
        guard let scaleFactor = computeScaleFactor(observation) else { return nil }

        // Get raw widths in cm FIRST (normalized width × scaleFactor).
        guard let rawM1Cm = extractM1RawWidthCm(observation, scaleFactor: scaleFactor),
              let rawM2Cm = extractM2RawWidthCm(observation, scaleFactor: scaleFactor),
              let rawM3Cm = extractM3RawWidthCm(observation, scaleFactor: scaleFactor) else {
            return nil
        }

        // NOW apply elliptical circumference on real cm values (halfWidth in cm).
        let ratios = depthRatios
        let m1 = ellipticalCircumference(halfWidth: rawM1Cm / 2, depthRatio: ratios.shoulder)
        let m2 = ellipticalCircumference(halfWidth: rawM2Cm / 2, depthRatio: ratios.hip)
        let m3 = ellipticalCircumference(halfWidth: rawM3Cm / 2, depthRatio: ratios.waist)

        print("[DEBUG] scaleFactor=\(scaleFactor)")
        print("[DEBUG] rawM1=\(rawM1Cm) → circ=\(m1)")
        print("[DEBUG] rawM2=\(rawM2Cm) → circ=\(m2)")
        print("[DEBUG] rawM3=\(rawM3Cm) → circ=\(m3)")

        // --- Vertical measurements (cm), with perspective correction ---
        guard
            let v1 = extractV1TorsoHeight(observation, scaleFactor: scaleFactor),
            let v2 = extractV2LegLength(observation, scaleFactor: scaleFactor)
        else {
            return nil
        }
        print("[DEBUG] V1=\(v1) V2=\(v2)")

        // Waist prominence proxy (monocular heuristic, 0–1)
        let waistProminenceScore = computeWaistProminenceScore(observation)

        return BodyProportionModel(
            m1ShoulderCircumferenceCm: m1,
            m2HipCircumferenceCm: m2,
            m3WaistCircumferenceCm: m3,
            v1TorsoHeightCm: v1,
            v2LegLengthCm: v2,
            waistProminenceScore: waistProminenceScore,
            captureConfidence: overallConfidence,
            timestamp: Date()
        )
    }

    // MARK: - Elliptical circumference

    /// Elliptical circumference (Ramanujan) from REAL cm measurements.
    /// a = half the real side-to-side width in cm
    /// b = estimated front-to-back depth = a × depthRatio
    ///
    /// Body depth ratios:
    ///   Shoulder: 0.42 → typical shoulder depth ~42% of width
    ///   Hip:     0.62 → typical hip depth ~62% of width
    ///   Waist:   0.55 → typical waist depth ~55% of width
    ///
    /// Expected results for average adult:
    ///   M1 shoulder: ~38cm width → circumference ~90–100cm
    ///   M2 hip:      ~42cm width → circumference ~95–105cm
    ///   M3 waist:    ~32cm width → circumference ~75–85cm
    private func ellipticalCircumference(halfWidth a: Double, depthRatio: Double) -> Double {
        let b = a * depthRatio
        return Double.pi * (3 * (a + b) - sqrt((3 * a + b) * (a + 3 * b)))
    }

    /// Waist prominence proxy (monocular heuristic 0–1).
    /// If root Y is displaced below hip-mid Y by >5% of normalized body height,
    /// this suggests front belly mass; ratio scaled into [0, 1].
    private func computeWaistProminenceScore(_ observation: VNHumanBodyPoseObservation) -> Double {
        let root = point(for: .root, in: observation)
        let lh = point(for: .leftHip, in: observation)
        let rh = point(for: .rightHip, in: observation)
        let nose = point(for: .nose, in: observation)
        let la = point(for: .leftAnkle, in: observation)
        let ra = point(for: .rightAnkle, in: observation)
        guard
            let r = root,
            let l = lh,
            let rightHip = rh,
            let n = nose,
            let la = la,
            let ra = ra
        else {
            return 0.0
        }
        let hipMidY = (l.y + rightHip.y) / 2
        let ankleMidY = (la.y + ra.y) / 2
        let displacement = max(0, r.y - hipMidY)
        let normalizedBodyHeight = abs(ankleMidY - n.y)
        guard normalizedBodyHeight > 0 else { return 0.0 }
        let ratio = displacement / normalizedBodyHeight
        if ratio > 0.05 {
            return min(1.0, ratio * 10.0)
        } else {
            return 0.0
        }
    }

    // MARK: - Scale factor (cm per normalized unit)

    /// Computes scale factor: real-world cm per normalized-distance-unit.
    ///
    /// Primary anchor is nose→ankle (best-covered vertical span). For back
    /// views the nose isn't detected, so we fall back to mid-shoulder→ankle
    /// and scale by the typical shoulder-to-floor ratio of body height
    /// (~0.83). Further fallbacks go through single ankle and then knees.
    ///
    /// `userHeightCm / fullHeightEstimate` → 1 normalized unit == scaleFactor cm.
    private func computeScaleFactor(_ observation: VNHumanBodyPoseObservation) -> Double? {
        let nose = point(for: .nose, in: observation)
        let leftShoulder = point(for: .leftShoulder, in: observation)
        let rightShoulder = point(for: .rightShoulder, in: observation)
        let leftAnkle = point(for: .leftAnkle, in: observation)
        let rightAnkle = point(for: .rightAnkle, in: observation)
        let leftKnee = point(for: .leftKnee, in: observation)
        let rightKnee = point(for: .rightKnee, in: observation)

        // Top anchor: prefer nose; fall back to shoulder midpoint (scaled to
        // a full-height equivalent so downstream math is unchanged).
        let shoulderMid: (x: Double, y: Double)? = {
            guard let ls = leftShoulder, let rs = rightShoulder else { return nil }
            return ((ls.x + rs.x) / 2, (ls.y + rs.y) / 2)
        }()

        // Returns (topPoint, fullHeightFraction): fraction of body height the
        // top point represents (1.0 for nose, ~0.83 for shoulder mid).
        // Drawn from typical adult proportions (top of head ~1.0, shoulders
        // ~0.83, navel ~0.60).
        let topAnchor: ((x: Double, y: Double), Double)? = {
            if let n = nose { return (n, 1.0) }
            if let sm = shoulderMid { return (sm, 0.83) }
            return nil
        }()

        guard let (top, topFraction) = topAnchor else { return nil }

        // Prefer ankle midpoint (most accurate full-height estimate).
        if let la = leftAnkle, let ra = rightAnkle {
            let ankleMidX = (la.x + ra.x) / 2
            let ankleMidY = (la.y + ra.y) / 2
            let dx = ankleMidX - top.x
            let dy = ankleMidY - top.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return nil }
            // Normalize dist to "full body height equivalent" then divide into userHeightCm.
            return userHeightCm / (dist / topFraction)
        }

        // Fallback: single ankle if only one is visible.
        if let la = leftAnkle {
            let dx = la.x - top.x
            let dy = la.y - top.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return nil }
            return userHeightCm / (dist / topFraction)
        }
        if let ra = rightAnkle {
            let dx = ra.x - top.x
            let dy = ra.y - top.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return nil }
            return userHeightCm / (dist / topFraction)
        }

        // Last fallback: knees. Nose-to-knee ≈ 0.65 × full height;
        // shoulder-mid-to-knee ≈ 0.48. Ratio = topFraction - 0.35 covers both.
        if let lk = leftKnee, let rk = rightKnee {
            let kneeMidX = (lk.x + rk.x) / 2
            let kneeMidY = (lk.y + rk.y) / 2
            let dx = kneeMidX - top.x
            let dy = kneeMidY - top.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return nil }
            let kneeFraction = max(0.4, topFraction - 0.35)
            return userHeightCm / (dist / kneeFraction)
        }

        return nil
    }

    /// M1: Shoulder raw width in cm. Normalized width × scaleFactor (convert to cm first).
    private func extractM1RawWidthCm(
        _ observation: VNHumanBodyPoseObservation,
        scaleFactor: Double
    ) -> Double? {
        let ls = point(for: .leftShoulder, in: observation)
        let rs = point(for: .rightShoulder, in: observation)
        guard let l = ls, let r = rs else { return nil }
        let normalizedWidth = abs(r.x - l.x)
        return normalizedWidth * scaleFactor
    }

    /// M2: Hip raw width in cm. Normalized width × scaleFactor (convert to cm first).
    private func extractM2RawWidthCm(
        _ observation: VNHumanBodyPoseObservation,
        scaleFactor: Double
    ) -> Double? {
        let lh = point(for: .leftHip, in: observation)
        let rh = point(for: .rightHip, in: observation)
        guard let l = lh, let r = rh else { return nil }
        let normalizedWidth = abs(r.x - l.x)
        return normalizedWidth * scaleFactor
    }

    /// M3: Waist raw width in cm.
    ///
    /// The Vision `root` joint sits at the pelvis, not the anatomical waist,
    /// so using it as a waist point inflates the reading (observed 92 cm vs
    /// 67 cm true waist in client testing). Instead we interpolate left- and
    /// right-side points at ~35% of the shoulder→hip distance from the
    /// shoulders, which is the anatomical waist position.
    ///
    /// Fallback chain:
    ///   1. Interpolate L/R waist from shoulders + hips (preferred).
    ///   2. `hip * 0.78` if shoulders are missing.
    private func extractM3RawWidthCm(
        _ observation: VNHumanBodyPoseObservation,
        scaleFactor: Double
    ) -> Double? {
        let ls = point(for: .leftShoulder, in: observation)
        let rs = point(for: .rightShoulder, in: observation)
        let lh = point(for: .leftHip, in: observation)
        let rh = point(for: .rightHip, in: observation)

        if let leftShoulder = ls, let rightShoulder = rs,
           let leftHip = lh, let rightHip = rh {
            // 35% of the vertical drop from shoulder to hip lands roughly at
            // the natural waist (narrowest torso cross-section).
            let t = 0.35
            let leftWaistX = leftShoulder.x + (leftHip.x - leftShoulder.x) * t
            let rightWaistX = rightShoulder.x + (rightHip.x - rightShoulder.x) * t
            let normalizedWidth = abs(rightWaistX - leftWaistX)
            return normalizedWidth * scaleFactor
        }

        guard let m2 = extractM2RawWidthCm(observation, scaleFactor: scaleFactor) else { return nil }
        return m2 * 0.78
    }

    /// V1: Torso height (cm). Nose→hip-midpoint when the face is visible
    /// (front/side scans); shoulder-midpoint→hip-midpoint when it isn't
    /// (back scans). The shoulder-based definition is the anatomically
    /// correct torso height — we only use the nose anchor on front/side
    /// to preserve prior calibration.
    private func extractV1TorsoHeight(
        _ observation: VNHumanBodyPoseObservation,
        scaleFactor: Double
    ) -> Double? {
        let nose = point(for: .nose, in: observation)
        let ls = point(for: .leftShoulder, in: observation)
        let rs = point(for: .rightShoulder, in: observation)
        let lh = point(for: .leftHip, in: observation)
        let rh = point(for: .rightHip, in: observation)
        guard let l = lh, let r = rh else { return nil }
        let hipMidY = (l.y + r.y) / 2
        let hipMidX = (l.x + r.x) / 2

        let topX: Double
        let topY: Double
        let correction: Double

        if let n = nose {
            topX = n.x
            topY = n.y
            correction = Self.perspectiveCorrectionVertical
        } else if let leftShoulder = ls, let rightShoulder = rs {
            topX = (leftShoulder.x + rightShoulder.x) / 2
            topY = (leftShoulder.y + rightShoulder.y) / 2
            // Shoulder→hip is ~0.82x nose→hip on an adult frame; scale up so
            // the reported torso height stays comparable to the nose-anchored
            // path the classifier is calibrated against.
            correction = Self.perspectiveCorrectionVertical / 0.82
        } else {
            return nil
        }

        let dy = hipMidY - topY
        let dx = hipMidX - topX
        let normalizedTorso = sqrt(dx * dx + dy * dy)
        let cm = normalizedTorso * scaleFactor
        return cm * correction
    }

    /// V2: Leg length (cm). Hip midpoint to ankle midpoint (floor level).
    /// Perspective correction applied.
    private func extractV2LegLength(
        _ observation: VNHumanBodyPoseObservation,
        scaleFactor: Double
    ) -> Double? {
        let lh = point(for: .leftHip, in: observation)
        let rh = point(for: .rightHip, in: observation)
        let la = point(for: .leftAnkle, in: observation)
        let ra = point(for: .rightAnkle, in: observation)
        guard let l = lh, let r = rh, let la = la, let ra = ra else { return nil }
        let hipMidX = (l.x + r.x) / 2
        let hipMidY = (l.y + r.y) / 2
        let ankleMidX = (la.x + ra.x) / 2
        let ankleMidY = (la.y + ra.y) / 2
        let dy = ankleMidY - hipMidY
        let dx = ankleMidX - hipMidX
        let normalizedLeg = sqrt(dx * dx + dy * dy)
        let cm = normalizedLeg * scaleFactor
        return cm * Self.perspectiveCorrectionVertical
    }

    /// Returns (x, y) in normalized 0–1 and confidence for a joint, or nil if below confidence.
    private func point(
        for joint: VNHumanBodyPoseObservation.JointName,
        in observation: VNHumanBodyPoseObservation
    ) -> (x: Double, y: Double)? {
        guard observation.availableJointNames.contains(joint) else { return nil }
        let pt = try? observation.recognizedPoint(joint)
        guard let p = pt, p.confidence >= Self.minKeypointConfidence else { return nil }
        return (Double(p.location.x), Double(p.location.y))
    }
}
