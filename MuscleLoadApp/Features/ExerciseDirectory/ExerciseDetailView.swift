import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExerciseDetailView: View {
    let exercise: Exercise
    let modelContext: ModelContext
    let onChange: () -> Void

    @State private var showingEditForm = false
    @State private var showingInUseAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                if let imageAssetName = exercise.imageAssetName {
                    Image(imageAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            Section("Основные мышцы") {
                ForEach(exercise.movementPattern.primaryMuscles, id: \.self) { muscle in
                    Text(muscle.displayName)
                }
            }
            if !exercise.movementPattern.secondaryMuscles.isEmpty {
                Section("Вторичные мышцы") {
                    ForEach(exercise.movementPattern.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                    }
                }
            }
            if let technique = exercise.techniqueDescription {
                Section("Техника") {
                    Text(technique)
                }
            }
        }
        .navigationTitle(exercise.name)
        .toolbar {
            if !exercise.isBuiltIn {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Изменить") { showingEditForm = true }
                        Button("Удалить", role: .destructive) { delete() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            ExerciseFormView(modelContext: modelContext, existingExercise: exercise) {
                onChange()
                dismiss()
            }
        }
        .alert("Нельзя удалить", isPresented: $showingInUseAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("Упражнение используется в сохранённой тренировке и не может быть удалено.")
        }
    }

    private func delete() {
        let repository = WorkoutRepository(modelContext: modelContext)
        do {
            try repository.deleteCustomExercise(id: exercise.id)
            onChange()
            dismiss()
        } catch {
            showingInUseAlert = true
        }
    }
}
