# Exercise Directory (Plan B3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the third tab of the app — a searchable/filterable exercise directory covering both the 23 built-in exercises (now with pictures and technique text) and user-created custom exercises (create/edit/delete), and wire custom exercises into the workout-logging picker so they can actually be trained.

**Architecture:** One new feature module (`ExerciseDirectory`) under `MuscleLoadApp/Features/`, following the `@Observable` ViewModel + SwiftUI views pattern from Plan B2, built on `WorkoutRepository` extensions. `MuscleLoadCore` gains no new types — a custom exercise is still just a name attached to an existing `MovementPatternCatalog` entry, so `RecoveryEngine` needs zero changes.

**Tech Stack:** Swift 5.10, SwiftUI (`@Observable`, iOS 17+ APIs), SwiftData, XCTest, GitHub Actions (`macos-14` for the app, `ubuntu-latest` for `MuscleLoadCore`).

**Spec:** [docs/superpowers/specs/2026-09-27-exercise-directory-design.md](../specs/2026-09-27-exercise-directory-design.md)

## Global Constraints

- No Mac, no Xcode, no local Swift toolchain — every task's verification happens by pushing and checking the real GitHub Actions run in a browser (`MuscleLoadApp CI` on `macos-14`, or `MuscleLoadCore CI` on `ubuntu-latest` for `MuscleLoadCore`-only changes), never by trusting a report.
- `WorkoutRepository` remains the only type that imports both `SwiftData` and `MuscleLoadCore` — extend it rather than adding a second bridge type. Built-in and custom exercises are merged there into one `[Exercise]`; no view touches `CustomExerciseRecord` or SwiftData fetch/predicate logic directly.
- Custom exercises get no photo in this plan — `imageAssetName` stays `nil` for every `CustomExerciseRecord`. Only the 23 built-in exercises get pictures, from the pre-made PNGs already in `image/exercises/`.
- The muscle filter in the directory is single-select and matches only `movementPattern.primaryMuscles` (not secondary muscles, not multi-select).
- Deleting a custom exercise that is referenced by any saved `SetEntryRecord` is **blocked** (throws `WorkoutRepositoryError.exerciseInUse`), not silently allowed — there is no workout-history screen yet (Plan B4) to explain a silently vanished set.
- No duplicate-name validation on custom exercises, and no muscle-grouping in the movement-pattern picker (flat list of the 20 `MovementPatternCatalog.all` entries, sorted by name) — explicit v1 simplifications.
- Movement pattern selection in the create/edit form always comes from `MovementPatternCatalog.all`, never free text — `WorkoutRepository.createCustomExercise`/`updateCustomExercise` still validate the id defensively and throw `WorkoutRepositoryError.unknownMovementPattern` if it's ever wrong.

## Verifying a task

