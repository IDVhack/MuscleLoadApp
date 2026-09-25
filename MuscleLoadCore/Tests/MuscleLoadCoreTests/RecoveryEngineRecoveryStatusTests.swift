import XCTest
@testable import MuscleLoadCore

final class RecoveryEngineRecoveryStatusTests: XCTestCase {
    let engine = RecoveryEngine()

    private func exercise(_ id: String) -> Exercise {
        ExerciseCatalog.all.first { $0.id == id }!
    }

    func test_recoveryStatus_returnsAllThirteenMuscleGroups() {
        let statuses = engine.recoveryStatus(asOf: .now, sessions: [])
        XCTAssertEqual(statuses.count, 13)
        XCTAssertTrue(statuses.allSatisfy { $0.recoveryPercent == 100 && $0.status == .ready })
    }

    func test_recoveryStatus_immediatelyAfterSession_isEarly() {
        let squat = exercise("barbellSquat")
        let sets = (1...4).map { SetEntry(exercise: squat, weightKg: 100, reps: 8, setNumber: $0) }
        let sessionDate = Date()
        let session = WorkoutSession(date: sessionDate, sets: sets)

        let statuses = engine.recoveryStatus(asOf: sessionDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        // 4 * 100kg * 8 reps * 1.8 = 5760 raw, capped at 100% momentary load.
        // Right at session end: recoveryPercent = 100 - 100 = 0%.
        XCTAssertEqual(quadStatus.recoveryPercent, 0, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .early)
    }

    func test_recoveryStatus_atEndOfWindow_isFullyRecovered() {
        let squat = exercise("barbellSquat")
        let sessionDate = Date(timeIntervalSince1970: 0)
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: sessionDate, sets: [set])

        // Quadriceps window is 72h.
        let checkDate = sessionDate.addingTimeInterval(72 * 3600)
        let statuses = engine.recoveryStatus(asOf: checkDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertEqual(quadStatus.recoveryPercent, 100, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .ready)
    }

    func test_recoveryStatus_halfwayThroughWindow_isPartiallyRecovered() {
        let squat = exercise("barbellSquat")
        let sessionDate = Date(timeIntervalSince1970: 0)
        let sets = (1...4).map { SetEntry(exercise: squat, weightKg: 100, reps: 8, setNumber: $0) }
        let session = WorkoutSession(date: sessionDate, sets: sets)

        // Momentary load for quadriceps is capped at 100% (huge session).
        // Halfway through the 72h window (36h): remaining load = 100 * 0.5 = 50.
        // recoveryPercent = 100 - 50 = 50 -> status .soon (40..<85).
        let checkDate = sessionDate.addingTimeInterval(36 * 3600)
        let statuses = engine.recoveryStatus(asOf: checkDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertEqual(quadStatus.recoveryPercent, 50, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .soon)
    }

    func test_recoveryStatus_stacksLoadFromOverlappingSessions() {
        let squat = exercise("barbellSquat")
        let firstSessionDate = Date(timeIntervalSince1970: 0)
        let secondSessionDate = firstSessionDate.addingTimeInterval(24 * 3600)

        let firstSet = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let secondSet = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)

        let sessions = [
            WorkoutSession(date: firstSessionDate, sets: [firstSet]),
            WorkoutSession(date: secondSessionDate, sets: [secondSet])
        ]

        // Right after the second session, session 1's partially-decayed load
        // stacks with session 2's fresh load, so recovery must be lower than
        // if only session 2 had happened.
        let checkDate = secondSessionDate
        let stackedStatuses = engine.recoveryStatus(asOf: checkDate, sessions: sessions)
        let stackedQuad = stackedStatuses.first { $0.muscleGroup == .quadriceps }!

        let singleSessionStatuses = engine.recoveryStatus(asOf: checkDate, sessions: [sessions[1]])
        let singleQuad = singleSessionStatuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertLessThan(stackedQuad.recoveryPercent, singleQuad.recoveryPercent)
    }

    func test_recoveryStatus_futureSessionsAreIgnored() {
        let squat = exercise("barbellSquat")
        let futureDate = Date(timeIntervalSince1970: 1_000_000)
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: futureDate, sets: [set])

        let statuses = engine.recoveryStatus(asOf: Date(timeIntervalSince1970: 0), sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertEqual(quadStatus.recoveryPercent, 100, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .ready)
    }

    func test_recoveryStatus_negativeLoadDoesNotExceedOneHundredPercent() {
        let squat = exercise("barbellSquat")
        let sessionDate = Date(timeIntervalSince1970: 0)
        // Pathological negative weight: nothing today constructs a SetEntry
        // this way, but the type system doesn't prevent it. Negative weight
        // drives rawLoad negative, which drives momentaryLoad and currentLoad
        // negative -- an "unloading" that never actually happens physically.
        let set = SetEntry(exercise: squat, weightKg: -80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: sessionDate, sets: [set])

        let statuses = engine.recoveryStatus(asOf: sessionDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        // currentLoad[quadriceps] is negative here, so after floor-clamping
        // load to max(0, ...) == 0, recoveryPercent = 100 - 0 = exactly 100.
        // Without the floor clamp this would exceed 100.
        XCTAssertEqual(quadStatus.recoveryPercent, 100, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(quadStatus.recoveryPercent, 100)
        XCTAssertEqual(quadStatus.status, .ready)
    }
}
