import Foundation
import SwiftData

@Model
final class WorkoutSessionRecord {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var perceivedEffort: Int?

    @Relationship(deleteRule: .cascade, inverse: \SetEntryRecord.session)
    var sets: [SetEntryRecord]

    init(
        id: UUID = UUID(),
        date: Date,
        duration: TimeInterval,
        perceivedEffort: Int? = nil,
        sets: [SetEntryRecord] = []
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.perceivedEffort = perceivedEffort
        self.sets = sets
    }
}
