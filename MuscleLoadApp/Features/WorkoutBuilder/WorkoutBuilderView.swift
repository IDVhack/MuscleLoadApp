import SwiftUI
import SwiftData

struct WorkoutBuilderView: View {
    @State private var viewModel: WorkoutBuilderViewModel
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = State(initialValue: WorkoutBuilderViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Тренировки")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            ContentUnavailableView(
                "Нет активной тренировки",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("Нажмите «Начать тренировку», чтобы начать")
            )
            .safeAreaInset(edge: .bottom) {
                Button("Начать тренировку") { viewModel.start() }
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        case .active:
            ActiveWorkoutView(viewModel: viewModel, modelContext: modelContext)
        case .summary(let summary):
            WorkoutSummaryView(summary: summary, onDone: { viewModel.reset() })
        }
    }
}
