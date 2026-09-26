import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RecoveryView(
                repository: WorkoutRepository(modelContext: modelContext),
                onStartWorkout: { selectedTab = 1 }
            )
            .tabItem { Label("Главная", systemImage: "heart.text.square") }
            .tag(0)

            WorkoutBuilderView(modelContext: modelContext)
                .tabItem { Label("Тренировки", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            Text("Упражнения")
                .tabItem { Label("Упражнения", systemImage: "list.bullet") }
                .tag(2)
        }
    }
}
