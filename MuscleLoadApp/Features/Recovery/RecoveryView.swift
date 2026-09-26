import SwiftUI
import MuscleLoadCore

struct RecoveryView: View {
    @State private var viewModel: RecoveryViewModel
    private let onStartWorkout: () -> Void

    init(repository: WorkoutRepository, onStartWorkout: @escaping () -> Void) {
        _viewModel = State(initialValue: RecoveryViewModel(repository: repository))
        self.onStartWorkout = onStartWorkout
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.recommendationText.isEmpty {
                    Section {
                        Text(viewModel.recommendationText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Мышцы") {
                    ForEach(viewModel.statuses, id: \.muscleGroup) { status in
                        MuscleRecoveryRow(status: status)
                    }
                }
            }
            .navigationTitle("Главная")
            .safeAreaInset(edge: .bottom) {
                Button(action: onStartWorkout) {
                    Text("Начать тренировку")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .onAppear { viewModel.load() }
        }
    }
}

struct MuscleRecoveryRow: View {
    let status: MuscleRecoveryStatus

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(status.muscleGroup.displayName)
            Spacer()
            Text("\(Int(status.recoveryPercent))%")
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch status.status {
        case .early: return .red
        case .soon: return .yellow
        case .ready: return .green
        }
    }
}
