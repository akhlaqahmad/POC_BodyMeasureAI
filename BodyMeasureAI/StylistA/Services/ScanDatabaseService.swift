import Foundation
import Appwrite
import AppwriteModels
import JSONCodable

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
        
        let documentData: [String: AnyCodable] = [
            "userId": AnyCodable(userId),
            "sessionId": AnyCodable(session.sessionId),
            "scanTimestamp": AnyCodable(session.sessionTimestamp.timeIntervalSince1970),
            "heightCm": AnyCodable(session.userInputs.heightCm),
            "gender": AnyCodable(session.userInputs.gender),
            "scanDataJSON": AnyCodable(session.prettyPrintedJSON() ?? "")
        ]
        
        do {
            _ = try await databases.createDocument(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.scansCollectionId,
                documentId: ID.unique(),
                data: documentData
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
            queries: [Query.equal("userId", value: userId), Query.orderDesc("scanTimestamp")]
        )
        
        return result.documents
    }
    
    private func savePendingScanLocally(documentData: [String: AnyCodable]) {
        // We need to convert AnyCodable dictionary to JSON Data
        if let data = try? JSONEncoder().encode(documentData) {
            var pendingScans = UserDefaults.standard.array(forKey: pendingScansKey) as? [Data] ?? []
            pendingScans.append(data)
            UserDefaults.standard.set(pendingScans, forKey: pendingScansKey)
        }
    }
    
    func retryPendingScans() async {
        guard let pendingScans = UserDefaults.standard.array(forKey: pendingScansKey) as? [Data], !pendingScans.isEmpty else { return }
        
        var remainingScans: [Data] = []
        
        for scanData in pendingScans {
            do {
                if let documentData = try? JSONDecoder().decode([String: AnyCodable].self, from: scanData) {
                    _ = try await databases.createDocument(
                        databaseId: AppwriteConfig.databaseId,
                        collectionId: AppwriteConfig.scansCollectionId,
                        documentId: ID.unique(),
                        data: documentData
                    )
                }
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
}
