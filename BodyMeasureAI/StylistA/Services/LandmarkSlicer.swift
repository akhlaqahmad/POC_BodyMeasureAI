//
//  LandmarkSlicer.swift
//  BodyMeasureAI
//
//  Derives the canonical body measurement set (taxonomy in
//  POC_BodyMeasureAI-backend/src/lib/measurements/taxonomy.ts) from a
//  front+side silhouette pair plus Vision keypoints.
//
//  Approach:
//    1. Build a per-mask scale factor from the user's height.
//    2. Locate ISO-8559 landmark Y-positions by interpolating between
//       Vision keypoints, with proportions calibrated against the 3DLOOK
//       reference sample (docs/Akhlaq test 1.pdf).
//    3. At each landmark Y, scan the front mask for width and the side mask
//       for depth.
//    4. For girths: feed (width, depth) into the Ramanujan ellipse perimeter.
//    5. For lengths/widths/heights: take the relevant span directly.
//    6. Confidence per measurement = min(mask quality at that Y, keypoint
//       confidence at the bounding keypoints, scale-anchor confidence).
//
//  This v1 implements every P0 measurement (~22) plus a handful of P1
//  examples that share the same machinery. Adding more measurements is a
//  matter of appending blueprint entries to `kBlueprints`.
//

import Foundation
import Vision

/// One captured measurement in the canonical taxonomy.
struct CapturedMeasurement: Hashable {
    let code: String
    let value: Double
    let unit: String      // "cm" or "deg"
    let confidence: Double
    let angle: String     // "front" | "side" | "back"
}

/// A horizontal slice on the body, identified by a fractional drop from
/// shoulder line (0.0) to hip line (1.0). Calibrated against the 3DLOOK
private struct LandmarkSlice {
    /// Fraction of the shoulder→hip span at which this landmark sits.
    /// 0.0 = shoulder line, 1.0 = hip line. Values >1.0 are below hips.
    let shoulderToHipFraction: Double
    /// Optional human-readable note for debugging.
    let debugLabel: String
}

/// Defines how one canonical measurement is derived from masks + keypoints.
private enum CaptureStrategy {
    /// Front-mask width × side-mask depth → Ramanujan ellipse circumference.
    case girth(slice: LandmarkSlice)
    /// Vertical distance from a slice line to a baseline (floor or another slice).
    case heightFromFloor(slice: LandmarkSlice)
    /// Front-mask width at a slice line.
    case frontWidth(slice: LandmarkSlice)
    /// Side-mask depth at a slice line.
    case sideDepth(slice: LandmarkSlice)
    /// Difference between two height blueprints, both resolved by code.
    case composite(minuendCode: String, subtrahendCode: String)
    /// Angle between two named keypoints, in degrees off horizontal.
    case poseAngle(left: VNHumanBodyPoseObservation.JointName,
                   right: VNHumanBodyPoseObservation.JointName)
}

private struct MeasurementBlueprint {
    let code: String
    let unit: String
    let strategy: CaptureStrategy
}

// ---------------------------------------------------------------------------
// Blueprint table — one row per implemented measurement. Ordering matters for
// `composite` strategies: the dependencies must be resolved first.
// ---------------------------------------------------------------------------

