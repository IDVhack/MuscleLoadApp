import SwiftUI
import SwiftData
import MuscleLoadCore

struct SetEntrySheet: View {
    let exercise: Exercise
    let modelContext: ModelContext
    let onSave: (Double, Int) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var showingBodyweightPrompt = false
    @State private var bodyweightInput: String = ""

    private var isBodyweightExercise: Bool {
        WorkoutBuilderViewModel.bodyweightExerciseIDs.contains(exercise.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(exercise.name) {
                    TextField("Вес, кг", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("Повторы", text: $repsText)
                        .keyboardType(.numberPad)
                }
                Button("Сохранить подход") {
                    let weight = parseDecimal(weightText) ?? 0
                    let reps = Int(repsText) ?? 0
                    onSave(weight, reps)
                }
                .disabled((Int(repsText) ?? 0) <= 0)
            }
            .navigationTitle("Подход")
        }
        .onAppear(perform: prefillIfNeeded)
        .alert("Вес тела", isPresented: $showingBodyweightPrompt) {
            TextField("Кг", text: $bodyweightInput)
                .keyboardType(.decimalPad)
            Button("Сохранить", action: saveBodyweight)
        } message: {
            Text("Укажите свой вес — он используется для упражнений на своём весе")
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private func prefillIfNeeded() {
        guard isBodyweightExercise else { return }
        let repository = WorkoutRepository(modelContext: modelContext)
        guard let profile = try? repository.fetchOrCreateProfile() else { return }
        if let bodyweightKg = profile.bodyweightKg {
            weightText = formatWeight(bodyweightKg)
        } else {
            showingBodyweightPrompt = true
        }
    }

    private func saveBodyweight() {
        guard let value = parseDecimal(bodyweightInput) else { return }
        let repository = WorkoutRepository(modelContext: modelContext)
        guard let profile = try? repository.fetchOrCreateProfile() else { return }
        profile.bodyweightKg = value
        try? modelContext.save()
        weightText = formatWeight(value)
    }
}
