import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Тренировка сохранена")
                .font(.title2)
                .bold()
            Text(formattedDuration)
            Text("Усилие: \(summary.perceivedEffort)/10")
            Text(summary.exerciseNames.joined(separator: ", "))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Готово", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var formattedDuration: String {
        let minutes = Int(summary.duration) / 60
        return "\(minutes) мин"
    }
}
