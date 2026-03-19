import XCTest
import Vision
@testable import BodyMeasureAI

final class BodyClassificationEngineTests: XCTestCase {
    
    var engine: BodyClassificationEngine!

    override func setUp() {
        super.setUp()
        engine = BodyClassificationEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Women's Threshold Tests
    
    func testWomensHourglassStrictness() {
        // Hourglass requires abs(M1 - M2) <= 7.62 and M3 to be significantly smaller
        let output = engine.classify(
            m1: 100, m2: 102, m3: 75,
            v1: 50, v2: 50,
            userHeightCm: 170, isFemale: true
        )
        XCTAssertTrue(output.positiveMessage.contains("highlight your natural waist and celebrate your balanced curves"))
    }
    
    func testWomensPetiteAddition() {
        // Less than 165cm should trigger the petite string
        let output = engine.classify(
            m1: 100, m2: 100, m3: 100,
            v1: 50, v2: 50,
            userHeightCm: 164, isFemale: true
        )
        XCTAssertTrue(output.isPetite)
        XCTAssertTrue(output.positiveMessage.contains("As a petite frame, clothing needs to create length"))
        
        // 165cm or more should NOT trigger
        let outputNotPetite = engine.classify(
            m1: 100, m2: 100, m3: 100,
            v1: 50, v2: 50,
            userHeightCm: 165, isFemale: true
        )
        XCTAssertFalse(outputNotPetite.isPetite)
        XCTAssertFalse(outputNotPetite.positiveMessage.contains("vertical lines in the middle slim the person as well as add length"))
    }
    
    // MARK: - Men's Imbalance & Waist Tests
    
    func testMensImbalanceThresholdExactly15cm() {
        // Exactly 15cm difference should not trigger the imbalance message (must be > 15)
        let outputNoTrigger = engine.classify(
            m1: 115, m2: 100, m3: 90,
            v1: 60, v2: 60,
            userHeightCm: 180, isFemale: false,
            waistProminenceScore: 0.1
        )
        XCTAssertFalse(outputNoTrigger.positiveMessage.contains("balance your strong upper body"))
        
        // > 15cm difference should trigger
        let outputTrigger = engine.classify(
            m1: 116, m2: 100, m3: 90,
            v1: 60, v2: 60,
            userHeightCm: 180, isFemale: false,
            waistProminenceScore: 0.1
        )
        XCTAssertTrue(outputTrigger.positiveMessage.contains("balance your strong upper body"))
    }
    
    func testMensWaistFrontProminence() {
        // Waist larger than shoulders and hips, with a high prominence score
        let output = engine.classify(
            m1: 100, m2: 100, m3: 110,
            v1: 60, v2: 60,
            userHeightCm: 180, isFemale: false,
            waistProminenceScore: 0.6
        )
        XCTAssertTrue(output.positiveMessage.contains("clean lines and cuts that smooth and flatter your midsection"))
    }
}