Same process as Plan B1/B2: commit, `git push`, open `https://github.com/IDVhack/MuscleLoadApp/actions`, find the run for your commit (match by subject — get the real numeric run ID from the link's `href`, never from the commit SHA), wait for it to finish, confirm Success. A task that only touches `MuscleLoadCore/` needs only `MuscleLoadCore CI` (ubuntu-latest, ~1 minute) green; a task that touches `MuscleLoadApp/` needs `MuscleLoadApp CI` (macos-14, several minutes) green. If a run fails, read the annotation (visible without signing in) for the actual error.

---

## Task 1: WorkoutRepository custom-exercise CRUD

**Files:**
- Modify: `MuscleLoadApp/Persistence/WorkoutRepository.swift`
- Modify: `MuscleLoadAppTests/WorkoutRepositoryTests.swift`

**Interfaces:**
- Consumes: `CustomExerciseRecord`, `SetEntryRecord` (Plan B1), `ExerciseCatalog.exercise(id:)`, `MovementPatternCatalog.pattern(id:)`, `Exercise` (all `MuscleLoadCore`)
- Produces: `WorkoutRepositoryError: Error, Equatable` (`.exerciseInUse`, `.unknownMovementPattern`), `WorkoutRepository.allExercises() throws -> [Exercise]`, `WorkoutRepository.createCustomExercise(name:movementPatternID:techniqueDescription:) throws -> Exercise`, `WorkoutRepository.updateCustomExercise(id:name:movementPatternID:techniqueDescription:) throws`, `WorkoutRepository.deleteCustomExercise(id:) throws` — all consumed by Task 4's `ExerciseDirectoryViewModel`, Task 5's views, and Task 6's `ExercisePickerView`.

- [ ] **Step 1: Write the failing tests**

Append to `MuscleLoadAppTests/WorkoutRepositoryTests.swift` (inside the existing `WorkoutRepositoryTests` class, before the final closing `}`):

```swift
    func test_allExercises_includesBuiltInAndCustomSortedByName() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(id: "myCurl", name: "Аааа мой подъём", movementPatternID: "bicepCurl")
        context.insert(custom)
        try context.save()
        let repository = WorkoutRepository(modelContext: context)

        let exercises = try repository.allExercises()

        XCTAssertEqual(exercises.count, 24)
        XCTAssertEqual(exercises.first?.id, "myCurl")
    }

    func test_createCustomExercise_persistsAndReturnsExercise() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let created = try repository.createCustomExercise(
            name: "Мой присед",
            movementPatternID: "squat",
            techniqueDescription: "Описание"
        )

        XCTAssertEqual(created.name, "Мой присед")
        XCTAssertEqual(created.movementPattern.id, "squat")
        XCTAssertFalse(created.isBuiltIn)

        let stored = try context.fetch(FetchDescriptor<CustomExerciseRecord>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, created.id)
    }

    func test_createCustomExercise_throwsForUnknownMovementPattern() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        XCTAssertThrowsError(
            try repository.createCustomExercise(name: "X", movementPatternID: "doesNotExist", techniqueDescription: nil)
        ) { error in
            XCTAssertEqual(error as? WorkoutRepositoryError, .unknownMovementPattern)
        }
    }

    func test_updateCustomExercise_changesFields() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        let created = try repository.createCustomExercise(name: "Старое имя", movementPatternID: "squat", techniqueDescription: nil)

        try repository.updateCustomExercise(id: created.id, name: "Новое имя", movementPatternID: "bicepCurl", techniqueDescription: "Новая техника")

        let updated = try repository.resolveExercise(id: created.id)
        XCTAssertEqual(updated?.name, "Новое имя")
        XCTAssertEqual(updated?.movementPattern.id, "bicepCurl")
        XCTAssertEqual(updated?.techniqueDescription, "Новая техника")
    }

    func test_updateCustomExercise_doesNothingForBuiltInID() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        try repository.updateCustomExercise(id: "barbellSquat", name: "Hacked", movementPatternID: "bicepCurl", techniqueDescription: nil)

        let stillBuiltIn = try repository.resolveExercise(id: "barbellSquat")
        XCTAssertEqual(stillBuiltIn?.name, "Приседания со штангой")
    }

    func test_deleteCustomExercise_removesUnusedExercise() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        let created = try repository.createCustomExercise(name: "Удали меня", movementPatternID: "squat", techniqueDescription: nil)

        try repository.deleteCustomExercise(id: created.id)

        XCTAssertNil(try repository.resolveExercise(id: created.id))
    }

    func test_deleteCustomExercise_throwsWhenExerciseIsUsedInASession() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        let created = try repository.createCustomExercise(name: "Используется", movementPatternID: "squat", techniqueDescription: nil)

        let session = WorkoutSessionRecord(date: .now, duration: 1800)
        let set = SetEntryRecord(exerciseID: created.id, weightKg: 50, reps: 10, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)
        try context.save()

        XCTAssertThrowsError(try repository.deleteCustomExercise(id: created.id)) { error in
            XCTAssertEqual(error as? WorkoutRepositoryError, .exerciseInUse)
        }
        XCTAssertNotNil(try repository.resolveExercise(id: created.id))
    }
```

- [ ] **Step 2: Implement the repository changes**

In `MuscleLoadApp/Persistence/WorkoutRepository.swift`, replace the existing `resolveExercise` method with a version that reuses a new private helper, and add the new methods. Replace this block:

```swift
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
```

with:

```swift
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
        return (ExerciseCatalog.all + customExercises).sorted { $0.name < $1.name }
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
```

Then add, near the top of the file (after the imports, before `struct WorkoutRepository`):

```swift
enum WorkoutRepositoryError: Error, Equatable {
    case exerciseInUse
    case unknownMovementPattern
}
```

- [ ] **Step 3: Commit, push, verify CI green**

```bash
git add MuscleLoadApp/Persistence/WorkoutRepository.swift MuscleLoadAppTests/WorkoutRepositoryTests.swift
git commit -m "$(cat <<'EOF'
Add custom-exercise CRUD to WorkoutRepository

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 2: Built-in exercise images and technique text (MuscleLoadCore)

**Files:**
- Modify: `MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift`
- Modify: `MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift`

**Interfaces:**
- Consumes: `Exercise` (existing `imageAssetName`/`techniqueDescription` fields, currently unused)
- Produces: every `ExerciseCatalog.all` entry now has `imageAssetName` equal to its own `id`, and a non-empty `techniqueDescription` — consumed by Task 3 (asset filenames must match these ids) and Task 5's `ExerciseDetailView`.

- [ ] **Step 1: Write the failing test**

In `MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift`, replace:

```swift
    func test_imageAndTechniqueDefaultToNil() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }
        XCTAssertNil(squat?.imageAssetName)
        XCTAssertNil(squat?.techniqueDescription)
    }
```

with:

```swift
    func test_allBuiltInExercises_haveImageAssetNameMatchingID() {
        XCTAssertTrue(ExerciseCatalog.all.allSatisfy { $0.imageAssetName == $0.id })
    }

    func test_allBuiltInExercises_haveNonEmptyTechniqueDescription() {
        XCTAssertTrue(ExerciseCatalog.all.allSatisfy { !($0.techniqueDescription?.isEmpty ?? true) })
    }
