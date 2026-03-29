import Foundation
import Appwrite

class AppwriteConfig {
    static let endpoint = "https://sgp.cloud.appwrite.io/v1"
    static let projectId = "69c541570033d3439bfb"
    static let databaseId = "stylista_db"
    static let scansCollectionId = "scans"
}

class AppwriteService {
    static let shared = AppwriteService()
    
    let client: Client
    let account: Account
    let databases: Databases
    
    private init() {
        self.client = Client()
            .setEndpoint(AppwriteConfig.endpoint)
            .setProject(AppwriteConfig.projectId)
        
        self.account = Account(client)
        self.databases = Databases(client)
    }
}
