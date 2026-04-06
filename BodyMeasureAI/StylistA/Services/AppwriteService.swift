import Foundation
import Appwrite

class AppwriteConfig {
    static let endpoint = "https://sgp.cloud.appwrite.io/v1"
    static let projectId = "69c541570033d3439bfb"
    static let databaseId = "stylista_db"
    static let scansCollectionId = "scans"
    static let bodyScansCollectionId = "body_scans"
    static let garmentScansCollectionId = "garment_scans"
    static let imagesBucketId = "scan_images"
}

class AppwriteService {
    static let shared = AppwriteService()

    let client: Client
    let account: Account
    let databases: Databases
    let storage: Storage

    private init() {
        self.client = Client()
            .setEndpoint(AppwriteConfig.endpoint)
            .setProject(AppwriteConfig.projectId)

        self.account = Account(client)
        self.databases = Databases(client)
        self.storage = Storage(client)
    }
}
