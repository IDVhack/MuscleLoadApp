import XCTest
@testable import MuscleLoadCore

final class ExerciseCatalogTests: XCTestCase {
    func test_hasTwentyThreeBuiltInExercises() {
        XCTAssertEqual(ExerciseCatalog.all.count, 23)
        XCTAssertTrue(ExerciseCatalog.all.allSatisfy(\.isBuiltIn))
    }

    func test_allExerciseIDsAreUnique() {
        let ids = ExerciseCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_barbellSquat_usesSquatPattern() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }
        XCTAssertEqual(squat?.movementPattern.id, "squat")
    }

    func test_hipAbductionExercises_shareSamePattern() {
        let cable = ExerciseCatalog.all.first { $0.id == "cableHipAbduction" }
        let seated = ExerciseCatalog.all.first { $0.id == "seatedHipAbduction" }
        XCTAssertEqual(cable?.movementPattern.id, "hipAbduction")
        XCTAssertEqual(seated?.movementPattern.id, "hipAbduction")
    }

    func test_pullUp_usesBodyweightVerticalPull() {
        let pullUp = ExerciseCatalog.all.first { $0.id == "pullUp" }
        XCTAssertEqual(pullUp?.movementPattern.id, "verticalPullBodyweight")
    }

    func test_imageAndTechniqueDefaultToNil() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }
        XCTAssertNil(squat?.imageAssetName)
        XCTAssertNil(squat?.techniqueDescription)
    }

    func test_exercise_returnsMatchingExerciseByID() {
        let squat = ExerciseCatalog.exercise(id: "barbellSquat")
        XCTAssertEqual(squat?.name, "Приседания со штангой")
    }

    func test_exercise_returnsNilForUnknownID() {
        XCTAssertNil(ExerciseCatalog.exercise(id: "doesNotExist"))
    }
}
