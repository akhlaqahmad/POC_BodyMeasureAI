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

    /// Fetch this device's scan history (body measurements + garment detail).
    static func fetchHistory(limit: Int = 50) async -> Result<[ScanHistoryItem], BackendUploadError> {
        var components = URLComponents(
            url: BackendConfig.baseURL.appendingPathComponent("api/my/sessions"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        let endpoint = components.url!

        let deviceId = DeviceIdentity.current()
        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        req.timeoutInterval = 15

        AppLog.network.info("→ GET \(endpoint.absoluteString, privacy: .public) device=\(deviceId.prefix(8), privacy: .public)…")
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            guard let http = resp as? HTTPURLResponse else { return .failure(.invalidResponse) }
            guard (200...299).contains(http.statusCode) else {
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                AppLog.network.error("← \(http.statusCode) history (\(durationMs)ms) body=\(bodyStr.prefix(300), privacy: .public)")
                return .failure(.httpStatus(http.statusCode, bodyStr))
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { dec in
                let s = try dec.singleValueContainer().decode(String.self)
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: s) { return d }
                iso.formatOptions = [.withInternetDateTime]
                if let d = iso.date(from: s) { return d }
                throw DecodingError.dataCorruptedError(
                    in: dec, debugDescription: "Invalid ISO-8601 date: \(s)"
                )
            }
            let wrapper = try decoder.decode(ScanHistoryResponse.self, from: data)
            AppLog.network.info("← 200 history (\(durationMs)ms) items=\(wrapper.sessions.count)")
            return .success(wrapper.sessions)
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            AppLog.network.error("✗ history failed after \(durationMs)ms: \(error.localizedDescription, privacy: .public)")
            return .failure(.transport(error))
        }
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