private let kBlueprints: [MeasurementBlueprint] = [
    // --- P0 girths --------------------------------------------------------
    MeasurementBlueprint(code: "upper_chest_girth",     unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 0.10, debugLabel: "upper chest"))),
    MeasurementBlueprint(code: "bust_girth",            unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 0.39, debugLabel: "bust"))),
    MeasurementBlueprint(code: "under_bust_girth",      unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 0.50, debugLabel: "under bust"))),
    MeasurementBlueprint(code: "waist_girth",           unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 0.67, debugLabel: "waist"))),
    MeasurementBlueprint(code: "upper_hip_girth",       unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 0.75, debugLabel: "upper hip"))),
    MeasurementBlueprint(code: "hip_girth",             unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 1.00, debugLabel: "hip"))),
    MeasurementBlueprint(code: "thigh_girth",           unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 1.30, debugLabel: "thigh"))),
    MeasurementBlueprint(code: "knee_girth",            unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 2.50, debugLabel: "knee"))),
    MeasurementBlueprint(code: "calf_girth",            unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 3.10, debugLabel: "calf"))),
    MeasurementBlueprint(code: "ankle_girth",           unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 3.95, debugLabel: "ankle"))),
    MeasurementBlueprint(code: "neck_girth",            unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: -0.20, debugLabel: "neck"))),
    MeasurementBlueprint(code: "upper_arm_girth",       unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 0.20, debugLabel: "upper arm"))),
    MeasurementBlueprint(code: "wrist_girth",           unit: "cm",
        strategy: .girth(slice: LandmarkSlice(shoulderToHipFraction: 1.40, debugLabel: "wrist"))),

    // --- P0 widths --------------------------------------------------------
    MeasurementBlueprint(code: "front_shoulder_width",  unit: "cm",
        strategy: .frontWidth(slice: LandmarkSlice(shoulderToHipFraction: 0.00, debugLabel: "shoulders"))),
    MeasurementBlueprint(code: "chest_width",           unit: "cm",
        strategy: .frontWidth(slice: LandmarkSlice(shoulderToHipFraction: 0.30, debugLabel: "chest"))),
    MeasurementBlueprint(code: "across_back_shoulder_width", unit: "cm",
        strategy: .frontWidth(slice: LandmarkSlice(shoulderToHipFraction: 0.05, debugLabel: "back shoulders"))),
    MeasurementBlueprint(code: "across_back_width",     unit: "cm",
        strategy: .frontWidth(slice: LandmarkSlice(shoulderToHipFraction: 0.20, debugLabel: "back"))),
    MeasurementBlueprint(code: "back_shoulder_width",   unit: "cm",
        strategy: .frontWidth(slice: LandmarkSlice(shoulderToHipFraction: 0.00, debugLabel: "back shoulder"))),

    // --- P0 heights -------------------------------------------------------
    MeasurementBlueprint(code: "back_neck_height",      unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 0.00, debugLabel: "back neck"))),
    MeasurementBlueprint(code: "bust_height",           unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 0.39, debugLabel: "bust"))),
    MeasurementBlueprint(code: "waist_height",          unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 0.67, debugLabel: "waist"))),
    MeasurementBlueprint(code: "hip_height",            unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 1.00, debugLabel: "hip"))),
    MeasurementBlueprint(code: "knee_height",           unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 2.50, debugLabel: "knee"))),

    // --- P0 lengths -------------------------------------------------------
    MeasurementBlueprint(code: "torso_height",          unit: "cm",
        strategy: .composite(minuendCode: "back_neck_height", subtrahendCode: "hip_height")),
    MeasurementBlueprint(code: "outside_leg_length",    unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 1.00, debugLabel: "outside leg"))),
    MeasurementBlueprint(code: "inside_leg_length",     unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 1.10, debugLabel: "inseam"))),
    MeasurementBlueprint(code: "inseam_from_crotch_to_floor", unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 1.10, debugLabel: "crotch to floor"))),
    MeasurementBlueprint(code: "inseam_from_crotch_to_ankle", unit: "cm",
        strategy: .composite(minuendCode: "inseam_from_crotch_to_floor", subtrahendCode: "outer_ankle_height")),
    MeasurementBlueprint(code: "outer_ankle_height",    unit: "cm",
        strategy: .heightFromFloor(slice: LandmarkSlice(shoulderToHipFraction: 3.95, debugLabel: "ankle"))),
    MeasurementBlueprint(code: "outer_arm_length",      unit: "cm",
        strategy: .composite(minuendCode: "back_neck_height", subtrahendCode: "outer_arm_length_floor_offset")),

    // --- P0 composites ----------------------------------------------------
    MeasurementBlueprint(code: "waist_to_hip_length",   unit: "cm",
        strategy: .composite(minuendCode: "waist_height", subtrahendCode: "hip_height")),

    // --- P1 angle ---------------------------------------------------------
    MeasurementBlueprint(code: "shoulder_slope",        unit: "deg",
        strategy: .poseAngle(left: .leftShoulder, right: .rightShoulder)),

    // --- P1 depth ---------------------------------------------------------
    MeasurementBlueprint(code: "waist_depth",           unit: "cm",
        strategy: .sideDepth(slice: LandmarkSlice(shoulderToHipFraction: 0.67, debugLabel: "waist depth"))),
]

// ---------------------------------------------------------------------------
// Slicer
// ---------------------------------------------------------------------------

/// Errors surfaced when the slicer can't proceed. None of these are recovered
/// internally — callers report them as a hard fail and prompt the user to
/// recapture.
enum LandmarkSlicerError: Error {
    case missingFrontKeypoints
    case missingScale
}

