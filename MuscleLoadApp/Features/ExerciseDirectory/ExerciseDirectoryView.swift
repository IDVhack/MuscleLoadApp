import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExerciseDirectoryView: View {
    @State private var viewModel: ExerciseDirectoryViewModel
    private let modelContext: ModelContext

    @State private var showingCreateForm = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = State(initialValue: ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: modelContext)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    muscleFilterPicker
                }
                ForEach(viewModel.filteredExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise, modelContext: modelContext, onChange: { viewModel.load() })
                    } label: {
                        HStack {
                            Text(exercise.name)
                            if !exercise.isBuiltIn {
                                Spacer()
                                Text("своё")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText)
            .navigationTitle("Упражнения")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateForm) {
                ExerciseFormView(modelContext: modelContext, existingExercise: nil) {
                    viewModel.load()
                }
            }
            .onAppear { viewModel.load() }
        }
    }

    private var muscleFilterPicker: some View {
        Picker("Мышца", selection: $viewModel.selectedMuscle) {
            Text("Все").tag(MuscleGroup?.none)
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                Text(muscle.displayName).tag(MuscleGroup?.some(muscle))
            }
        }
    }
}
