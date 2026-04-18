import Foundation
import Appwrite
import AppwriteModels
import JSONCodable

// MARK: - History Item Models

struct BodyScanHistoryItem: Identifiable, Hashable {
    let id: String
    let scanId: String
    let scanTimestamp: Date
    let heightCm: Double
    let gender: String
    let positiveMessage: String
    let verticalType: String
    let isPetite: Bool
    let captureConfidence: Double
    let measurementsJSON: String
    let imageLocalFilename: String?
    let imageRemoteFileId: String?
}

struct GarmentScanHistoryItem: Identifiable, Hashable {
    let id: String
    let scanId: String
    let scanTimestamp: Date
    let garmentDataJSON: String
    let imageLocalFilename: String?
    let imageRemoteFileId: String?

    /// Parsed category from garmentDataJSON for display in history list.
    var category: String {
        guard let data = garmentDataJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cat = json["category"] as? String else { return "Unknown" }
        return cat
    }

    /// Parsed primary colors from garmentDataJSON for display in history list.
    var primaryColors: [String] {
        guard let data = garmentDataJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = json["primaryColors"] as? [String] else { return [] }
        return colors
    }
}

// MARK: - ScanDatabaseService

class ScanDatabaseService {
    static let shared = ScanDatabaseService()

    private let databases = AppwriteService.shared.databases
    private let pendingScansKey = "com.bjs.BodyMeasureAI.pendingScans"

    private init() {}

    enum ScanError: Error, LocalizedError {
        case unauthenticated

        var errorDescription: String? {
            switch self {
            case .unauthenticated: return "No authenticated user found."
            }
        }
    }
    
    func saveScanSession(_ session: ScanSessionModel) async throws {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw ScanError.unauthenticated
        }
        
        let documentData: [String: Any] = [
            "sessionId": session.sessionId,
            "scanTimestamp": session.sessionTimestamp.timeIntervalSince1970,
            "heightCm": session.userInputs.heightCm,
            "gender": session.userInputs.gender,
            "scanDataJSON": session.prettyPrintedJSON() ?? ""
        ]

