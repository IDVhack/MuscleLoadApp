import XCTest

final class PipelineSanityTests: XCTestCase {
    func test_ciPipelineCatchesFailures() {
        XCTAssertTrue(false, "this must fail until Step 5")
    }
}
