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

        let exercise = try repository.resolveExercise(id: "barbellSquat")

        XCTAssertEqual(exercise?.name, "Приседания со штангой")
        XCTAssertEqual(exercise?.movementPattern.id, "squat")
    }

    func test_resolveExercise_returnsCustomExerciseFromStore() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(id: "myCurl", name: "Мой подъём", movementPatternID: "bicepCurl")
        context.insert(custom)
        let repository = WorkoutRepository(modelContext: context)

        let exercise = try repository.resolveExercise(id: "myCurl")

        XCTAssertEqual(exercise?.name, "Мой подъём")
        XCTAssertEqual(exercise?.movementPattern.id, "bicepCurl")
        XCTAssertFalse(exercise?.isBuiltIn ?? true)
    }

    func test_resolveExercise_returnsNilForUnknownID() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        XCTAssertNil(try repository.resolveExercise(id: "doesNotExist"))
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

    func test_currentRecoveryStatuses_dropsSetsWithUnresolvableExercise() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSessionRecord(date: .now, duration: 3600)
        let goodSet = SetEntryRecord(exerciseID: "barbellSquat", weightKg: 80, reps: 8, setNumber: 1)
        let badSet = SetEntryRecord(exerciseID: "deletedExercise", weightKg: 50, reps: 10, setNumber: 2)
        goodSet.session = session
        badSet.session = session
        session.sets = [goodSet, badSet]
        context.insert(session)
        try context.save()

        let repository = WorkoutRepository(modelContext: context)
        let statuses = try repository.currentRecoveryStatuses(asOf: .now)

        XCTAssertEqual(statuses.count, 13)
        let quadriceps = statuses.first { $0.muscleGroup == .quadriceps }
        XCTAssertNotNil(quadriceps)
        XCTAssertLessThan(quadriceps!.recoveryPercent, 100)
    }

    func test_currentRecoveryStatuses_resolvesCustomExerciseThroughFullPath() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(id: "myCurl", name: "Мой подъём", movementPatternID: "bicepCurl")
        context.insert(custom)

        let session = WorkoutSessionRecord(date: .now, duration: 3600)
        let set = SetEntryRecord(exerciseID: "myCurl", weightKg: 15, reps: 10, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)
        try context.save()

        let repository = WorkoutRepository(modelContext: context)
        let statuses = try repository.currentRecoveryStatuses(asOf: .now)

        let biceps = statuses.first { $0.muscleGroup == .biceps }
        XCTAssertNotNil(biceps)
        XCTAssertLessThan(biceps!.recoveryPercent, 100)
    }

    func test_fetchOrCreateProfile_createsOneWhenNoneExists() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let profile = try repository.fetchOrCreateProfile()

        XCTAssertNil(profile.bodyweightKg)
        XCTAssertEqual(profile.notificationsEnabled, true)

        let descriptor = FetchDescriptor<UserProfileRecord>()
        XCTAssertEqual(try context.fetch(descriptor).count, 1)
    }

    func test_fetchOrCreateProfile_returnsExistingWhenPresent() throws {
        let context = try makeInMemoryContext()
        let existing = UserProfileRecord(bodyweightKg: 78.5)
        context.insert(existing)
        try context.save()
        let repository = WorkoutRepository(modelContext: context)

        let profile = try repository.fetchOrCreateProfile()

        XCTAssertEqual(profile.bodyweightKg, 78.5)
        let descriptor = FetchDescriptor<UserProfileRecord>()
        XCTAssertEqual(try context.fetch(descriptor).count, 1)
    }
}
