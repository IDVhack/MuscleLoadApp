import XCTest
@testable import MuscleLoadCore

final class MovementPatternCatalogTests: XCTestCase {
    func test_hasTwentyPatterns() {
        XCTAssertEqual(MovementPatternCatalog.all.count, 20)
    }

    func test_allPatternIDsAreUnique() {
        let ids = MovementPatternCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_squat_hasExpectedMusclesAndCoefficient() {
        let squat = MovementPatternCatalog.squat
        XCTAssertEqual(squat.primaryMuscles, [.quadriceps, .glutes])
        XCTAssertEqual(squat.secondaryMuscles, [.hamstrings, .lowerBack, .absCore])
        XCTAssertEqual(squat.heavinessCoefficient, 1.8)
    }

    func test_verticalPullPatterns_haveDifferentCoefficients() {
        // Split from one "Тяга вертикальная" pattern name in chat because
        // bodyweight pull-ups and cable lat pulldowns have different
        // heaviness — see plan header note.
        XCTAssertEqual(MovementPatternCatalog.verticalPullBodyweight.heavinessCoefficient, 1.5)
        XCTAssertEqual(MovementPatternCatalog.verticalPullCable.heavinessCoefficient, 1.3)
    }

    func test_overheadPressPatterns_haveDifferentCoefficients() {
        XCTAssertEqual(MovementPatternCatalog.overheadPressSeated.heavinessCoefficient, 1.3)
        XCTAssertEqual(MovementPatternCatalog.overheadPressStanding.heavinessCoefficient, 1.4)
    }

    func test_tricepExtensionPatterns_haveDifferentCoefficients() {
        XCTAssertEqual(MovementPatternCatalog.tricepExtensionCable.heavinessCoefficient, 0.8)
        XCTAssertEqual(MovementPatternCatalog.tricepExtensionLying.heavinessCoefficient, 0.9)
    }

    func test_hipAbduction_hasNoSecondaryMuscles() {
        XCTAssertTrue(MovementPatternCatalog.hipAbduction.secondaryMuscles.isEmpty)
    }
}
