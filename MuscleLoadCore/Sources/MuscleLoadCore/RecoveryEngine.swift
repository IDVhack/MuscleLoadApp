import Foundation

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
}