```

- [ ] **Step 2: Implement the catalog changes**

Replace the full contents of `MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift` with:

```swift
public enum ExerciseCatalog {
    public static let all: [Exercise] = [
        Exercise(id: "barbellSquat", name: "Приседания со штангой", movementPattern: MovementPatternCatalog.squat, isBuiltIn: true, techniqueDescription: "Со штангой на плечах присядьте до параллели бёдер с полом, сохраняя спину прямой, затем поднимитесь в исходное положение.", imageAssetName: "barbellSquat"),
        Exercise(id: "pullUp", name: "Подтягивания", movementPattern: MovementPatternCatalog.verticalPullBodyweight, isBuiltIn: true, techniqueDescription: "Возьмитесь за перекладину прямым хватом и подтянитесь, пока подбородок не окажется над перекладиной, затем плавно опуститесь.", imageAssetName: "pullUp"),
        Exercise(id: "romanianDeadlift", name: "Румынская тяга", movementPattern: MovementPatternCatalog.hipHinge, isBuiltIn: true, techniqueDescription: "Со штангой в прямых руках наклонитесь вперёд от бёдер, чуть сгибая колени, пока не почувствуете растяжение задней поверхности бедра, затем вернитесь в исходное положение.", imageAssetName: "romanianDeadlift"),
        Exercise(id: "gluteBridge", name: "Ягодичный мост", movementPattern: MovementPatternCatalog.hipExtension, isBuiltIn: true, techniqueDescription: "Лёжа на спине с согнутыми коленями поднимите таз вверх, напрягая ягодицы, затем плавно опустите.", imageAssetName: "gluteBridge"),
        Exercise(id: "legPress", name: "Жим ногами", movementPattern: MovementPatternCatalog.squatMachine, isBuiltIn: true, techniqueDescription: "Сидя в тренажёре, согните колени до угла 90 градусов и выжмите платформу вверх, не разгибая колени полностью.", imageAssetName: "legPress"),
        Exercise(id: "lyingLegCurl", name: "Сгибание ног лёжа", movementPattern: MovementPatternCatalog.legCurl, isBuiltIn: true, techniqueDescription: "Лёжа на животе, согните ноги в коленях, подводя валик тренажёра к ягодицам, затем плавно вернитесь в исходное положение.", imageAssetName: "lyingLegCurl"),
        Exercise(id: "cableHipAbduction", name: "Отведение ноги в кроссовере", movementPattern: MovementPatternCatalog.hipAbduction, isBuiltIn: true, techniqueDescription: "Стоя боком к блоку с манжетой на щиколотке, отведите прямую ногу в сторону, затем плавно верните обратно.", imageAssetName: "cableHipAbduction"),
        Exercise(id: "seatedHipAbduction", name: "Разводка ног сидя", movementPattern: MovementPatternCatalog.hipAbduction, isBuiltIn: true, techniqueDescription: "Сидя в тренажёре с упорами на внешней стороне бёдер, разведите колени в стороны против сопротивления, затем плавно сведите обратно.", imageAssetName: "seatedHipAbduction"),
        Exercise(id: "pushUp", name: "Отжимания", movementPattern: MovementPatternCatalog.horizontalPress, isBuiltIn: true, techniqueDescription: "В упоре лёжа согните руки, опуская грудь к полу, затем выжмите тело вверх, сохраняя корпус прямым.", imageAssetName: "pushUp"),
        Exercise(id: "crunch", name: "Пресс", movementPattern: MovementPatternCatalog.crunch, isBuiltIn: true, techniqueDescription: "Лёжа на спине с согнутыми коленями оторвите лопатки от пола, скручиваясь к тазу, затем плавно вернитесь.", imageAssetName: "crunch"),
        Exercise(id: "wideGripLatPulldown", name: "Вертикальная тяга (широкий хват)", movementPattern: MovementPatternCatalog.verticalPullCable, isBuiltIn: true, techniqueDescription: "Сидя в тренажёре, широким хватом потяните рукоять вниз к верху груди, затем плавно верните вес наверх.", imageAssetName: "wideGripLatPulldown"),
        Exercise(id: "closeGripLatPulldown", name: "Вертикальная тяга (узкий хват)", movementPattern: MovementPatternCatalog.verticalPullCable, isBuiltIn: true, techniqueDescription: "Сидя в тренажёре, узким хватом потяните рукоять вниз к груди, сводя лопатки, затем плавно верните вес наверх.", imageAssetName: "closeGripLatPulldown"),
        Exercise(id: "seatedCableRow", name: "Горизонтальная тяга", movementPattern: MovementPatternCatalog.horizontalPull, isBuiltIn: true, techniqueDescription: "Сидя у блока с прямой спиной потяните рукоять к животу, сводя лопатки, затем плавно верните вес вперёд.", imageAssetName: "seatedCableRow"),
        Exercise(id: "pullover", name: "Пуловер", movementPattern: MovementPatternCatalog.pullover, isBuiltIn: true, techniqueDescription: "В кроссовере или с гантелью прямыми руками опустите вес назад за голову, затем верните его над грудью.", imageAssetName: "pullover"),
        Exercise(id: "dumbbellBicepCurl", name: "Подъём гантелей на бицепс", movementPattern: MovementPatternCatalog.bicepCurl, isBuiltIn: true, techniqueDescription: "Стоя с гантелями в опущенных руках, согните руки в локтях, поднимая гантели к плечам, затем плавно опустите.", imageAssetName: "dumbbellBicepCurl"),
        Exercise(id: "seatedDumbbellPress", name: "Жим гантелей сидя", movementPattern: MovementPatternCatalog.overheadPressSeated, isBuiltIn: true, techniqueDescription: "Сидя с гантелями на уровне плеч, выжмите их вверх над головой, затем плавно опустите обратно.", imageAssetName: "seatedDumbbellPress"),
        Exercise(id: "cableTricepPushdown", name: "Разгибание рук (верхний блок)", movementPattern: MovementPatternCatalog.tricepExtensionCable, isBuiltIn: true, techniqueDescription: "Стоя у верхнего блока, разогните руки в локтях, отжимая рукоять вниз, затем плавно вернитесь в исходное положение.", imageAssetName: "cableTricepPushdown"),
        Exercise(id: "skullCrusher", name: "Французский жим", movementPattern: MovementPatternCatalog.tricepExtensionLying, isBuiltIn: true, techniqueDescription: "Лёжа со штангой или гантелями над грудью, согните руки в локтях, опуская вес ко лбу, затем разогните руки обратно.", imageAssetName: "skullCrusher"),
        Exercise(id: "standingLateralRaise", name: "Разведение гантелей стоя", movementPattern: MovementPatternCatalog.lateralRaise, isBuiltIn: true, techniqueDescription: "Стоя с гантелями по бокам, поднимите прямые руки в стороны до уровня плеч, затем плавно опустите.", imageAssetName: "standingLateralRaise"),
        Exercise(id: "standingDumbbellPress", name: "Жим гантелей стоя", movementPattern: MovementPatternCatalog.overheadPressStanding, isBuiltIn: true, techniqueDescription: "Стоя с гантелями на уровне плеч, выжмите их вверх над головой, не прогибаясь в пояснице, затем опустите обратно.", imageAssetName: "standingDumbbellPress"),
        Exercise(id: "reverseMachineFly", name: "Обратные разведения в тренажёре", movementPattern: MovementPatternCatalog.lateralRaise, isBuiltIn: true, techniqueDescription: "Сидя лицом к тренажёру, разведите руки в стороны и назад, сводя лопатки, затем плавно верните рукояти вперёд.", imageAssetName: "reverseMachineFly"),
        Exercise(id: "hyperextension", name: "Гиперэкстензия", movementPattern: MovementPatternCatalog.backExtension, isBuiltIn: true, techniqueDescription: "Лёжа животом на тренажёре с зафиксированными ногами, опустите корпус вниз, затем поднимите его до прямой линии с бёдрами.", imageAssetName: "hyperextension"),
        Exercise(id: "bulgarianSplitSquat", name: "Болгарские выпады", movementPattern: MovementPatternCatalog.lunge, isBuiltIn: true, techniqueDescription: "Поставив одну ногу на возвышение сзади, присядьте на опорной ноге до параллели бедра с полом, затем вернитесь в исходное положение.", imageAssetName: "bulgarianSplitSquat")
    ]

