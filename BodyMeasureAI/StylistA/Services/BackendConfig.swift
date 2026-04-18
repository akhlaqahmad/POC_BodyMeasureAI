//
//  BackendConfig.swift
//  BodyMeasureAI
//
//  Resolves the backend base URL.
//
//  Resolution order:
//    1. `BACKEND_BASE_URL` Info.plist key — optional per-scheme override.
//    2. Compile-time default: localhost in DEBUG, production URL otherwise.
//

import Foundation

enum BackendConfig {

    /// Live backend URL (Vercel-hosted Next.js, queries Neon Postgres).
    private static let productionBaseURL = URL(string: "https://bodymeasureai-admin.vercel.app")!

    #if DEBUG
    private static let debugBaseURL = URL(string: "http://localhost:3000")!
    #endif

    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        #if DEBUG
        return debugBaseURL
        #else
        return productionBaseURL
        #endif
    }

    /// Upload endpoint — matches `POST /api/sessions` in the Next.js backend.
    static var sessionsEndpoint: URL {
        baseURL.appendingPathComponent("api/sessions")
    }
}
