//
//  SilhouetteSegmenter.swift
//  BodyMeasureAI
//
//  Wraps VNGeneratePersonSegmentationRequest. Produces a binary silhouette
//  mask the LandmarkSlicer scans for body widths/depths/heights.
//
//  On-device, no network. Runs in <500ms on iPhone 14+ at .accurate quality
//  for a 4032×3024 image.
//

import CoreImage
import CoreVideo
import Foundation
import UIKit
import Vision

/// Binary person mask aligned to the input image.
///
/// `pixels` is row-major, length == `width * height`. A pixel is `true` if
/// Vision classified it as person, `false` otherwise. The grid uses standard
/// image-space (origin top-left, +X right, +Y down) — different from Vision's
/// normalized keypoint coords. The slicer maps between the two.
struct SilhouetteMask {
    let width: Int
    let height: Int
    /// Row-major occupancy grid. `pixels[y * width + x]` is true for body.
    let pixels: [Bool]

    @inlinable
    func isBody(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return pixels[y * width + x]
    }
}

enum SilhouetteSegmenterError: Error {
    case requestFailed(Error)
    case noObservation
    case invalidPixelBuffer
}

/// Runs Apple's Vision person segmenter and returns a `SilhouetteMask`.
final class SilhouetteSegmenter {
    private let qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel

    init(qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel = .accurate) {
        self.qualityLevel = qualityLevel
    }

    /// Synchronous segment from a UIImage. Caller is responsible for
    /// off-main-thread dispatch.
    func segment(image: UIImage) throws -> SilhouetteMask {
        guard let cgImage = image.cgImage else {
            throw SilhouetteSegmenterError.invalidPixelBuffer
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        return try perform(handler: handler)
    }

    /// Synchronous segment from a CVPixelBuffer (the camera-pipeline path,
    /// avoids a UIImage round-trip). Caller passes the same orientation it
    /// used for the body-pose request so masks and keypoints align.
    func segment(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
    ) throws -> SilhouetteMask {
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:],
        )
        return try perform(handler: handler)
    }

    private func perform(handler: VNImageRequestHandler) throws -> SilhouetteMask {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = qualityLevel
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            try handler.perform([request])
        } catch {
            throw SilhouetteSegmenterError.requestFailed(error)
        }
        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            throw SilhouetteSegmenterError.noObservation
        }
        return Self.makeMask(from: observation.pixelBuffer)
    }

    /// Converts a single-channel 8-bit pixel buffer to a `SilhouetteMask`.
    /// Threshold of 128 splits person/background (Vision returns confidences
    /// up to 255; the morph noise around the boundary is small enough that a
    /// hard threshold is sufficient for measurement work).
    private static func makeMask(from buffer: CVPixelBuffer) -> SilhouetteMask {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return SilhouetteMask(
                width: width,
                height: height,
                pixels: [Bool](repeating: false, count: width * height),
            )
        }

        let basePtr = baseAddress.assumingMemoryBound(to: UInt8.self)
        var pixels = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            let rowPtr = basePtr.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                pixels[y * width + x] = rowPtr[x] >= 128
            }
        }
        return SilhouetteMask(width: width, height: height, pixels: pixels)
    }
}