    public static func exercise(id: String) -> Exercise? {
        all.first { $0.id == id }
    }
}
```

- [ ] **Step 3: Commit, push, verify `MuscleLoadCore CI` green**

```bash
git add MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift
git commit -m "$(cat <<'EOF'
Add technique descriptions and image asset names to ExerciseCatalog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 3: Assets.xcassets for built-in exercise images

**Files:**
- Create: `MuscleLoadApp/App/Assets.xcassets/Contents.json`
- Create: `MuscleLoadApp/App/Assets.xcassets/<id>.imageset/Contents.json` (23 files, one per exercise id from Task 2)
- Create: `MuscleLoadApp/App/Assets.xcassets/<id>.imageset/<id>.png` (23 files, copied from `image/exercises/`)

**Interfaces:**
- Consumes: the 23 `id`s from `ExerciseCatalog.all` (Task 2), the 23 source PNGs already present in `image/exercises/` (untracked reference folder, not part of this task's commit)
- Produces: an asset catalog where `Image("<id>")` resolves for every built-in exercise id — consumed by Task 5's `ExerciseDetailView`.

XcodeGen picks up any `.xcassets` folder inside an existing `sources:` path as a resource automatically — `MuscleLoadApp/App` is already listed in `project.yml`, so no `project.yml` change is needed for this task.

- [ ] **Step 1: Generate the asset catalog from the source images**

Run from the repo root:

```bash
set -euo pipefail
mkdir -p MuscleLoadApp/App/Assets.xcassets
cat > MuscleLoadApp/App/Assets.xcassets/Contents.json <<'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

MAP=(
  "barbellSquat:01_prisedaniya_so_shtangoy.png"
  "pullUp:02_podtyagivaniya.png"
  "romanianDeadlift:03_rumynskaya_tyaga.png"
  "gluteBridge:04_yagodichniy_most.png"
  "legPress:05_zhim_nogami.png"
  "lyingLegCurl:06_sgibanie_nog_lezha.png"
  "cableHipAbduction:07_otvedenie_nogi_v_krossovere.png"
  "seatedHipAbduction:08_razvodka_nog_sidya.png"
  "pushUp:09_otzhimaniya.png"
  "crunch:10_press.png"
  "wideGripLatPulldown:11_vertikalnaya_tyaga_shirokiy_hvat.png"
  "closeGripLatPulldown:12_vertikalnaya_tyaga_uzkiy_hvat.png"
  "seatedCableRow:13_gorizontalnaya_tyaga.png"
  "pullover:14_pulover.png"
  "dumbbellBicepCurl:15_podyom_ganteley_na_bicheps.png"
  "seatedDumbbellPress:16_zhim_ganteley_sidya.png"
  "cableTricepPushdown:17_razgibanie_ruk_verhniy_blok.png"
  "skullCrusher:18_frantsuzskiy_zhim.png"
  "standingLateralRaise:19_razvedenie_ganteley_stoya.png"
  "standingDumbbellPress:20_zhim_ganteley_stoya.png"
  "reverseMachineFly:21_obratnie_razvedeniya_v_trenazhere.png"
  "hyperextension:22_giperekstenziya.png"
  "bulgarianSplitSquat:23_bolgarskie_vypady.png"
)

for entry in "${MAP[@]}"; do
  id="${entry%%:*}"
  file="${entry#*:}"
  dir="MuscleLoadApp/App/Assets.xcassets/${id}.imageset"
  mkdir -p "$dir"
  cp "image/exercises/${file}" "${dir}/${id}.png"
  cat > "${dir}/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "${id}.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
done
```

- [ ] **Step 2: Verify all 23 imagesets were created**

```bash
find MuscleLoadApp/App/Assets.xcassets -maxdepth 1 -name "*.imageset" | wc -l
```

Expected output: `23`.

- [ ] **Step 3: Commit, push, verify `MuscleLoadApp CI` green**

```bash
git add MuscleLoadApp/App/Assets.xcassets
git commit -m "$(cat <<'EOF'
Add Assets.xcassets with pictures for built-in exercises

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

Confirm the archive/build steps of `MuscleLoadApp CI` still succeed with the new asset catalog present (a malformed `Contents.json` would fail the build at the asset-compile step).

---

## Task 4: ExerciseDirectoryViewModel

**Files:**
- Create: `MuscleLoadApp/Features/ExerciseDirectory/ExerciseDirectoryViewModel.swift`
- Create: `MuscleLoadAppTests/ExerciseDirectoryViewModelTests.swift`

**Interfaces:**
- Consumes: `WorkoutRepository.allExercises()`, `WorkoutRepository.createCustomExercise(...)` (Task 1), `Exercise`, `MuscleGroup` (`MuscleLoadCore`)
- Produces: `ExerciseDirectoryViewModel` with `allExercises: [Exercise]` (read-only), `searchText: String`, `selectedMuscle: MuscleGroup?`, `filteredExercises: [Exercise]` (computed), `load()` — consumed by Task 5's `ExerciseDirectoryView`.

- [ ] **Step 1: Write the failing tests**

`MuscleLoadAppTests/ExerciseDirectoryViewModelTests.swift`:

```swift
import XCTest
import SwiftData
import MuscleLoadCore
@testable import MuscleLoadApp

final class ExerciseDirectoryViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            WorkoutSessionRecord.self,
            SetEntryRecord.self,
            CustomExerciseRecord.self,
            UserProfileRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func test_load_populatesAllExercises() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))

        viewModel.load()

        XCTAssertEqual(viewModel.allExercises.count, 23)
    }

    func test_filteredExercises_withSearchText_matchesNameSubstring() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.searchText = "присед"

        XCTAssertTrue(viewModel.filteredExercises.allSatisfy { $0.name.localizedCaseInsensitiveContains("присед") })
        XCTAssertTrue(viewModel.filteredExercises.contains { $0.id == "barbellSquat" })
    }

    func test_filteredExercises_withSelectedMuscle_matchesPrimaryMuscleOnly() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.selectedMuscle = .biceps

        XCTAssertTrue(viewModel.filteredExercises.allSatisfy { $0.movementPattern.primaryMuscles.contains(.biceps) })
        XCTAssertTrue(viewModel.filteredExercises.contains { $0.id == "dumbbellBicepCurl" })
        XCTAssertFalse(viewModel.filteredExercises.contains { $0.id == "barbellSquat" })
    }

    func test_filteredExercises_combinesSearchAndMuscleFilter() throws {
        let context = try makeInMemoryContext()
        let viewModel = ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: context))
        viewModel.load()

        viewModel.searchText = "жим"
        viewModel.selectedMuscle = .shoulders

        XCTAssertTrue(viewModel.filteredExercises.contains { $0.id == "seatedDumbbellPress" })
        XCTAssertFalse(viewModel.filteredExercises.contains { $0.id == "legPress" })
    }

    func test_filteredExercises_includesCustomExercise() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)
        _ = try repository.createCustomExercise(name: "Моё упражнение", movementPatternID: "bicepCurl", techniqueDescription: nil)
        let viewModel = ExerciseDirectoryViewModel(repository: repository)

        viewModel.load()

        XCTAssertTrue(viewModel.filteredExercises.contains { $0.name == "Моё упражнение" && !$0.isBuiltIn })
    }
}
```

- [ ] **Step 2: Implement `ExerciseDirectoryViewModel`**

`MuscleLoadApp/Features/ExerciseDirectory/ExerciseDirectoryViewModel.swift`:

```swift
import Foundation
import MuscleLoadCore