final class LandmarkSlicer {
    private let userHeightCm: Double
    private let gender: Gender

    init(userHeightCm: Double, gender: Gender = .nonBinary) {
        self.userHeightCm = userHeightCm
        self.gender = gender
    }

    /// Run the slicer. `sideMask` and `sideObservation` may be nil — in that
    /// case girth measurements fall back to gender-typical depth ratios
    /// (legacy KeypointNormalizer behaviour) so the pipeline still produces
    /// values, with reduced confidence.
    func slice(
        frontMask: SilhouetteMask,
        sideMask: SilhouetteMask?,
        frontObservation: VNHumanBodyPoseObservation,
        sideObservation: VNHumanBodyPoseObservation?,
    ) throws -> [CapturedMeasurement] {
        guard let frontGeometry = MaskGeometry(
            mask: frontMask,
            observation: frontObservation,
            userHeightCm: userHeightCm,
        ) else {
            throw LandmarkSlicerError.missingFrontKeypoints
        }

        let sideGeometry: MaskGeometry? = {
            guard let sm = sideMask, let so = sideObservation else { return nil }
            return MaskGeometry(mask: sm, observation: so, userHeightCm: userHeightCm)
        }()

        var resolved: [String: CapturedMeasurement] = [:]
        for blueprint in kBlueprints {
            if let m = compute(
                blueprint,
                frontGeometry: frontGeometry,
                sideGeometry: sideGeometry,
                resolved: resolved,
                frontObservation: frontObservation,
            ) {
                resolved[m.code] = m
            }
        }
        return Array(resolved.values)
    }

    // MARK: - Per-blueprint computation

    private func compute(
        _ blueprint: MeasurementBlueprint,
        frontGeometry: MaskGeometry,
        sideGeometry: MaskGeometry?,
        resolved: [String: CapturedMeasurement],
        frontObservation: VNHumanBodyPoseObservation,
    ) -> CapturedMeasurement? {
        switch blueprint.strategy {
        case .girth(let slice):
            return computeGirth(code: blueprint.code, slice: slice,
                                front: frontGeometry, side: sideGeometry)
        case .heightFromFloor(let slice):
            return computeHeight(code: blueprint.code, slice: slice, front: frontGeometry)
        case .frontWidth(let slice):
            return computeFrontWidth(code: blueprint.code, slice: slice, front: frontGeometry)
        case .sideDepth(let slice):
            guard let side = sideGeometry else { return nil }
            return computeSideDepth(code: blueprint.code, slice: slice, side: side)
        case .composite(let minuendCode, let subtrahendCode):
            return computeComposite(code: blueprint.code,
                                    minuendCode: minuendCode,
                                    subtrahendCode: subtrahendCode,
                                    resolved: resolved)
        case .poseAngle(let leftJoint, let rightJoint):
            return computePoseAngle(code: blueprint.code, unit: blueprint.unit,
                                    left: leftJoint, right: rightJoint,
                                    in: frontObservation)
        }
    }

    private func computeGirth(
        code: String,
        slice: LandmarkSlice,
        front: MaskGeometry,
        side: MaskGeometry?,
    ) -> CapturedMeasurement? {
        guard let frontWidthCm = front.widthAtSlice(slice) else { return nil }
        let depthCm: Double
        let depthConfidence: Double
        if let side = side, let d = side.widthAtSlice(slice) {
            depthCm = d
            depthConfidence = side.scaleConfidence
        } else {
            // Fallback: gender-typical depth ratio. Lower confidence to flag.
            depthCm = frontWidthCm * fallbackDepthRatio(for: code)
            depthConfidence = 0.4
        }
        let perimeter = ramanujanEllipsePerimeter(width: frontWidthCm, depth: depthCm)
        let confidence = min(front.scaleConfidence, depthConfidence) * front.maskQualityAt(slice)
        return CapturedMeasurement(code: code, value: perimeter, unit: "cm",
                                   confidence: confidence, angle: "front")
    }

    private func computeHeight(
        code: String,
        slice: LandmarkSlice,
        front: MaskGeometry,
    ) -> CapturedMeasurement? {
        guard let height = front.heightFromFloorAtSlice(slice) else { return nil }
        let confidence = front.scaleConfidence * front.maskQualityAt(slice)
        return CapturedMeasurement(code: code, value: height, unit: "cm",
                                   confidence: confidence, angle: "front")
    }

