import XCTest
import SwiftData
import MuscleLoadCore
@testable import MuscleLoadApp

final class RecoveryViewModelTests: XCTestCase {
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

    func test_load_withNoSessions_allReadyAndRecommendsReady() throws {
        let context = try makeInMemoryContext()
        let viewModel = RecoveryViewModel(repository: WorkoutRepository(modelContext: context))

        viewModel.load()

        XCTAssertEqual(viewModel.statuses.count, 13)
        XCTAssertTrue(viewModel.statuses.allSatisfy { $0.recoveryPercent == 100 })
        XCTAssertEqual(viewModel.recommendationText, "Все мышцы готовы к тренировке")
    }

    func test_load_sortsByRecoveryPercentAscending() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSessionRecord(date: .now, duration: 3600)
        let sets = (1...4).map { SetEntryRecord(exerciseID: "barbellSquat", weightKg: 100, reps: 8, setNumber: $0) }
        sets.forEach { $0.session = session }
        session.sets = sets
        context.insert(session)
        try context.save()

        let viewModel = RecoveryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        // barbellSquat's primary muscles are quadriceps AND glutes (both get the
        // full, capped-at-100 momentary load from 4 heavy sets) — they tie for
        // lowest recoveryPercent, so check the two lowest as a set rather than
        // assuming a specific tie-break order.
        let lowestTwo = Set([viewModel.statuses[0].muscleGroup, viewModel.statuses[1].muscleGroup])
        XCTAssertEqual(lowestTwo, Set([MuscleGroup.quadriceps, MuscleGroup.glutes]))
        XCTAssertEqual(viewModel.statuses[0].recoveryPercent, 0, accuracy: 0.01)
        XCTAssertEqual(viewModel.recommendationText, "Есть мышцы, которым нужен отдых — тренируйте то, что готово, или отдохните")
    }

    func test_recommendationText_reflectsWorstStatus_soon() throws {
        let context = try makeInMemoryContext()
        let sessionDate = Date(timeIntervalSince1970: 0)
        let sets = (1...4).map { SetEntryRecord(exerciseID: "barbellSquat", weightKg: 100, reps: 8, setNumber: $0) }
        let session = WorkoutSessionRecord(date: sessionDate, duration: 3600)
        sets.forEach { $0.session = session }
        session.sets = sets
        context.insert(session)
        try context.save()

        let viewModel = RecoveryViewModel(repository: WorkoutRepository(modelContext: context))
        // Halfway through quadriceps' 72h recovery window: capped 100% momentary
        // load decays linearly to 50%, so recoveryPercent = 50 -> status .soon.
        viewModel.load(asOf: sessionDate.addingTimeInterval(36 * 3600))

        XCTAssertEqual(viewModel.recommendationText, "Некоторые мышцы почти восстановились — лёгкая тренировка подойдёт")
    }
}