@Observable
final class ExerciseDirectoryViewModel {
    private(set) var allExercises: [Exercise] = []
    var searchText: String = ""
    var selectedMuscle: MuscleGroup?

    private let repository: WorkoutRepository

    init(repository: WorkoutRepository) {
        self.repository = repository
    }

    func load() {
        allExercises = (try? repository.allExercises()) ?? []
    }

    var filteredExercises: [Exercise] {
        allExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesMuscle = selectedMuscle.map { exercise.movementPattern.primaryMuscles.contains($0) } ?? true
            return matchesSearch && matchesMuscle
        }
    }
}
```

- [ ] **Step 3: Commit, push, verify CI green**

```bash
git add MuscleLoadApp/Features/ExerciseDirectory/ExerciseDirectoryViewModel.swift MuscleLoadAppTests/ExerciseDirectoryViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add ExerciseDirectoryViewModel with search and muscle filtering

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 5: ExerciseDirectory views (list, detail, create/edit form)

**Files:**
- Create: `MuscleLoadApp/Features/ExerciseDirectory/ExerciseDirectoryView.swift`
- Create: `MuscleLoadApp/Features/ExerciseDirectory/ExerciseDetailView.swift`
- Create: `MuscleLoadApp/Features/ExerciseDirectory/ExerciseFormView.swift`

