import Foundation
import SwiftData
import MuscleLoadCore

struct WorkoutDraftSet: Identifiable {
    let id: UUID
    let exercise: Exercise
    let weightKg: Double
    let reps: Int

    init(id: UUID = UUID(), exercise: Exercise, weightKg: Double, reps: Int) {
        self.id = id
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
    }
}

struct WorkoutSummary: Equatable {
    let duration: TimeInterval
    let exerciseNames: [String]
    let perceivedEffort: Int
}

enum WorkoutBuilderPhase: Equatable {
    case idle
    case active
    case summary(WorkoutSummary)
}

@Observable
final class WorkoutBuilderViewModel {
    private(set) var phase: WorkoutBuilderPhase = .idle
    private(set) var draftSets: [WorkoutDraftSet] = []
    private var startDate: Date?

    private let modelContext: ModelContext

    /// Exercises with no natural added weight — their weight field is
    /// prefilled from the user's bodyweight instead of starting at 0.
    /// MuscleLoadCore never knows about this distinction; it lives here.
    static let bodyweightExerciseIDs: Set<String> = ["pullUp", "pushUp", "crunch"]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func start() {
        startDate = .now
        draftSets = []
        phase = .active
    }

    func addSet(exercise: Exercise, weightKg: Double, reps: Int) {
        draftSets.append(WorkoutDraftSet(exercise: exercise, weightKg: weightKg, reps: reps))
    }

    func removeSet(id: UUID) {
        draftSets.removeAll { $0.id == id }
    }

    /// Persists the draft as a WorkoutSessionRecord with one SetEntryRecord
    /// per draft set, numbering sets per exercise (not globally), then moves
    /// to the summary phase.
    func finish(perceivedEffort: Int) {
        guard phase == .active, let startDate else { return }
        let duration = Date().timeIntervalSince(startDate)

        let session = WorkoutSessionRecord(date: startDate, duration: duration, perceivedEffort: perceivedEffort)
        modelContext.insert(session)

        var setNumberByExercise: [String: Int] = [:]
        var records: [SetEntryRecord] = []
        for draft in draftSets {
            setNumberByExercise[draft.exercise.id, default: 0] += 1
            let record = SetEntryRecord(
                exerciseID: draft.exercise.id,
                weightKg: draft.weightKg,
                reps: draft.reps,
                setNumber: setNumberByExercise[draft.exercise.id]!
            )
            record.session = session
            modelContext.insert(record)
            records.append(record)
        }
        session.sets = records
        try? modelContext.save()

        let exerciseNames = Array(Set(draftSets.map { $0.exercise.name })).sorted()
        phase = .summary(WorkoutSummary(duration: duration, exerciseNames: exerciseNames, perceivedEffort: perceivedEffort))
    }

    func reset() {
        phase = .idle
        draftSets = []
        startDate = nil
    }
}
