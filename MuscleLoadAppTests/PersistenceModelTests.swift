import XCTest
import SwiftData
@testable import MuscleLoadApp

final class PersistenceModelTests: XCTestCase {
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

    func test_workoutSessionRecord_persistsWithSets() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSessionRecord(date: .now, duration: 3600, perceivedEffort: 7)
        let set = SetEntryRecord(exerciseID: "barbellSquat", weightKg: 80, reps: 8, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)

        try context.save()

        let descriptor = FetchDescriptor<WorkoutSessionRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sets.count, 1)
        XCTAssertEqual(fetched.first?.sets.first?.exerciseID, "barbellSquat")
    }

    func test_customExerciseRecord_persists() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(name: "Моё упражнение", movementPatternID: "bicepCurl")
        context.insert(custom)
        try context.save()

        let descriptor = FetchDescriptor<CustomExerciseRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Моё упражнение")
        XCTAssertEqual(fetched.first?.movementPatternID, "bicepCurl")
    }

    func test_userProfileRecord_persistsWithDefaults() throws {
        let context = try makeInMemoryContext()
        let profile = UserProfileRecord()
        context.insert(profile)
        try context.save()

        let descriptor = FetchDescriptor<UserProfileRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched.first?.bodyweightKg)
        XCTAssertEqual(fetched.first?.notificationsEnabled, true)
    }
}
