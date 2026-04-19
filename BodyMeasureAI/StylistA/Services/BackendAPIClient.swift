//
//  BackendAPIClient.swift
//  BodyMeasureAI
//
//  Thin URLSession client for the Next.js ingest endpoint. Uploads the same
//  JSON shape that ScanSessionModel / BodyScanResult already produce.
//

import Foundation
import os

enum BackendUploadError: Error, CustomStringConvertible {
    case invalidResponse
    case httpStatus(Int, String)
    case serialization(Error)
    case transport(Error)

    var description: String {
        switch self {
        case .invalidResponse: return "invalidResponse"
        case .httpStatus(let code, let body):
            return "httpStatus(\(code), \(body.prefix(200)))"
        case .serialization(let e): return "serialization(\(e.localizedDescription))"
        case .transport(let e): return "transport(\(e.localizedDescription))"
        }
    }
}

struct BackendUploadResult {
    let remoteSessionId: String
    let durationMs: Int
}

enum BackendAPIClient {

    /// Upload a complete scan (body + garment).
    static func upload(session: ScanSessionModel) async -> Result<BackendUploadResult, BackendUploadError> {
        AppLog.upload.info("upload(session) sessionId=\(session.sessionId, privacy: .public)")
        return await postJSON(dict: session.exportJSON, label: "session")
    }

    /// Upload a body-only scan (no garment). BodyScanResult.exportJSON matches
    /// the same schema minus `garmentAnalysis`.
    static func upload(bodyOnly result: BodyScanResult) async -> Result<BackendUploadResult, BackendUploadError> {
        AppLog.upload.info("upload(bodyOnly) timestamp=\(result.measurements.timestamp.timeIntervalSince1970, privacy: .public)")
        return await postJSON(dict: result.exportJSON, label: "bodyOnly")
    }

    // MARK: - Transport

    private static func postJSON(
        dict: [String: Any],
        label: String
    ) async -> Result<BackendUploadResult, BackendUploadError> {
        let endpoint = BackendConfig.sessionsEndpoint
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict, options: [])
        } catch {
            AppLog.network.error("[\(label, privacy: .public)] serialization failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.serialization(error))
        }

        let deviceId = DeviceIdentity.current()
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        req.httpBody = data
        req.timeoutInterval = 15

        let bodySize = data.count
        AppLog.network.info("→ POST \(endpoint.absoluteString, privacy: .public) bytes=\(bodySize) label=\(label, privacy: .public) device=\(deviceId.prefix(8), privacy: .public)…")
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (respData, resp) = try await URLSession.shared.data(for: req)
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            guard let http = resp as? HTTPURLResponse else {
                AppLog.network.error("[\(label, privacy: .public)] non-HTTP response (\(durationMs)ms)")
                return .failure(.invalidResponse)
            }
            let bodyStr = String(data: respData, encoding: .utf8) ?? ""
            guard (200...299).contains(http.statusCode) else {
                AppLog.network.error("← \(http.statusCode) \(endpoint.absoluteString, privacy: .public) (\(durationMs)ms) body=\(bodyStr.prefix(300), privacy: .public)")
                return .failure(.httpStatus(http.statusCode, bodyStr))
            }
            AppLog.network.info("← \(http.statusCode) \(endpoint.absoluteString, privacy: .public) (\(durationMs)ms) bytes=\(respData.count)")
            let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any]
            let remoteId = json?["sessionId"] as? String ?? ""
            AppLog.upload.info("[\(label, privacy: .public)] success remoteId=\(remoteId, privacy: .public) (\(durationMs)ms)")
            return .success(BackendUploadResult(remoteSessionId: remoteId, durationMs: durationMs))
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            AppLog.network.error("✗ POST \(endpoint.absoluteString, privacy: .public) failed after \(durationMs)ms: \(error.localizedDescription, privacy: .public)")
            return .failure(.transport(error))
        }
    }
}
