//
//  BackendConfig.swift
//  BodyMeasureAI
//
//  Resolves the backend base URL.
//
//  Resolution order:
//    1. `BACKEND_BASE_URL` Info.plist key — optional per-scheme override.
//    2. Compile-time default: the live production URL.
//

import Foundation

enum BackendConfig {

    /// Live backend URL (Vercel-hosted Next.js, queries Neon Postgres).
    private static let productionBaseURL = URL(string: "https://bodymeasureai-admin.vercel.app")!

    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return productionBaseURL
    }

    /// Upload endpoint — matches `POST /api/sessions` in the Next.js backend.
    static var sessionsEndpoint: URL {
        baseURL.appendingPathComponent("api/sessions")
    }

    /// Scan-asset upload endpoint — matches `POST /api/blob/scan-assets`.
    /// Streams one HEIC frame or PNG mask at a time as multipart/form-data
    /// and returns the resulting Vercel Blob URL.
    static var scanAssetsEndpoint: URL {
        baseURL.appendingPathComponent("api/blob/scan-assets")
    }
}
