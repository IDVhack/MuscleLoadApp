public struct MovementPattern: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let primaryMuscles: [MuscleGroup]
    public let secondaryMuscles: [MuscleGroup]
    public let heavinessCoefficient: Double

    public init(
        id: String,
        name: String,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        heavinessCoefficient: Double
    ) {
        self.id = id
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.heavinessCoefficient = heavinessCoefficient
    }
}