**Interfaces:**
- Consumes: `ExerciseDirectoryViewModel` (Task 4); `WorkoutRepository.createCustomExercise`/`updateCustomExercise`/`deleteCustomExercise`, `WorkoutRepositoryError` (Task 1); `MovementPatternCatalog.all`, `MuscleGroup.displayName`, `Exercise` (`MuscleLoadCore`); built-in image assets (Task 3)
- Produces: `ExerciseDirectoryView` (init takes a `ModelContext`) — consumed by Task 7's `RootTabView`.

These three files form one interdependent screen flow (list → detail → edit, list → create) and are grouped in one task because no one file is independently reviewable without the others.

- [ ] **Step 1: Implement `ExerciseFormView`**

`MuscleLoadApp/Features/ExerciseDirectory/ExerciseFormView.swift`:

```swift
import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExerciseFormView: View {
    let modelContext: ModelContext
    let existingExercise: Exercise?
    let onSaved: () -> Void

    @State private var name: String
    @State private var movementPatternID: String
    @State private var techniqueDescription: String
    @Environment(\.dismiss) private var dismiss

    init(modelContext: ModelContext, existingExercise: Exercise?, onSaved: @escaping () -> Void) {
        self.modelContext = modelContext
        self.existingExercise = existingExercise
        self.onSaved = onSaved
        _name = State(initialValue: existingExercise?.name ?? "")
        _movementPatternID = State(initialValue: existingExercise?.movementPattern.id ?? MovementPatternCatalog.all[0].id)
        _techniqueDescription = State(initialValue: existingExercise?.techniqueDescription ?? "")
    }

    private var sortedPatterns: [MovementPattern] {
        MovementPatternCatalog.all.sorted { $0.name < $1.name }
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Название упражнения", text: $name)
                }
                Section("Шаблон движения") {
                    Picker("Шаблон", selection: $movementPatternID) {
                        ForEach(sortedPatterns) { pattern in
                            Text(pattern.name).tag(pattern.id)
                        }
                    }
                }
                Section("Техника (необязательно)") {
                    TextField("Описание техники", text: $techniqueDescription, axis: .vertical)
                }
            }
            .navigationTitle(existingExercise == nil ? "Новое упражнение" : "Изменить упражнение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!isNameValid)
                }
            }
        }
    }

    private func save() {
        let repository = WorkoutRepository(modelContext: modelContext)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTechnique = techniqueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let technique = trimmedTechnique.isEmpty ? nil : trimmedTechnique

        if let existingExercise {
            try? repository.updateCustomExercise(
                id: existingExercise.id,
                name: trimmedName,
                movementPatternID: movementPatternID,
                techniqueDescription: technique
            )
        } else {
            _ = try? repository.createCustomExercise(
                name: trimmedName,
                movementPatternID: movementPatternID,
                techniqueDescription: technique
            )
        }
        onSaved()
        dismiss()
    }
}
```