    private func computeFrontWidth(
        code: String,
        slice: LandmarkSlice,
        front: MaskGeometry,
    ) -> CapturedMeasurement? {
        guard let width = front.widthAtSlice(slice) else { return nil }
        let confidence = front.scaleConfidence * front.maskQualityAt(slice)
        return CapturedMeasurement(code: code, value: width, unit: "cm",
                                   confidence: confidence, angle: "front")
    }

    private func computeSideDepth(
        code: String,
        slice: LandmarkSlice,
        side: MaskGeometry,
    ) -> CapturedMeasurement? {
        guard let depth = side.widthAtSlice(slice) else { return nil }
        let confidence = side.scaleConfidence * side.maskQualityAt(slice)
        return CapturedMeasurement(code: code, value: depth, unit: "cm",
                                   confidence: confidence, angle: "side")
    }

    private func computeComposite(
        code: String,
        minuendCode: String,
        subtrahendCode: String,
        resolved: [String: CapturedMeasurement],
    ) -> CapturedMeasurement? {
        guard let a = resolved[minuendCode], let b = resolved[subtrahendCode] else {
            return nil
        }
        let value = a.value - b.value
        guard value >= 0 else { return nil }
        return CapturedMeasurement(
            code: code,
            value: value,
            unit: a.unit,
            confidence: min(a.confidence, b.confidence) * 0.95,
            angle: a.angle,
        )
    }

    private func computePoseAngle(
        code: String,
        unit: String,
        left: VNHumanBodyPoseObservation.JointName,
        right: VNHumanBodyPoseObservation.JointName,
        in observation: VNHumanBodyPoseObservation,
    ) -> CapturedMeasurement? {
        guard
            let lp = try? observation.recognizedPoint(left),
            let rp = try? observation.recognizedPoint(right),
            lp.confidence >= 0.2, rp.confidence >= 0.2
        else { return nil }
        let dx = Double(rp.location.x - lp.location.x)
        let dy = Double(rp.location.y - lp.location.y)
        // Angle off horizontal, magnitude in degrees.
        let degrees = abs(atan2(dy, dx) * 180.0 / .pi)
        let normalized = degrees > 90 ? 180 - degrees : degrees
        let confidence = Double(min(lp.confidence, rp.confidence))
        return CapturedMeasurement(code: code, value: normalized, unit: unit,
                                   confidence: confidence, angle: "front")
    }

    // MARK: - Helpers

    private func fallbackDepthRatio(for code: String) -> Double {
        // Conservative defaults from KeypointNormalizer's ratio table.
        // Used only when sideMask is nil; confidence is downgraded.
        switch code {
        case "bust_girth", "upper_chest_girth", "under_bust_girth":
            return gender == .female ? 0.40 : 0.45
        case "hip_girth", "upper_hip_girth":
            return 0.58
        case "waist_girth":
            return gender == .female ? 0.40 : 0.45
        case "thigh_girth", "knee_girth", "calf_girth", "ankle_girth":
            return 0.95   // limbs are nearly circular
        case "upper_arm_girth", "wrist_girth":
            return 0.95
        case "neck_girth":
            return 0.85
        default:
            return 0.7
        }
    }

    /// Ramanujan ellipse perimeter approximation. Same formula used by
    /// KeypointNormalizer for backwards compatibility.
    private func ramanujanEllipsePerimeter(width: Double, depth: Double) -> Double {
        let a = width / 2
        let b = depth / 2
        return Double.pi * (3 * (a + b) - sqrt((3 * a + b) * (a + 3 * b)))
    }
}

// ---------------------------------------------------------------------------
// MaskGeometry — turns a (mask, keypoints, height) bundle into a queryable
// "what's the width/height at this body landmark" interface. Encapsulates the
// coordinate-system conversions between Vision (normalized, +Y up) and image
// pixels (+Y down).
// ---------------------------------------------------------------------------

private struct MaskGeometry {
    let mask: SilhouetteMask
    /// Pixels per cm for this image. Computed from nose→ankle span vs
    /// userHeightCm.
    let pixelsPerCm: Double
    /// Confidence (0..1) of the height anchor itself.
    let scaleConfidence: Double

