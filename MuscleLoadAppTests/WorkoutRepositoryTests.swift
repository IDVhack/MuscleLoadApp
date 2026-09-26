import XCTest
import SwiftData
import MuscleLoadCore
@testable import MuscleLoadApp

final class WorkoutRepositoryTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            WorkoutSessionRecord.self,
            SetEntryRecord.self,
            CustomExerciseRecord.self,
            UserProfileRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func test_resolveExercise_returnsBuiltInFromCatalog() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let exercise = repository.resolveExercise(id: "barbellSquat")

        XCTAssertEqual(exercise?.name, "Приседания со штангой")
        XCTAssertEqual(exercise?.movementPattern.id, "squat")
    }

    func test_resolveExercise_returnsCustomExerciseFromStore() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(id: "myCurl", name: "Мой подъём", movementPatternID: "bicepCurl")
        context.insert(custom)
        let repository = WorkoutRepository(modelContext: context)

        let exercise = repository.resolveExercise(id: "myCurl")

        XCTAssertEqual(exercise?.name, "Мой подъём")
        XCTAssertEqual(exercise?.movementPattern.id, "bicepCurl")
        XCTAssertFalse(exercise?.isBuiltIn ?? true)
    }

    func test_resolveExercise_returnsNilForUnknownID() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        XCTAssertNil(repository.resolveExercise(id: "doesNotExist"))
    }

    func test_currentRecoveryStatuses_reflectsPersistedSession() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSessionRecord(date: .now, duration: 3600)
        let set = SetEntryRecord(exerciseID: "barbellSquat", weightKg: 80, reps: 8, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)
        try context.save()

        let repository = WorkoutRepository(modelContext: context)
        let statuses = try repository.currentRecoveryStatuses(asOf: .now)

        XCTAssertEqual(statuses.count, 13)
        let quadriceps = statuses.first { $0.muscleGroup == .quadriceps }
        XCTAssertNotNil(quadriceps)
        XCTAssertLessThan(quadriceps!.recoveryPercent, 100)
    }

    func test_currentRecoveryStatuses_withNoSessions_isFullyRecovered() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let statuses = try repository.currentRecoveryStatuses(asOf: .now)

        XCTAssertEqual(statuses.count, 13)
        XCTAssertTrue(statuses.allSatisfy { $0.recoveryPercent == 100 })
    }
}
