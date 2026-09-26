import SwiftUI
import SwiftData

@main
struct MuscleLoadAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            WorkoutSessionRecord.self,
            SetEntryRecord.self,
            CustomExerciseRecord.self,
            UserProfileRecord.self
        ])
    }
}
