import SwiftUI

struct FinishWorkoutView: View {
    let onFinish: (Int) -> Void

    @State private var effort: Double = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Усилие (1–10)") {
                    Slider(value: $effort, in: 1...10, step: 1)
                    Text("\(Int(effort))")
                }
                Button("Сохранить тренировку") {
                    onFinish(Int(effort))
                }
            }
            .navigationTitle("Завершить")
        }
    }
}
