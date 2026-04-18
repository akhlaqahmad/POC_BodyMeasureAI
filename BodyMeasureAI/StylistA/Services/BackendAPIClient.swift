//
//  BackendAPIClient.swift
//  BodyMeasureAI
//
//  Thin URLSession client for the Next.js ingest endpoint. Uploads the same
//  JSON shape that ScanSessionModel / BodyScanResult already produce.
//

import Foundation

enum BackendUploadError: Error {
    case invalidResponse
    case httpStatus(Int, String)
    case serialization(Error)
    case transport(Error)
}

struct BackendUploadResult {
    let remoteSessionId: String
}

enum BackendAPIClient {

    /// Upload a complete scan (body + garment).
    static func upload(session: ScanSessionModel) async -> Result<BackendUploadResult, BackendUploadError> {
        await postJSON(dict: session.exportJSON)
    }

    /// Upload a body-only scan (no garment). BodyScanResult.exportJSON matches
    /// the same schema minus `garmentAnalysis`.
    static func upload(bodyOnly result: BodyScanResult) async -> Result<BackendUploadResult, BackendUploadError> {
        await postJSON(dict: result.exportJSON)
    }

    // MARK: - Transport

    private static func postJSON(dict: [String: Any]) async -> Result<BackendUploadResult, BackendUploadError> {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict, options: [])
        } catch {
            return .failure(.serialization(error))
        }

        var req = URLRequest(url: BackendConfig.sessionsEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 15

        do {
            let (respData, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return .failure(.invalidResponse) }
            guard (200...299).contains(http.statusCode) else {
                let body = String(data: respData, encoding: .utf8) ?? ""
                return .failure(.httpStatus(http.statusCode, body))
            }
            let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
            let remoteId = json?["sessionId"] as? String ?? ""
            return .success(BackendUploadResult(remoteSessionId: remoteId))
        } catch {
            return .failure(.transport(error))
        }
    }
}
