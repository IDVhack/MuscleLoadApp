import Foundation

public struct WorkoutSession: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let sets: [SetEntry]
    public let perceivedEffort: Int?

    public init(id: UUID = UUID(), date: Date, sets: [SetEntry], perceivedEffort: Int? = nil) {
        self.id = id
        self.date = date
        self.sets = sets
        self.perceivedEffort = perceivedEffort
    }
}
