import Foundation
import UIKit

class DeviceIdentifierManager {
    static let shared = DeviceIdentifierManager()
    
    private let keychainKey = "com.bjs.BodyMeasureAI.deviceIdentifier"
    
    private init() {}
    
    func getDeviceIdentifier() -> String {
        do {
            // Try to load existing identifier from Keychain
            return try KeychainManager.shared.loadString(key: keychainKey)
        } catch {
            // If not found, generate a new one
            let udid = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let timestamp = Int(Date().timeIntervalSince1970)
            let newIdentifier = "\(udid)_\(timestamp)"
            
            do {
                try KeychainManager.shared.saveString(key: keychainKey, value: newIdentifier)
            } catch {
                print("Failed to save device identifier to Keychain: \(error)")
            }
            
            return newIdentifier
        }
    }
    
    func resetDeviceIdentifier() {
        do {
            try KeychainManager.shared.delete(key: keychainKey)
        } catch {
            print("Failed to delete device identifier from Keychain: \(error)")
        }
    }
}
