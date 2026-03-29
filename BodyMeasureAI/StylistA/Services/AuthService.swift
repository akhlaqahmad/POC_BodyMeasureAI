import Foundation
import Combine
import Appwrite
import AppwriteModels
import JSONCodable

enum AuthState {
    case uninitialized
    case checking
    case loggedIn
    case recoveryNeeded(previousSessionId: String)
    case error(Error)
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var authState: AuthState = .uninitialized
    @Published var currentUser: AppwriteModels.User<[String: AnyCodable]>?
    
    private let account = AppwriteService.shared.account
    private let databases = AppwriteService.shared.databases
    
    private init() {}
    
    /// Entry point on app launch
    func initializeAuth() async {
        DispatchQueue.main.async {
            self.authState = .checking
        }
        
        do {
            // Check if we are already logged in
            let user = try await account.get()
            
            // If logged in, we are good to go
            DispatchQueue.main.async {
                self.currentUser = user
                self.authState = .loggedIn
            }
            Task {
                await ScanDatabaseService.shared.retryPendingScans()
            }
        } catch {
            // Not logged in.
            // Check if we have a device identifier from a previous install
            let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            let deviceId = DeviceIdentifierManager.shared.getDeviceIdentifier()
            
            if isFirstLaunch {
                // If it's a fresh install but we have a Keychain ID, we might need recovery
                do {
                    // Try to create an anonymous session with a specific ID, but Appwrite anonymous sessions don't take a custom ID.
                    // Actually, anonymous users in Appwrite have a random ID. We can't specify it.
                    // Wait! The requirement says: "using their device UDID combined with a timestamp identifier upon app launch"
                    // If we use Email/Password with the device ID as email and password? Or use createAnonymousSession?
                    // Anonymous sessions create a random user ID.
                    // Alternatively, we can use createEmailPasswordSession with a dummy email constructed from the device ID!
                    // Let's use Email/Password to allow cross-install recovery via the persistent device ID.
                    
                    let dummyEmail = "\(deviceId)@anonymous.stylista.app"
                    let dummyPassword = deviceId.padding(toLength: 8, withPad: "x", startingAt: 0) // Ensure 8 chars
                    
                    do {
                        let session = try await account.createEmailPasswordSession(email: dummyEmail, password: dummyPassword)
                        let user = try await account.get()
                        
                        // Check if they have previous scans to prompt recovery
                        let scans = try await databases.listDocuments(
                            databaseId: AppwriteConfig.databaseId,
                            collectionId: AppwriteConfig.scansCollectionId,
                            queries: [Query.equal("userId", value: user.id)]
                        )
                        
                        DispatchQueue.main.async {
                            if scans.total > 0 {
                                self.authState = .recoveryNeeded(previousSessionId: session.id)
                            } else {
                                self.currentUser = user
                                self.authState = .loggedIn
                            }
                            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        }
                    } catch let error as AppwriteError {
                        if error.code == 0 {
                            throw error
                        }
                        // User doesn't exist or invalid credentials, create it
                        let user = try await account.create(userId: ID.unique(), email: dummyEmail, password: dummyPassword, name: "Anonymous User")
                        _ = try await account.createEmailPasswordSession(email: dummyEmail, password: dummyPassword)
                        
                        DispatchQueue.main.async {
                            self.currentUser = user
                            self.authState = .loggedIn
                            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        }
                    } catch {
                        // General fallback
                        throw error
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.authState = .error(error)
                    }
                }
            } else {
                // Not first launch but not logged in. Just log them back in.
                await loginWithDeviceIdentifier()
            }
        }
    }
    
    func loginWithDeviceIdentifier() async {
        let deviceId = DeviceIdentifierManager.shared.getDeviceIdentifier()
        let dummyEmail = "\(deviceId)@anonymous.stylista.app"
        let dummyPassword = deviceId.padding(toLength: 8, withPad: "x", startingAt: 0)
        
        do {
            _ = try await account.createEmailPasswordSession(email: dummyEmail, password: dummyPassword)
            let user = try await account.get()
            DispatchQueue.main.async {
                self.currentUser = user
                self.authState = .loggedIn
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
    
    func acceptRecovery() async {
        // They accepted to restore previous data.
        // We just proceed as logged in.
        do {
            let user = try await account.get()
            DispatchQueue.main.async {
                self.currentUser = user
                self.authState = .loggedIn
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
    
    func declineRecovery() async {
        // They declined recovery. We need to create a NEW account and leave the old one alone.
        // We will generate a NEW device ID, save it to Keychain, and create a new account.
        DeviceIdentifierManager.shared.resetDeviceIdentifier()
        let newDeviceId = DeviceIdentifierManager.shared.getDeviceIdentifier()
        
        // Log out of the recovered account
        do {
            try await account.deleteSession(sessionId: "current")
        } catch {
            print("Failed to delete current session: \(error)")
        }
        
        let dummyEmail = "\(newDeviceId)@anonymous.stylista.app"
        let dummyPassword = newDeviceId.padding(toLength: 8, withPad: "x", startingAt: 0)
        
        do {
            let user = try await account.create(userId: ID.unique(), email: dummyEmail, password: dummyPassword, name: "Anonymous User")
            _ = try await account.createEmailPasswordSession(email: dummyEmail, password: dummyPassword)
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.authState = .loggedIn
            }
        } catch {
            DispatchQueue.main.async {
                self.authState = .error(error)
            }
        }
    }
}
