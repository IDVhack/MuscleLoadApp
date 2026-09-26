import Foundation
import MuscleLoadCore

@Observable
final class RecoveryViewModel {
    private(set) var statuses: [MuscleRecoveryStatus] = []
    private let repository: WorkoutRepository

    init(repository: WorkoutRepository) {
        self.repository = repository
    }

    /// Loads recovery status for every muscle group as of `date`, sorted with
    /// the least-recovered muscles first so the dashboard leads with what
    /// needs attention.
    func load(asOf date: Date = .now) {
        guard let result = try? repository.currentRecoveryStatuses(asOf: date) else {
            statuses = []
            return
        }
        statuses = result.sorted { $0.recoveryPercent < $1.recoveryPercent }
    }

    /// A short recommendation driven by the single worst-off muscle group —
    /// simpler and just as actionable as a "majority of muscles" heuristic,
    /// and much easier to reason about (one muscle's status, not a count).
    var recommendationText: String {
        guard let worst = statuses.first else { return "" }
        switch worst.status {
        case .early:
            return "Есть мышцы, которым нужен отдых — тренируйте то, что готово, или отдохните"
        case .soon:
            return "Некоторые мышцы почти восстановились — лёгкая тренировка подойдёт"
        case .ready:
            return "Все мышцы готовы к тренировке"
        }
    }
}
