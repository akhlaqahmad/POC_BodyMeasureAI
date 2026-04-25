//
//  FrameEncoder.swift
//  BodyMeasureAI
//
//  Encodes scan-time imagery into upload-ready blobs:
//    - RGB CVPixelBuffer → HEIC (~300–500 KB at 1080p, quality 0.8)
//    - SilhouetteMask (binary grid) → grayscale PNG (~50–200 KB)
//
//  Both encoders run synchronously and are cheap relative to the surrounding
//  segmentation step (~300 ms). Caller is responsible for off-main dispatch.
//
//  Returned `EncodedAsset` carries a sha256 the upload route validates.
//

import CoreImage
import CryptoKit
import Foundation
import UIKit
import Vision

struct EncodedAsset {
    let data: Data
    let sha256Hex: String
    let contentType: String
    let bytes: Int

    init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
        self.bytes = data.count
        let digest = SHA256.hash(data: data)
        self.sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum FrameEncoderError: Error {
    case heicEncodeFailed
    case pngEncodeFailed
    case invalidMaskDimensions
}

enum FrameEncoder {

    /// HEIC-encode the live camera frame for upload as a reference photo.
    /// Quality 0.8 keeps detail enough for SMPL-X fitting / segmentation
    /// while staying under the backend's 2 MB limit per asset.
    static func encodeHEIC(pixelBuffer: CVPixelBuffer, quality: Float = 0.8) throws -> EncodedAsset {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality,
        ]
        guard let data = context.heifRepresentation(
            of: ci,
            format: .RGBA8,
            colorSpace: colorSpace,
            options: options,
        ) else {
            throw FrameEncoderError.heicEncodeFailed
        }
        return EncodedAsset(data: data, contentType: "image/heic")
    }

    /// PNG-encode a binary silhouette mask as 8-bit grayscale (255 for body,
    /// 0 for background). PNG's run-length encoding compresses the binary
    /// content well — typical 1080p mask ends up ~50–150 KB.
    static func encodePNG(mask: SilhouetteMask) throws -> EncodedAsset {
        guard mask.width > 0, mask.height > 0,
              mask.pixels.count == mask.width * mask.height else {
            throw FrameEncoderError.invalidMaskDimensions
        }

        // Pack into a single grayscale byte plane.
        var bytes = [UInt8](repeating: 0, count: mask.pixels.count)
        for i in 0..<mask.pixels.count {
            bytes[i] = mask.pixels[i] ? 255 : 0
        }

        let provider = CGDataProvider(data: Data(bytes) as CFData)
        guard let cg = CGImage(
            width: mask.width,
            height: mask.height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: mask.width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        ) else {
            throw FrameEncoderError.pngEncodeFailed
        }

        let ui = UIImage(cgImage: cg)
        guard let png = ui.pngData() else {
            throw FrameEncoderError.pngEncodeFailed
        }
        return EncodedAsset(data: png, contentType: "image/png")
    }
}
