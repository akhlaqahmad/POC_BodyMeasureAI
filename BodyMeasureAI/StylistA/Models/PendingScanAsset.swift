//
//  PendingScanAsset.swift
//  BodyMeasureAI
//
//  In-memory bundle of a scan-time RGB frame or silhouette mask waiting to
//  be uploaded. Lives on BodyScanResult / ScanSessionModel until the upload
//  pipeline drains it via BackendAPIClient. Bytes are dropped after upload
//  to keep memory pressure low across multi-angle flows.
//

import Foundation

enum ScanAssetAngle: String {
    case front, side, back
}

enum ScanAssetKind: String {
    case rgbFrame = "rgb_frame"
    case silhouetteMask = "silhouette_mask"
}

/// One scan-time asset (HEIC frame or PNG mask) ready for upload. Carries
/// the bytes plus integrity + content metadata so the backend route can
/// validate without inspecting the file.
struct PendingScanAsset {
    let angle: ScanAssetAngle
    let kind: ScanAssetKind
    let data: Data
    let contentType: String
    let sha256Hex: String

    var bytes: Int { data.count }
}

/// Server's response after the asset has been streamed to Vercel Blob.
/// Contains the canonical URL we'll register on POST /api/sessions.
struct UploadedScanAsset {
    let angle: ScanAssetAngle
    let kind: ScanAssetKind
    let url: String
    let contentType: String
    let bytes: Int
    let sha256Hex: String

    var exportJSON: [String: Any] {
        [
            "angle": angle.rawValue,
            "kind": kind.rawValue,
            "url": url,
            "contentType": contentType,
            "bytes": bytes,
            "sha256": sha256Hex,
        ]
    }
}
