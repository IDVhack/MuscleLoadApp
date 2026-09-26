import Foundation
import SwiftData

@Model
final class SetEntryRecord {
    var id: UUID
    var exerciseID: String
    var weightKg: Double
    var reps: Int
    var setNumber: Int
    var session: WorkoutSessionRecord?

    init(
        id: UUID = UUID(),
        exerciseID: String,
        weightKg: Double,
        reps: Int,
        setNumber: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.weightKg = weightKg
        self.reps = reps
        self.setNumber = setNumber
    }
}
