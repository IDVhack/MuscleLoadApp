import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Text("Главная")
                .tabItem { Label("Главная", systemImage: "heart.text.square") }

            Text("Тренировки")
                .tabItem { Label("Тренировки", systemImage: "figure.strengthtraining.traditional") }

            Text("Упражнения")
                .tabItem { Label("Упражнения", systemImage: "list.bullet") }
        }
    }
}
