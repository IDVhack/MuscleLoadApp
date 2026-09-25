import XCTest
@testable import MuscleLoadCore

final class SetEntryTests: XCTestCase {
    func test_rawLoad_multipliesWeightRepsAndCoefficient() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }!
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        // 80 * 8 * 1.8 = 1152, per spec section 4's raw_load formula.
        XCTAssertEqual(set.rawLoad, 1152, accuracy: 0.001)
    }

    func test_workoutSession_holdsMultipleSets() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }!
        let sets = (1...3).map { SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: $0) }
        let session = WorkoutSession(date: .now, sets: sets, perceivedEffort: 7)

        XCTAssertEqual(session.sets.count, 3)
        XCTAssertEqual(session.perceivedEffort, 7)
    }
}