- [ ] **Step 2: Implement `ExerciseDetailView`**

`MuscleLoadApp/Features/ExerciseDirectory/ExerciseDetailView.swift`:

```swift
import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExerciseDetailView: View {
    let exercise: Exercise
    let modelContext: ModelContext
    let onChange: () -> Void

    @State private var showingEditForm = false
    @State private var showingInUseAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                if let imageAssetName = exercise.imageAssetName {
                    Image(imageAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            Section("Основные мышцы") {
                ForEach(exercise.movementPattern.primaryMuscles, id: \.self) { muscle in
                    Text(muscle.displayName)
                }
            }
            if !exercise.movementPattern.secondaryMuscles.isEmpty {
                Section("Вторичные мышцы") {
                    ForEach(exercise.movementPattern.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle.displayName)
                    }
                }
            }
            if let technique = exercise.techniqueDescription {
                Section("Техника") {
                    Text(technique)
                }
            }
        }
        .navigationTitle(exercise.name)
        .toolbar {
            if !exercise.isBuiltIn {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Изменить") { showingEditForm = true }
                        Button("Удалить", role: .destructive) { delete() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            ExerciseFormView(modelContext: modelContext, existingExercise: exercise) {
                onChange()
                dismiss()
            }
        }
        .alert("Нельзя удалить", isPresented: $showingInUseAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("Упражнение используется в сохранённой тренировке и не может быть удалено.")
        }
    }

    private func delete() {
        let repository = WorkoutRepository(modelContext: modelContext)
        do {
            try repository.deleteCustomExercise(id: exercise.id)
            onChange()
            dismiss()
        } catch {
            showingInUseAlert = true
        }
    }
}
```

`ExerciseDetailView` holds `exercise` as an immutable snapshot, so after a successful edit it dismisses itself back to the (now-refreshed) list rather than trying to reactively re-render stale data in place.

- [ ] **Step 3: Implement `ExerciseDirectoryView`**

`MuscleLoadApp/Features/ExerciseDirectory/ExerciseDirectoryView.swift`:

```swift
import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExerciseDirectoryView: View {
    @State private var viewModel: ExerciseDirectoryViewModel
    private let modelContext: ModelContext

    @State private var showingCreateForm = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = State(initialValue: ExerciseDirectoryViewModel(repository: WorkoutRepository(modelContext: modelContext)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    muscleFilterPicker
                }
                ForEach(viewModel.filteredExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise, modelContext: modelContext, onChange: { viewModel.load() })
                    } label: {
                        HStack {
                            Text(exercise.name)
                            if !exercise.isBuiltIn {
                                Spacer()
                                Text("своё")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText)
            .navigationTitle("Упражнения")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateForm) {
                ExerciseFormView(modelContext: modelContext, existingExercise: nil) {
                    viewModel.load()
                }
            }
            .onAppear { viewModel.load() }
        }
    }

    private var muscleFilterPicker: some View {
        Picker("Мышца", selection: $viewModel.selectedMuscle) {
            Text("Все").tag(MuscleGroup?.none)
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                Text(muscle.displayName).tag(MuscleGroup?.some(muscle))
            }
        }
    }
}
```

No dedicated unit tests for these three views — they're SwiftUI views with no logic beyond what `ExerciseDirectoryViewModelTests` and `WorkoutRepositoryTests` already cover. Correctness is verified by the app target building successfully in CI.

- [ ] **Step 4: Commit, push, verify CI green**

```bash
git add MuscleLoadApp/Features/ExerciseDirectory/ExerciseFormView.swift MuscleLoadApp/Features/ExerciseDirectory/ExerciseDetailView.swift MuscleLoadApp/Features/ExerciseDirectory/ExerciseDirectoryView.swift
git commit -m "$(cat <<'EOF'
Add ExerciseDirectory screen flow: list, detail, create/edit form

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 6: Wire custom exercises into the workout-logging picker

**Files:**
- Modify: `MuscleLoadApp/Features/WorkoutBuilder/ExercisePickerView.swift`

**Interfaces:**
- Consumes: `WorkoutRepository.allExercises()` (Task 1)
- Produces: no change to `ExercisePickerView`'s own public interface (still `ExercisePickerView(modelContext:onPick:)`) — internally now shows custom exercises alongside built-in ones.

- [ ] **Step 1: Update `ExercisePickerView` to load from the repository**

Replace the full contents of `MuscleLoadApp/Features/WorkoutBuilder/ExercisePickerView.swift` with:

```swift
import SwiftUI
import SwiftData
import MuscleLoadCore

