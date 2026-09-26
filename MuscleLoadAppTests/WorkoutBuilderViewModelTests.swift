import XCTest
import SwiftData
import MuscleLoadCore
@testable import MuscleLoadApp

final class WorkoutBuilderViewModelTests: XCTestCase {
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

    func test_start_setsActivePhaseAndClearsDrafts() throws {
        let context = try makeInMemoryContext()
        let viewModel = WorkoutBuilderViewModel(modelContext: context)

        viewModel.start()

        XCTAssertEqual(viewModel.phase, .active)
        XCTAssertTrue(viewModel.draftSets.isEmpty)
    }

    func test_addSet_appendsDraft() throws {
        let context = try makeInMemoryContext()
        let viewModel = WorkoutBuilderViewModel(modelContext: context)
        let squat = ExerciseCatalog.exercise(id: "barbellSquat")!

        viewModel.start()
        viewModel.addSet(exercise: squat, weightKg: 80, reps: 8)

        XCTAssertEqual(viewModel.draftSets.count, 1)
        XCTAssertEqual(viewModel.draftSets[0].exercise.id, "barbellSquat")
        XCTAssertEqual(viewModel.draftSets[0].weightKg, 80)
        XCTAssertEqual(viewModel.draftSets[0].reps, 8)
    }

    func test_removeSet_removesByID() throws {
        let context = try makeInMemoryContext()
        let viewModel = WorkoutBuilderViewModel(modelContext: context)
        let squat = ExerciseCatalog.exercise(id: "barbellSquat")!

        viewModel.start()
        viewModel.addSet(exercise: squat, weightKg: 80, reps: 8)
        let idToRemove = viewModel.draftSets[0].id

        viewModel.removeSet(id: idToRemove)

        XCTAssertTrue(viewModel.draftSets.isEmpty)
    }

    func test_finish_savesSessionWithPerExerciseSetNumbers() throws {
        let context = try makeInMemoryContext()
        let viewModel = WorkoutBuilderViewModel(modelContext: context)
        let squat = ExerciseCatalog.exercise(id: "barbellSquat")!
        let curl = ExerciseCatalog.exercise(id: "dumbbellBicepCurl")!

        viewModel.start()
        viewModel.addSet(exercise: squat, weightKg: 80, reps: 8)
        viewModel.addSet(exercise: squat, weightKg: 80, reps: 8)
        viewModel.addSet(exercise: curl, weightKg: 12, reps: 10)
        viewModel.finish(perceivedEffort: 7)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSessionRecord>())
        XCTAssertEqual(sessions.count, 1)
        let session = sessions[0]
        XCTAssertEqual(session.sets.count, 3)
        XCTAssertEqual(session.perceivedEffort, 7)
        XCTAssertGreaterThanOrEqual(session.duration, 0)

        let squatSetNumbers = session.sets
            .filter { $0.exerciseID == "barbellSquat" }
            .map(\.setNumber)
            .sorted()
        XCTAssertEqual(squatSetNumbers, [1, 2])

        let curlSetNumbers = session.sets.filter { $0.exerciseID == "dumbbellBicepCurl" }.map(\.setNumber)
        XCTAssertEqual(curlSetNumbers, [1])

        guard case .summary(let summary) = viewModel.phase else {
            XCTFail("expected .summary phase after finish()")
            return
        }
        XCTAssertEqual(summary.perceivedEffort, 7)
        XCTAssertEqual(Set(summary.exerciseNames), Set([squat.name, curl.name]))
    }

    func test_reset_returnsToIdleAndClearsDrafts() throws {
        let context = try makeInMemoryContext()
        let viewModel = WorkoutBuilderViewModel(modelContext: context)
        let squat = ExerciseCatalog.exercise(id: "barbellSquat")!

        viewModel.start()
        viewModel.addSet(exercise: squat, weightKg: 80, reps: 8)
        viewModel.reset()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertTrue(viewModel.draftSets.isEmpty)
    }

    func test_bodyweightExerciseIDs_containsExpectedThreeExercises() {
        XCTAssertEqual(WorkoutBuilderViewModel.bodyweightExerciseIDs, Set(["pullUp", "pushUp", "crunch"]))
    }
}
