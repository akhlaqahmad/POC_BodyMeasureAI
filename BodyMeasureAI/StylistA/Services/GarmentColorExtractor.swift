//
//  GarmentColorExtractor.swift
//  BodyMeasureAI
//
//  Extracts dominant colors from UIImage as pixel-accurate hex strings.
//

import UIKit

final class GarmentColorExtractor {

    private static let resizeSize = CGSize(width: 100, height: 100)
    private static let colorBucketSize: Int = 16  // 16 bins per channel → 4096 buckets; better blue/purple discrimination

    /// Resize image to 100×100, sample pixels, cluster into dominant colors,
    /// and return them as hex strings ordered by coverage (most pixels first).
    func extractDominantColorHexes(from image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let cropped = centerCrop(cgImage) ?? cgImage
        guard let resized = resize(cropped, to: Self.resizeSize) else { return [] }
        let pixels = samplePixels(from: resized)
        guard !pixels.isEmpty else { return [] }

        var sums: [Int: (Int, Int, Int)] = [:]
        var counts: [Int: Int] = [:]
        let binsPerChannel = 256 / Self.colorBucketSize

        for (r, g, b) in pixels {
            // Skip near-white background and near-black shadows
            let avg = (Int(r) + Int(g) + Int(b)) / 3
            guard avg > 30 && avg < 225 else { continue }

            let br = Int(r) / Self.colorBucketSize
            let bg = Int(g) / Self.colorBucketSize
            let bb = Int(b) / Self.colorBucketSize
            let key = br * (binsPerChannel * binsPerChannel)
                    + bg * binsPerChannel + bb

            counts[key, default: 0] += 1
            var sum = sums[key] ?? (0, 0, 0)
            sum.0 += Int(r)
            sum.1 += Int(g)
            sum.2 += Int(b)
            sums[key] = sum
        }

        let total = max(pixels.count, 1)

        return counts
            .sorted { $0.value > $1.value }
            .filter { ($0.value * 100 / total) >= 3 }
            .compactMap { key, c in
                guard let s = sums[key], c > 0 else { return nil }
                let r = UInt8(s.0 / c)
                let g = UInt8(s.1 / c)
                let b = UInt8(s.2 / c)
                return String(format: "#%02X%02X%02X", r, g, b)
            }
    }

    // MARK: - Center crop (garment area)

    /// Crop to center 60% width × 85% height (removes background edges). Garment is typically centered.
    private func centerCrop(_ cgImage: CGImage) -> CGImage? {
        let w = cgImage.width
        let h = cgImage.height
        let cropW = Int(Double(w) * 0.6)
        let cropH = Int(Double(h) * 0.85)
        let cropX = (w - cropW) / 2
        let cropY = Int(Double(h) * 0.08)
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        return cgImage.cropping(to: cropRect)
    }

    // MARK: - Resize

    private func resize(_ cgImage: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    // MARK: - Sample pixels (grid)

    private func samplePixels(from cgImage: CGImage) -> [(UInt8, UInt8, UInt8)] {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = height * bytesPerRow
        var pixels: [(UInt8, UInt8, UInt8)] = []
        pixels.reserveCapacity(width * height)
        guard let data = malloc(bufferSize) else { return [] }
        defer { free(data) }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let raw = data.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = raw[offset]
                let g = raw[offset + 1]
                let b = raw[offset + 2]
                let brightness = (Int(r) + Int(g) + Int(b)) / 3
                if brightness > 200 { continue }  // skip white/very light (background wall)
                let maxC = max(Int(r), Int(g), Int(b))
                let minC = min(Int(r), Int(g), Int(b))
                let saturation = maxC > 0 ? (maxC - minC) * 255 / maxC : 0
                if saturation < 30 && brightness > 120 { continue }  // skip grey background
                pixels.append((r, g, b))
            }
        }
        return pixels
    }

    // No static colour-name mapping; colours are represented only as hex strings.
}
