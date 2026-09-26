import Foundation
import SwiftData
import MuscleLoadCore

struct WorkoutRepository {
    let modelContext: ModelContext

    /// Resolves an exercise id to its `MuscleLoadCore.Exercise` value —
    /// built-in exercises come from `ExerciseCatalog`, custom ones are
    /// rehydrated from `CustomExerciseRecord` through the pattern catalog.
    func resolveExercise(id: String) throws -> Exercise? {
        if let builtIn = ExerciseCatalog.exercise(id: id) {
            return builtIn
        }

        let targetID = id
        let descriptor = FetchDescriptor<CustomExerciseRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard
            let record = try modelContext.fetch(descriptor).first,
            let pattern = MovementPatternCatalog.pattern(id: record.movementPatternID)
        else {
            return nil
        }

        return Exercise(
            id: record.id,
            name: record.name,
            movementPattern: pattern,
            isBuiltIn: false,
            techniqueDescription: record.techniqueDescription,
            imageAssetName: record.imageAssetName
        )
    }

    /// Loads every persisted workout session, rehydrates it into
    /// `MuscleLoadCore` value types, and runs `RecoveryEngine` over them.
    /// Sets whose exercise can no longer be resolved are dropped rather
    /// than failing the whole calculation.
    func currentRecoveryStatuses(asOf date: Date) throws -> [MuscleRecoveryStatus] {
        let descriptor = FetchDescriptor<WorkoutSessionRecord>()
        let records = try modelContext.fetch(descriptor)

        let sessions: [WorkoutSession] = try records.map { record in
            let sets: [SetEntry] = try record.sets.compactMap { setRecord in
                guard let exercise = try resolveExercise(id: setRecord.exerciseID) else { return nil }
                return SetEntry(
                    id: setRecord.id,
                    exercise: exercise,
                    weightKg: setRecord.weightKg,
                    reps: setRecord.reps,
                    setNumber: setRecord.setNumber
                )
            }
            return WorkoutSession(
                id: record.id,
                date: record.date,
                sets: sets,
                perceivedEffort: record.perceivedEffort
            )
        }

        return RecoveryEngine().recoveryStatus(asOf: date, sessions: sessions)
    }
}
