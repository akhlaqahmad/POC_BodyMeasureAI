import XCTest
@testable import BodyMeasureAI

final class KeychainManagerTests: XCTestCase {
    let testKey = "com.bjs.BodyMeasureAI.testKey"
    let testValue = "test_identifier_12345"

    override func setUpWithError() throws {
        // Clear before each test
        try? KeychainManager.shared.delete(key: testKey)
    }

    override func tearDownWithError() throws {
        // Clear after each test
        try? KeychainManager.shared.delete(key: testKey)
    }

    func testSaveAndLoadString() throws {
        // Save
        try KeychainManager.shared.saveString(key: testKey, value: testValue)
        
        // Load
        let loadedValue = try KeychainManager.shared.loadString(key: testKey)
        
        XCTAssertEqual(loadedValue, testValue, "Loaded value should match the saved value.")
    }
    
    func testDelete() throws {
        try KeychainManager.shared.saveString(key: testKey, value: testValue)
        try KeychainManager.shared.delete(key: testKey)
        
        XCTAssertThrowsError(try KeychainManager.shared.loadString(key: testKey)) { error in
            guard let keychainError = error as? KeychainManager.KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            if case .itemNotFound = keychainError {
                // Success
            } else {
                XCTFail("Expected itemNotFound, got \(keychainError)")
            }
        }
    }
}
