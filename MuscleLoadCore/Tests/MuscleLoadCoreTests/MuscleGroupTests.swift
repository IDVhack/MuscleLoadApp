import XCTest
@testable import MuscleLoadCore

final class MuscleGroupTests: XCTestCase {
    func test_hasThirteenCases() {
        XCTAssertEqual(MuscleGroup.allCases.count, 13)
    }

    func test_recoveryWindow_largeMuscles_is72Hours() {
        XCTAssertEqual(MuscleGroup.quadriceps.recoveryWindowHours, 72)
        XCTAssertEqual(MuscleGroup.glutes.recoveryWindowHours, 72)
        XCTAssertEqual(MuscleGroup.upperBack.recoveryWindowHours, 72)
        XCTAssertEqual(MuscleGroup.chest.recoveryWindowHours, 72)
    }

    func test_recoveryWindow_mediumMuscles_is48Hours() {
        XCTAssertEqual(MuscleGroup.hamstrings.recoveryWindowHours, 48)
        XCTAssertEqual(MuscleGroup.lowerBack.recoveryWindowHours, 48)
        XCTAssertEqual(MuscleGroup.shoulders.recoveryWindowHours, 48)
    }

    func test_recoveryWindow_smallMuscles_is24Hours() {
        XCTAssertEqual(MuscleGroup.biceps.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.triceps.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.calves.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.forearms.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.adductors.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.absCore.recoveryWindowHours, 24)
    }

    func test_fullLoadThreshold_matchesSizeCategory() {
        XCTAssertEqual(MuscleGroup.quadriceps.fullLoadThreshold, 4500)
        XCTAssertEqual(MuscleGroup.hamstrings.fullLoadThreshold, 3000)
        XCTAssertEqual(MuscleGroup.biceps.fullLoadThreshold, 1500)
    }

    func test_allCases_haveNonEmptyDisplayName() {
        for muscle in MuscleGroup.allCases {
            XCTAssertFalse(muscle.displayName.isEmpty, "\(muscle) has empty displayName")
        }
    }
}
