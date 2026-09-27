import Foundation
import MuscleLoadCore

@Observable
final class ExerciseDirectoryViewModel {
    private(set) var allExercises: [Exercise] = []
    var searchText: String = ""
    var selectedMuscle: MuscleGroup?

    private let repository: WorkoutRepository

    init(repository: WorkoutRepository) {
        self.repository = repository
    }

    func load() {
        allExercises = (try? repository.allExercises()) ?? []
    }

    var filteredExercises: [Exercise] {
        allExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesMuscle = selectedMuscle.map { exercise.movementPattern.primaryMuscles.contains($0) } ?? true
            return matchesSearch && matchesMuscle
        }
    }
}
