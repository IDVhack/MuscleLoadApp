import XCTest
@testable import MuscleLoadCore

final class RecoveryEngineMomentaryLoadTests: XCTestCase {
    let engine = RecoveryEngine()

    private func exercise(_ id: String) -> Exercise {
        ExerciseCatalog.all.first { $0.id == id }!
    }

    func test_momentaryLoad_singleSet_splitsPrimaryAndSecondary() {
        let squat = exercise("barbellSquat")
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: .now, sets: [set])

        let load = engine.momentaryLoad(for: session)

        // rawLoad = 80 * 8 * 1.8 = 1152.
        // Primary (quadriceps, glutes) get full 1152, threshold 4500 (large).
        XCTAssertEqual(load[.quadriceps] ?? 0, 1152 / 4500 * 100, accuracy: 0.01)
        XCTAssertEqual(load[.glutes] ?? 0, 1152 / 4500 * 100, accuracy: 0.01)

        // Secondary (hamstrings, lowerBack, absCore) get half: 576.
        XCTAssertEqual(load[.hamstrings] ?? 0, 576 / 3000 * 100, accuracy: 0.01)
        XCTAssertEqual(load[.lowerBack] ?? 0, 576 / 3000 * 100, accuracy: 0.01)
        XCTAssertEqual(load[.absCore] ?? 0, 576 / 1500 * 100, accuracy: 0.01)
    }

    func test_momentaryLoad_capsAtOneHundredPercent() {
        let squat = exercise("barbellSquat")
        let sets = (1...10).map { SetEntry(exercise: squat, weightKg: 150, reps: 12, setNumber: $0) }
        let session = WorkoutSession(date: .now, sets: sets)

        let load = engine.momentaryLoad(for: session)

        XCTAssertEqual(load[.quadriceps] ?? 0, 100, accuracy: 0.01)
    }

    func test_momentaryLoad_multipleExercises_accumulatePerMuscle() {
        let squat = exercise("barbellSquat")
        let lunge = exercise("bulgarianSplitSquat")
        let squatSet = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let lungeSet = SetEntry(exercise: lunge, weightKg: 20, reps: 10, setNumber: 1)
        let session = WorkoutSession(date: .now, sets: [squatSet, lungeSet])

        // Both exercises have quadriceps as primary, so their contributions add up.
        let load = engine.momentaryLoad(for: session)
        let squatRaw = 80.0 * 8 * 1.8
        let lungeRaw = 20.0 * 10 * 1.4
        let expected = min(100, (squatRaw + lungeRaw) / 4500 * 100)
        XCTAssertEqual(load[.quadriceps] ?? 0, expected, accuracy: 0.01)
    }
}
