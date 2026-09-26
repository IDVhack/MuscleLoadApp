import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExercisePickerView: View {
    let modelContext: ModelContext
    let onPick: (Exercise, Double, Int) -> Void

    @State private var searchText = ""
    @State private var selectedExercise: Exercise?
    @Environment(\.dismiss) private var dismiss

    private var filteredExercises: [Exercise] {
        guard !searchText.isEmpty else { return ExerciseCatalog.all }
        return ExerciseCatalog.all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises, id: \.id) { exercise in
                Button(exercise.name) { selectedExercise = exercise }
                    .foregroundStyle(.primary)
            }
            .searchable(text: $searchText)
            .navigationTitle("Упражнение")
            .sheet(item: $selectedExercise) { exercise in
                SetEntrySheet(exercise: exercise, modelContext: modelContext) { weight, reps in
                    onPick(exercise, weight, reps)
                    selectedExercise = nil
                    dismiss()
                }
            }
        }
    }
}
