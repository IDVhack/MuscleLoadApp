import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExerciseFormView: View {
    let modelContext: ModelContext
    let existingExercise: Exercise?
    let onSaved: () -> Void

    @State private var name: String
    @State private var movementPatternID: String
    @State private var techniqueDescription: String
    @Environment(\.dismiss) private var dismiss

    init(modelContext: ModelContext, existingExercise: Exercise?, onSaved: @escaping () -> Void) {
        self.modelContext = modelContext
        self.existingExercise = existingExercise
        self.onSaved = onSaved
        _name = State(initialValue: existingExercise?.name ?? "")
        _movementPatternID = State(initialValue: existingExercise?.movementPattern.id ?? MovementPatternCatalog.all[0].id)
        _techniqueDescription = State(initialValue: existingExercise?.techniqueDescription ?? "")
    }

    private var sortedPatterns: [MovementPattern] {
        MovementPatternCatalog.all.sorted { $0.name < $1.name }
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Название упражнения", text: $name)
                }
                Section("Шаблон движения") {
                    Picker("Шаблон", selection: $movementPatternID) {
                        ForEach(sortedPatterns) { pattern in
                            Text(pattern.name).tag(pattern.id)
                        }
                    }
                }
                Section("Техника (необязательно)") {
                    TextField("Описание техники", text: $techniqueDescription, axis: .vertical)
                }
            }
            .navigationTitle(existingExercise == nil ? "Новое упражнение" : "Изменить упражнение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!isNameValid)
                }
            }
        }
    }

    private func save() {
        let repository = WorkoutRepository(modelContext: modelContext)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTechnique = techniqueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let technique = trimmedTechnique.isEmpty ? nil : trimmedTechnique

        if let existingExercise {
            try? repository.updateCustomExercise(
                id: existingExercise.id,
                name: trimmedName,
                movementPatternID: movementPatternID,
                techniqueDescription: technique
            )
        } else {
            _ = try? repository.createCustomExercise(
                name: trimmedName,
                movementPatternID: movementPatternID,
                techniqueDescription: technique
            )
        }
        onSaved()
        dismiss()
    }
}