        do {
            _ = try await databases.createDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.scansCollectionId,
                documentId: ID.unique(),
                data: documentData,
                permissions: [
                    Permission.read(Role.user(userId)),
                    Permission.write(Role.user(userId))
                ]
            )
        } catch let error as AppwriteError {
            // If it's a network error (e.g. code 0), save locally
            if error.code == 0 {
                savePendingScanLocally(documentData: documentData)
            }
            throw error
        } catch {
            throw error
        }
    }
    
    func fetchUserScans() async throws -> [AppwriteModels.Document<[String: AnyCodable]>] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw ScanError.unauthenticated
        }
        
        let result = try await databases.listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.scansCollectionId,
            queries: [Query.orderDesc("scanTimestamp")]
        )

        return result.documents
    }
    
    private func savePendingScanLocally(documentData: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(documentData),
              let data = try? JSONSerialization.data(withJSONObject: documentData, options: []) else { return }
        var pendingScans = UserDefaults.standard.array(forKey: pendingScansKey) as? [Data] ?? []
        pendingScans.append(data)
        UserDefaults.standard.set(pendingScans, forKey: pendingScansKey)
    }
    
    func retryPendingScans() async {
        guard let pendingScans = UserDefaults.standard.array(forKey: pendingScansKey) as? [Data], !pendingScans.isEmpty else { return }
        
        var remainingScans: [Data] = []
        
        for scanData in pendingScans {
            do {
                guard let json = try JSONSerialization.jsonObject(with: scanData) as? [String: Any] else { continue }
                _ = try await databases.createDocument(
                    databaseId: AppwriteConfig.databaseId,
                    collectionId: AppwriteConfig.scansCollectionId,
                    documentId: ID.unique(),
                    data: json
                )
            } catch let error as AppwriteError {
                if error.code == 0 {
                    // Still network error, keep it
                    remainingScans.append(scanData)
                }
            } catch {
                // Non-network error, maybe malformed data. Discard or keep? Discard to avoid infinite loop.
            }
        }
        
        UserDefaults.standard.set(remainingScans, forKey: pendingScansKey)
    }

    // MARK: - Individual Body Scan Persistence

    func saveBodyScan(_ result: BodyScanResult) async throws {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw ScanError.unauthenticated
        }

        let measurementsDict: [String: Any] = [
            "M1_shoulderCircumferenceCm": result.measurements.m1ShoulderCircumferenceCm,
            "M2_hipCircumferenceCm": result.measurements.m2HipCircumferenceCm,
            "M3_waistCircumferenceCm": result.measurements.m3WaistCircumferenceCm,
            "V1_torsoHeightCm": result.measurements.v1TorsoHeightCm,
            "V2_legLengthCm": result.measurements.v2LegLengthCm,
            "waistProminenceScore": result.measurements.waistProminenceScore
        ]
        let measurementsJSONString: String
        if JSONSerialization.isValidJSONObject(measurementsDict),
           let data = try? JSONSerialization.data(withJSONObject: measurementsDict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            measurementsJSONString = str
        } else {
            measurementsJSONString = "{}"
        }

        let documentData: [String: Any] = [
            "scanId": UUID().uuidString,
            "scanTimestamp": Date().timeIntervalSince1970,
            "heightCm": result.userHeightCm,
            "gender": result.gender,
            "positiveMessage": result.positiveMessage,
            "verticalType": result.verticalType,
            "isPetite": result.isPetite,
            "captureConfidence": result.measurements.captureConfidence,
            "measurementsJSON": measurementsJSONString,
            "imageLocalFilename": result.imageLocalFilename ?? "",
            "imageRemoteFileId": result.imageRemoteFileId ?? ""
        ]

        do {
            _ = try await databases.createDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.bodyScansCollectionId,
                documentId: ID.unique(),
                data: documentData,
                permissions: [
                    Permission.read(Role.user(userId)),
                    Permission.write(Role.user(userId))
                ]
            )
            Log.info("Body scan saved successfully")
        } catch {
            Log.error("Failed to save body scan", context: ["error": error.localizedDescription])
            throw error
        }
    }

    func fetchBodyScans() async throws -> [BodyScanHistoryItem] {
        guard AuthService.shared.currentUser != nil else {
            throw ScanError.unauthenticated
        }

        let result = try await databases.listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.bodyScansCollectionId,
            queries: [Query.orderDesc("scanTimestamp")]
        )

        return result.documents.compactMap { doc -> BodyScanHistoryItem? in
            guard let scanId = doc.data["scanId"]?.value as? String,
                  let timestamp = doc.data["scanTimestamp"]?.value as? Double,
                  let heightCm = doc.data["heightCm"]?.value as? Double,
                  let gender = doc.data["gender"]?.value as? String,
                  let positiveMessage = doc.data["positiveMessage"]?.value as? String,
                  let verticalType = doc.data["verticalType"]?.value as? String,
                  let captureConfidence = doc.data["captureConfidence"]?.value as? Double,
                  let measurementsJSON = doc.data["measurementsJSON"]?.value as? String else {
                return nil
            }
            let isPetite = doc.data["isPetite"]?.value as? Bool ?? false
            let imageLocal = doc.data["imageLocalFilename"]?.value as? String
            let imageRemote = doc.data["imageRemoteFileId"]?.value as? String
            return BodyScanHistoryItem(
                id: doc.id,
                scanId: scanId,
                scanTimestamp: Date(timeIntervalSince1970: timestamp),
                heightCm: heightCm,
                gender: gender,
                positiveMessage: positiveMessage,
                verticalType: verticalType,
                isPetite: isPetite,
                captureConfidence: captureConfidence,
                measurementsJSON: measurementsJSON,
                imageLocalFilename: (imageLocal?.isEmpty == false) ? imageLocal : nil,
                imageRemoteFileId: (imageRemote?.isEmpty == false) ? imageRemote : nil
            )
        }
    }

    // MARK: - Individual Garment Scan Persistence

    func saveGarmentScan(_ result: GarmentTagModel) async throws {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw ScanError.unauthenticated
        }

        let garmentJSONString: String
        let garmentJSON = result.exportJSON
        if JSONSerialization.isValidJSONObject(garmentJSON),
           let data = try? JSONSerialization.data(withJSONObject: garmentJSON, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            garmentJSONString = str
        } else {
            garmentJSONString = "{}"
        }

        let documentData: [String: Any] = [
            "scanId": UUID().uuidString,
            "scanTimestamp": Date().timeIntervalSince1970,
            "garmentDataJSON": garmentJSONString,
            "imageLocalFilename": result.imageLocalFilename ?? "",
            "imageRemoteFileId": result.imageRemoteFileId ?? ""
        ]

        do {
            _ = try await databases.createDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.garmentScansCollectionId,
                documentId: ID.unique(),
                data: documentData,
                permissions: [
                    Permission.read(Role.user(userId)),
                    Permission.write(Role.user(userId))
                ]
            )
            Log.info("Garment scan saved successfully")
        } catch {
            Log.error("Failed to save garment scan", context: ["error": error.localizedDescription])
            throw error
        }
    }

    func fetchGarmentScans() async throws -> [GarmentScanHistoryItem] {
        guard AuthService.shared.currentUser != nil else {
            throw ScanError.unauthenticated
        }

        let result = try await databases.listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.garmentScansCollectionId,
            queries: [Query.orderDesc("scanTimestamp")]
        )

        return result.documents.compactMap { doc -> GarmentScanHistoryItem? in
            guard let scanId = doc.data["scanId"]?.value as? String,
                  let timestamp = doc.data["scanTimestamp"]?.value as? Double,
                  let garmentDataJSON = doc.data["garmentDataJSON"]?.value as? String else {
                return nil
            }
            let imageLocal = doc.data["imageLocalFilename"]?.value as? String
            let imageRemote = doc.data["imageRemoteFileId"]?.value as? String
            return GarmentScanHistoryItem(
                id: doc.id,
                scanId: scanId,
                scanTimestamp: Date(timeIntervalSince1970: timestamp),
                garmentDataJSON: garmentDataJSON,
                imageLocalFilename: (imageLocal?.isEmpty == false) ? imageLocal : nil,
                imageRemoteFileId: (imageRemote?.isEmpty == false) ? imageRemote : nil
            )
        }
    }

    // MARK: - Update Remote Image ID

    func updateImageRemoteId(collectionId: String, documentId: String, fileId: String) async {
        do {
            _ = try await databases.updateDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: collectionId,
                documentId: documentId,
                data: ["imageRemoteFileId": fileId]
            )
        } catch {
            Log.error("Failed to update remote image ID", context: ["error": error.localizedDescription])
        }
    }
}
