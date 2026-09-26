import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let viewModel: WorkoutBuilderViewModel
    let modelContext: ModelContext

    @State private var showingExercisePicker = false
    @State private var showingFinishSheet = false

    var body: some View {
        List {
            ForEach(viewModel.draftSets) { draft in
                HStack {
                    Text(draft.exercise.name)
                    Spacer()
                    Text("\(Int(draft.weightKg)) кг × \(draft.reps)")
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.removeSet(id: viewModel.draftSets[index].id)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Завершить") { showingFinishSheet = true }
                    .disabled(viewModel.draftSets.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Добавить упражнение") { showingExercisePicker = true }
                .buttonStyle(.bordered)
                .padding()
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(modelContext: modelContext) { exercise, weight, reps in
                viewModel.addSet(exercise: exercise, weightKg: weight, reps: reps)
            }
        }
        .sheet(isPresented: $showingFinishSheet) {
            FinishWorkoutView { effort in
                viewModel.finish(perceivedEffort: effort)
                showingFinishSheet = false
            }
        }
    }
}
