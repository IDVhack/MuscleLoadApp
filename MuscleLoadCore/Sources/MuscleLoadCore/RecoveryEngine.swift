import Foundation

public enum RecoveryStatus: Equatable, Sendable {
    case early
    case soon
    case ready
}

public struct MuscleRecoveryStatus: Equatable, Sendable {
    public let muscleGroup: MuscleGroup
    public let recoveryPercent: Double
    public let status: RecoveryStatus

    public init(muscleGroup: MuscleGroup, recoveryPercent: Double, status: RecoveryStatus) {
        self.muscleGroup = muscleGroup
        self.recoveryPercent = recoveryPercent
        self.status = status
    }

    public static func == (lhs: MuscleRecoveryStatus, rhs: MuscleRecoveryStatus) -> Bool {
        lhs.muscleGroup == rhs.muscleGroup
            && abs(lhs.recoveryPercent - rhs.recoveryPercent) < 0.0001
            && lhs.status == rhs.status
    }
}

public struct RecoveryEngine: Sendable {
    public init() {}

    /// Momentary load (0...100%) each muscle receives from a single session,
    /// per spec section 4: primary muscles get full raw_load, secondary
    /// muscles get half.
    public func momentaryLoad(for session: WorkoutSession) -> [MuscleGroup: Double] {
        var rawContribution: [MuscleGroup: Double] = [:]

        for set in session.sets {
            let pattern = set.exercise.movementPattern
            for muscle in pattern.primaryMuscles {
                rawContribution[muscle, default: 0] += set.rawLoad * 1.0
            }
            for muscle in pattern.secondaryMuscles {
                rawContribution[muscle, default: 0] += set.rawLoad * 0.5
            }
        }

        var result: [MuscleGroup: Double] = [:]
        for (muscle, raw) in rawContribution {
            result[muscle] = min(100, raw / muscle.fullLoadThreshold * 100)
        }
        return result
    }

    /// Recovery status for every muscle group as of `date`, given past
    /// sessions. Each session's momentary load decays linearly to 0 over
    /// the muscle's fixed recovery window (spec section 4); overlapping
    /// sessions stack, capped at 100% current load. Sessions in the future
    /// relative to `date` are ignored.
    public func recoveryStatus(asOf date: Date, sessions: [WorkoutSession]) -> [MuscleRecoveryStatus] {
        var currentLoad: [MuscleGroup: Double] = [:]

        for session in sessions {
            let hoursElapsed = date.timeIntervalSince(session.date) / 3600
            guard hoursElapsed >= 0 else { continue }

            for (muscle, momentary) in momentaryLoad(for: session) {
                let window = muscle.recoveryWindowHours
                guard hoursElapsed < window else { continue }
                let remainingFraction = 1 - (hoursElapsed / window)
                currentLoad[muscle, default: 0] += momentary * remainingFraction
            }
        }

        return MuscleGroup.allCases.map { muscle in
            let load = min(100, currentLoad[muscle] ?? 0)
            let recoveryPercent = 100 - load
            let status: RecoveryStatus
            switch recoveryPercent {
            case ..<40: status = .early
            case 40..<85: status = .soon
            default: status = .ready
            }
            return MuscleRecoveryStatus(muscleGroup: muscle, recoveryPercent: recoveryPercent, status: status)
        }
    }
}
