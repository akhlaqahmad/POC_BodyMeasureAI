//
//  GarmentMeasurementService.swift
//  BodyMeasureAI
//
//  POC garment-measurement extraction using a credit card as a real-world
//  reference for pixel-to-cm calibration. Marked beta — the output feeds the
//  optional `GarmentMeasurements` on a GarmentTagModel.
//

import Foundation
import UIKit
import Vision

/// Real-world dimensions of an ISO/IEC 7810 ID-1 card (credit card, driver's
/// licence, etc.) in centimetres. Same across AU/US/EU.
private enum ReferenceCard {
    static let widthCm: Double = 8.56
    static let heightCm: Double = 5.398
    static let aspectRatio: Double = widthCm / heightCm   // ~1.586
}

/// Result of a measurement attempt. `measurements` is present on success;
/// `error` describes why we fell back to nil. Keep non-throwing so the UI
/// can show a friendly beta message and carry on without measurements.
struct GarmentMeasurementResult {
    let measurements: GarmentMeasurements?
    let error: String?
}

final class GarmentMeasurementService {

    /// Try to extract physical measurements from a garment photo containing a
    /// reference card (credit card). Falls back to a nil measurements result
    /// with an error reason when the card can't be located confidently.
    func measure(image: UIImage) async -> GarmentMeasurementResult {
        guard let cgImage = image.cgImage else {
            return .init(measurements: nil, error: "Invalid image")
        }

        let rectangles = await detectRectangles(in: cgImage)
        guard let card = pickCreditCardCandidate(rectangles) else {
            return .init(
                measurements: nil,
                error: "Couldn't find the reference card. Place a credit card flat next to the garment and try again."
            )
        }

        let imageSize = CGSize(
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )
        let cardPxWidth = pixelWidth(of: card, imageSize: imageSize)
        guard cardPxWidth > 10 else {
            return .init(
                measurements: nil,
                error: "Reference card too small in frame — move the camera closer."
            )
        }
        let pixelsPerCm = Double(cardPxWidth) / ReferenceCard.widthCm

        // Garment bounding box: use the non-card portion of the frame as a
        // proxy. Tight contour detection would be better but is out of scope
        // for the POC; image minus card region gives usable chest/length.
        let cardRect = normalizedBoundingBox(for: card)
        let garmentBox = garmentBoundingBox(excluding: cardRect)

        let chestWidthCm = Double(garmentBox.width) * Double(imageSize.width) / pixelsPerCm
        let garmentLengthCm = Double(garmentBox.height) * Double(imageSize.height) / pixelsPerCm

        return .init(
            measurements: GarmentMeasurements(
                chestWidthCm: chestWidthCm,
                garmentLengthCm: garmentLengthCm,
                shoulderWidthCm: nil,
                waistWidthCm: nil,
                method: .creditCard,
                pixelsPerCm: pixelsPerCm,
                confidence: Double(card.confidence)
            ),
            error: nil
        )
    }

    // MARK: - Rectangle detection

    private func detectRectangles(in cgImage: CGImage) async -> [VNRectangleObservation] {
        await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { req, _ in
                let obs = (req.results as? [VNRectangleObservation]) ?? []
                continuation.resume(returning: obs)
            }
            // Credit-card-ish aspect ratio window, with generous tolerance to
            // absorb perspective foreshortening.
            request.minimumAspectRatio = VNAspectRatio(1.3)
            request.maximumAspectRatio = VNAspectRatio(1.9)
            request.minimumSize = 0.05
            request.minimumConfidence = 0.7
            request.maximumObservations = 8
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }

    /// Pick the rectangle whose aspect ratio is closest to a credit card.
    private func pickCreditCardCandidate(
        _ rectangles: [VNRectangleObservation]
    ) -> VNRectangleObservation? {
        return rectangles.min { a, b in
            distance(from: ratio(of: a), to: ReferenceCard.aspectRatio)
                < distance(from: ratio(of: b), to: ReferenceCard.aspectRatio)
        }
    }

    private func ratio(of obs: VNRectangleObservation) -> Double {
        let w = abs(obs.topRight.x - obs.topLeft.x)
        let h = abs(obs.topLeft.y - obs.bottomLeft.y)
        guard h > 0 else { return 0 }
        return Double(w) / Double(h)
    }

    private func distance(from a: Double, to b: Double) -> Double { abs(a - b) }

    /// Bounding box in image pixels (Vision coordinates are normalized
    /// bottom-left origin; Swift's CGRect for pixel math wants top-left).
    private func pixelWidth(of obs: VNRectangleObservation, imageSize: CGSize) -> CGFloat {
        let box = normalizedBoundingBox(for: obs)
        return box.width * imageSize.width
    }

    private func normalizedBoundingBox(for obs: VNRectangleObservation) -> CGRect {
        let minX = min(obs.topLeft.x, obs.bottomLeft.x)
        let maxX = max(obs.topRight.x, obs.bottomRight.x)
        let minY = min(obs.bottomLeft.y, obs.bottomRight.y)
        let maxY = max(obs.topLeft.y, obs.topRight.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Trim a safety margin from the frame edges and exclude the card region
    /// to get an approximate garment bounding box (normalized 0–1).
    private func garmentBoundingBox(excluding cardRect: CGRect) -> CGRect {
        // Heuristic: assume garment occupies the middle 80% of the frame and
        // doesn't overlap the card. Shrinking avoids background clutter.
        var box = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

        // If the card is inside the default box, nudge the box away from it.
        // Simpler to just cap the width so the garment box doesn't include the
        // card column.
        if cardRect.intersects(box), cardRect.maxX < box.midX {
            // Card on the left → push garment's left edge past the card.
            let newX = min(cardRect.maxX + 0.02, 0.5)
            box = CGRect(
                x: newX, y: box.minY,
                width: max(0.3, box.maxX - newX),
                height: box.height
            )
        } else if cardRect.intersects(box), cardRect.minX > box.midX {
            // Card on the right → cap garment's right edge before the card.
            let newMaxX = max(cardRect.minX - 0.02, 0.5)
            box = CGRect(
                x: box.minX, y: box.minY,
                width: max(0.3, newMaxX - box.minX),
                height: box.height
            )
        }
        return box
    }
}
