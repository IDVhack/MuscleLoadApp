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

    func test_allExercises_includesBuiltInAndCustomSortedByName() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(id: "myCurl", name: "Аааа мой подъём", movementPatternID: "bicepCurl")
        context.insert(custom)
        try context.save()
        let repository = WorkoutRepository(modelContext: context)

        let exercises = try repository.allExercises()

        XCTAssertEqual(exercises.count, 24)
        XCTAssertEqual(exercises.first?.id, "myCurl")
    }

    func test_createCustomExercise_persistsAndReturnsExercise() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let created = try repository.createCustomExercise(
            name: "Мой присед",
            movementPatternID: "squat",
            techniqueDescription: "Описание"
        )

        XCTAssertEqual(created.name, "Мой присед")
        XCTAssertEqual(created.movementPattern.id, "squat")
        XCTAssertFalse(created.isBuiltIn)

        let stored = try context.fetch(FetchDescriptor<CustomExerciseRecord>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, created.id)
    }

    func test_createCustomExercise_throwsForUnknownMovementPattern() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        XCTAssertThrowsError(
            try repository.createCustomExercise(name: "X", movementPatternID: "doesNotExist", techniqueDescription: nil)
        ) { error in
            XCTAssertEqual(error as? WorkoutRepositoryError, .unknownMovementPattern)
        }
    }

    func test_updateCustomExercise_changesFields() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        let created = try repository.createCustomExercise(name: "Старое имя", movementPatternID: "squat", techniqueDescription: nil)

        try repository.updateCustomExercise(id: created.id, name: "Новое имя", movementPatternID: "bicepCurl", techniqueDescription: "Новая техника")

        let updated = try repository.resolveExercise(id: created.id)
        XCTAssertEqual(updated?.name, "Новое имя")
        XCTAssertEqual(updated?.movementPattern.id, "bicepCurl")
        XCTAssertEqual(updated?.techniqueDescription, "Новая техника")
    }

    func test_updateCustomExercise_doesNothingForBuiltInID() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        try repository.updateCustomExercise(id: "barbellSquat", name: "Hacked", movementPatternID: "bicepCurl", techniqueDescription: nil)

        let stillBuiltIn = try repository.resolveExercise(id: "barbellSquat")
        XCTAssertEqual(stillBuiltIn?.name, "Приседания со штангой")
    }

    func test_deleteCustomExercise_removesUnusedExercise() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        let created = try repository.createCustomExercise(name: "Удали меня", movementPatternID: "squat", techniqueDescription: nil)

        try repository.deleteCustomExercise(id: created.id)

        XCTAssertNil(try repository.resolveExercise(id: created.id))
    }

    func test_deleteCustomExercise_throwsWhenExerciseIsUsedInASession() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        let created = try repository.createCustomExercise(name: "Используется", movementPatternID: "squat", techniqueDescription: nil)

        let session = WorkoutSessionRecord(date: .now, duration: 1800)
        let set = SetEntryRecord(exerciseID: created.id, weightKg: 50, reps: 10, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)
        try context.save()

        XCTAssertThrowsError(try repository.deleteCustomExercise(id: created.id)) { error in
            XCTAssertEqual(error as? WorkoutRepositoryError, .exerciseInUse)
        }
        XCTAssertNotNil(try repository.resolveExercise(id: created.id))
    }
}