    /// Image-Y in pixels at the anatomical shoulder line. Origin top-left.
    let shoulderPixelY: Double
    /// Image-Y in pixels at the hip line.
    let hipPixelY: Double
    /// Image-Y in pixels of the lowest body pixel (~floor).
    let floorPixelY: Double

    init?(
        mask: SilhouetteMask,
        observation: VNHumanBodyPoseObservation,
        userHeightCm: Double,
    ) {
        self.mask = mask

        let p: (VNHumanBodyPoseObservation.JointName) -> (x: Double, y: Double, conf: Double)? = { joint in
            guard observation.availableJointNames.contains(joint),
                  let pt = try? observation.recognizedPoint(joint),
                  pt.confidence >= 0.2 else { return nil }
            return (Double(pt.location.x), Double(pt.location.y), Double(pt.confidence))
        }

        guard
            let nose = p(.nose) ?? p(.neck),
            let ls = p(.leftShoulder),
            let rs = p(.rightShoulder),
            let lh = p(.leftHip),
            let rh = p(.rightHip)
        else { return nil }

        let h = Double(mask.height)
        // Vision Y origin is bottom-left, mask Y is top-left.
        let yToPx: (Double) -> Double = { (1.0 - $0) * h }

        let shoulderVisionY = (ls.y + rs.y) / 2
        let hipVisionY = (lh.y + rh.y) / 2
        self.shoulderPixelY = yToPx(shoulderVisionY)
        self.hipPixelY = yToPx(hipVisionY)

        // Floor: lowest body pixel in the mask.
        var lowest: Int? = nil
        for y in stride(from: mask.height - 1, through: 0, by: -1) {
            for x in 0..<mask.width where mask.isBody(x: x, y: y) {
                lowest = y
                break
            }
            if lowest != nil { break }
        }
        guard let floor = lowest else { return nil }
        self.floorPixelY = Double(floor)

        // Scale anchor: nose → floor in pixels == userHeightCm.
        let nosePixelY = yToPx(nose.y)
        let scaleSpanPixels = abs(self.floorPixelY - nosePixelY)
        guard scaleSpanPixels > 1.0 else { return nil }
        self.pixelsPerCm = scaleSpanPixels / userHeightCm
        self.scaleConfidence = nose.conf
    }

    /// Pixel Y for a slice expressed as a fraction of the shoulder→hip span.
    private func sliceY(_ slice: LandmarkSlice) -> Double {
        let span = hipPixelY - shoulderPixelY
        return shoulderPixelY + slice.shoulderToHipFraction * span
    }

    /// Width (cm) of the body at this slice, scanning horizontally.
    /// Returns nil if the slice falls outside the mask or no body pixels are
    /// present on that row.
    func widthAtSlice(_ slice: LandmarkSlice) -> Double? {
        let yFloat = sliceY(slice)
        let y = Int(yFloat.rounded())
        guard y >= 0, y < mask.height else { return nil }

        var leftMost: Int? = nil
        var rightMost: Int? = nil
        for x in 0..<mask.width {
            if mask.isBody(x: x, y: y) {
                if leftMost == nil { leftMost = x }
                rightMost = x
            }
        }
        guard let l = leftMost, let r = rightMost, r > l else { return nil }
        return Double(r - l) / pixelsPerCm
    }

    /// Distance (cm) from the floor to this slice line.
    func heightFromFloorAtSlice(_ slice: LandmarkSlice) -> Double? {
        let yFloat = sliceY(slice)
        guard yFloat >= 0, yFloat < Double(mask.height) else { return nil }
        let pixelDelta = floorPixelY - yFloat
        return pixelDelta / pixelsPerCm
    }

    /// Mask quality at a slice: rough proxy = does the row have a continuous
    /// body span without holes? Returns 1.0 for clean rows, dropping toward 0
    /// as the mask gets noisy. Cheap, not authoritative.
    func maskQualityAt(_ slice: LandmarkSlice) -> Double {
        let yFloat = sliceY(slice)
        let y = Int(yFloat.rounded())
        guard y >= 0, y < mask.height else { return 0.0 }

        var inBody = false
        var transitions = 0
        for x in 0..<mask.width {
            let here = mask.isBody(x: x, y: y)
            if here != inBody { transitions += 1; inBody = here }
        }
        // Healthy: 2 transitions (background→body→background). Each extra
        // transition pair is a hole or a fragment — penalize linearly.
        let extras = max(0, transitions - 2)
        return max(0.0, 1.0 - Double(extras) * 0.1)
    }
}