struct ExercisePickerView: View {
    let modelContext: ModelContext
    let onPick: (Exercise, Double, Int) -> Void

    @State private var searchText = ""
    @State private var selectedExercise: Exercise?
    @State private var exercises: [Exercise] = []
    @Environment(\.dismiss) private var dismiss

    private var filteredExercises: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises, id: \.id) { exercise in
                Button(exercise.name) { selectedExercise = exercise }
                    .foregroundStyle(.primary)
            }
            .searchable(text: $searchText)
            .navigationTitle("Упражнение")
            .onAppear {
                exercises = (try? WorkoutRepository(modelContext: modelContext).allExercises()) ?? []
            }
            .sheet(item: $selectedExercise) { exercise in
                SetEntrySheet(exercise: exercise, modelContext: modelContext) { weight, reps in
                    onPick(exercise, weight, reps)
                    selectedExercise = nil
                    dismiss()
                }
            }
        }
    }
}
```

No dedicated unit test — this view had none before either (its search/list behavior over `[Exercise]` is unchanged; only the source of the array changed, and `allExercises()` is already covered by `WorkoutRepositoryTests`). Verified via CI build.

- [ ] **Step 2: Commit, push, verify CI green**

```bash
git add MuscleLoadApp/Features/WorkoutBuilder/ExercisePickerView.swift
git commit -m "$(cat <<'EOF'
Include custom exercises in the workout-logging exercise picker

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 7: Wire RootTabView

**Files:**
- Modify: `MuscleLoadApp/Navigation/RootTabView.swift`

**Interfaces:**
- Consumes: `ExerciseDirectoryView` (Task 5)
- Produces: the third tab is now real — nothing later in this plan depends on it, it's the integration point.

- [ ] **Step 1: Replace the placeholder tab**

Replace the contents of `MuscleLoadApp/Navigation/RootTabView.swift`:

```swift
import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RecoveryView(
                repository: WorkoutRepository(modelContext: modelContext),
                onStartWorkout: { selectedTab = 1 }
            )
            .tabItem { Label("Главная", systemImage: "heart.text.square") }
            .tag(0)

            WorkoutBuilderView(modelContext: modelContext)
                .tabItem { Label("Тренировки", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            ExerciseDirectoryView(modelContext: modelContext)
                .tabItem { Label("Упражнения", systemImage: "list.bullet") }
                .tag(2)
        }
    }
}
```

No dedicated unit test for this step — pure view wiring, no new logic. Correctness is verified by the app target building successfully in CI, and by the fact that `ExerciseDirectoryViewModelTests` / `WorkoutRepositoryTests` already cover everything this view calls.

- [ ] **Step 2: Commit, push, verify CI green**

```bash
git add MuscleLoadApp/Navigation/RootTabView.swift
git commit -m "$(cat <<'EOF'
Wire ExerciseDirectoryView into RootTabView

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Self-Review

**Spec coverage:** Design doc §3 (merge + CRUD + `WorkoutRepositoryError`) → Task 1. §4 (ViewModel, directory/detail views, single-select primary-muscle filter, create/edit form, blocked deletion) → Tasks 4-5. §5 (built-in images + authored technique text, no photo for custom exercises) → Tasks 2-3. §6 (picker integration) → Task 6. §7 (`RootTabView`) → Task 7. §8 (out of scope: custom-exercise photos, secondary-muscle/multi-select filtering, duplicate-name validation, pattern grouping, history/stats/notifications) → correctly absent from every task, and reflected in this plan's Global Constraints. §9 (testing) → Tasks 1 and 4 carry the dedicated tests; Tasks 2, 3, 5, 6, 7 explicitly note CI-build-only verification, matching the spec.

**Placeholder scan:** no TBD/TODO. All 23 `ExerciseCatalog` entries in Task 2 have real, complete technique text and matching asset names, not stand-ins.

**Type consistency:** `WorkoutRepository.allExercises()/createCustomExercise(...)/updateCustomExercise(...)/deleteCustomExercise(...)` and `WorkoutRepositoryError` (Task 1) are used with identical names and signatures in `ExerciseDirectoryViewModel` (Task 4), `ExerciseFormView`/`ExerciseDetailView` (Task 5), and `ExercisePickerView` (Task 6). `ExerciseDirectoryViewModel.allExercises`/`filteredExercises`/`searchText`/`selectedMuscle`/`load()` (Task 4) are used identically in `ExerciseDirectoryView` (Task 5). Asset names produced in Task 2 (`imageAssetName == id`) match the imageset names created in Task 3 and the lookup in `ExerciseDetailView` (Task 5). `ExerciseDirectoryView(modelContext:)` (Task 5) matches its call site in `RootTabView` (Task 7).
