import XCTest
import SwiftData
import MuscleLoadCore
@testable import MuscleLoadApp

final class ExerciseDirectoryViewModelTests: XCTestCase {
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

    func test_load_populatesAllExercises() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))

        viewModel.load()

        XCTAssertEqual(viewModel.allExercises.count, 23)
    }

    func test_filteredExercises_withSearchText_matchesNameSubstring() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.searchText = "присед"

        XCTAssertTrue(viewModel.filteredExercises.allSatisfy { $0.name.localizedCaseInsensitiveContains("присед") })
        XCTAssertTrue(viewModel.filteredExercises.contains { $0.id == "barbellSquat" })
    }

    func test_filteredExercises_withSelectedMuscle_matchesPrimaryMuscleOnly() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.selectedMuscle = .biceps

        XCTAssertTrue(viewModel.filteredExercises.allSatisfy { $0.movementPattern.primaryMuscles.contains(.biceps) })
        XCTAssertTrue(viewModel.filteredExercises.contains { $0.id == "dumbbellBicepCurl" })
        XCTAssertFalse(viewModel.filteredExercises.contains { $0.id == "barbellSquat" })
    }

    func test_filteredExercises_combinesSearchAndMuscleFilter() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.searchText = "жим"
        viewModel.selectedMuscle = .shoulders

        XCTAssertTrue(viewModel.filteredExercises.contains { $0.id == "seatedDumbbellPress" })
        XCTAssertFalse(viewModel.filteredExercises.contains { $0.id == "legPress" })
    }

    func test_filteredExercises_withNoMatchingSearchText_isEmpty() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.searchText = "zzz-no-such-exercise-zzz"

        XCTAssertTrue(viewModel.filteredExercises.isEmpty)
    }

    func test_filteredExercises_includesCustomExercise() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        _ = try repository.createCustomExercise(name: "Моё упражнение", movementPatternID: "bicepCurl", techniqueDescription: nil)
        let viewModel = ExerciseDirectoryViewModel(repository: repository)

        viewModel.load()

        XCTAssertTrue(viewModel.filteredExercises.contains { $0.name == "Моё упражнение" && !$0.isBuiltIn })
    }
}
