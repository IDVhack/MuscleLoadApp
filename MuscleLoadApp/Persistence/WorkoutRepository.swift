import Foundation
import SwiftData
import MuscleLoadCore

enum WorkoutRepositoryError: Error, Equatable {
    case exerciseInUse
    case unknownMovementPattern
}

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
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        return exercise(from: record)
    }

    /// Rehydrates a `CustomExerciseRecord` into `MuscleLoadCore.Exercise`,
    /// resolving its movement pattern from the fixed catalog. Returns nil if
    /// the record references a pattern id no longer in `MovementPatternCatalog`.
    private func exercise(from record: CustomExerciseRecord) -> Exercise? {
        guard let pattern = MovementPatternCatalog.pattern(id: record.movementPatternID) else {
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

    /// Every exercise available to the user — built-in catalog entries plus
    /// all persisted custom exercises — sorted by name so the directory and
    /// the workout-logging picker show one consistent, alphabetical list.
    func allExercises() throws -> [Exercise] {
        let customRecords = try modelContext.fetch(FetchDescriptor<CustomExerciseRecord>())
        let customExercises = customRecords.compactMap(exercise(from:))
        return (ExerciseCatalog.all + customExercises).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Creates and persists a new custom exercise. `movementPatternID` must
    /// be one of `MovementPatternCatalog.all` — the create form only offers
    /// those ids, but this is validated defensively at the repository
    /// boundary rather than trusted blindly.
    func createCustomExercise(name: String, movementPatternID: String, techniqueDescription: String?) throws -> Exercise {
        guard MovementPatternCatalog.pattern(id: movementPatternID) != nil else {
            throw WorkoutRepositoryError.unknownMovementPattern
        }
        let record = CustomExerciseRecord(
            name: name,
            movementPatternID: movementPatternID,
            techniqueDescription: techniqueDescription
        )
        modelContext.insert(record)
        try modelContext.save()
        return exercise(from: record)!
    }

    /// Updates an existing custom exercise in place. No-ops if `id` doesn't
    /// match any `CustomExerciseRecord` (e.g. a built-in id) — the edit form
    /// never calls this for built-in exercises, so no separate guard is
    /// surfaced to the caller.
    func updateCustomExercise(id: String, name: String, movementPatternID: String, techniqueDescription: String?) throws {
        guard MovementPatternCatalog.pattern(id: movementPatternID) != nil else {
            throw WorkoutRepositoryError.unknownMovementPattern
        }
        let targetID = id
        let descriptor = FetchDescriptor<CustomExerciseRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.name = name
        record.movementPatternID = movementPatternID
        record.techniqueDescription = techniqueDescription
        try modelContext.save()
    }

    /// Deletes a custom exercise, but refuses if any saved `SetEntryRecord`
    /// still references it — there is no workout-history screen yet to
    /// explain a set that silently lost its exercise.
    func deleteCustomExercise(id: String) throws {
        let targetID = id
        var usageDescriptor = FetchDescriptor<SetEntryRecord>(
            predicate: #Predicate { $0.exerciseID == targetID }
        )
        usageDescriptor.fetchLimit = 1
        guard try modelContext.fetch(usageDescriptor).isEmpty else {
            throw WorkoutRepositoryError.exerciseInUse
        }

        let recordDescriptor = FetchDescriptor<CustomExerciseRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let record = try modelContext.fetch(recordDescriptor).first else { return }
        modelContext.delete(record)
        try modelContext.save()
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

    /// Returns the single app-wide user profile, creating an empty one on
    /// first use. There is exactly one profile record; nothing else in this
    /// app inserts a `UserProfileRecord`.
    func fetchOrCreateProfile() throws -> UserProfileRecord {
        var descriptor = FetchDescriptor<UserProfileRecord>()
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfileRecord()
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }
}
