import Foundation

public struct SetEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let exercise: Exercise
    public let weightKg: Double
    public let reps: Int
    public let setNumber: Int

    public init(id: UUID = UUID(), exercise: Exercise, weightKg: Double, reps: Int, setNumber: Int) {
        self.id = id
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.setNumber = setNumber
    }

    /// raw_load = вес × повторы × heaviness_coefficient, per spec section 4.
    public var rawLoad: Double {
        weightKg * Double(reps) * exercise.movementPattern.heavinessCoefficient
    }
}
