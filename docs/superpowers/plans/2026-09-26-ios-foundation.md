# iOS App Foundation (Plan B1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a buildable, testable SwiftUI iOS app shell (XcodeGen project, SwiftData persistence layer, 3-tab navigation placeholder) on top of the already-shipped `MuscleLoadCore` package, verified entirely through GitHub Actions since this machine has no Mac.

**Architecture:** `MuscleLoadCore` gains two small additive lookup functions. A new `project.yml` (XcodeGen) generates an `.xcodeproj` in CI — never committed — for a `MuscleLoadApp` target (SwiftUI, SwiftData) and a `MuscleLoadAppTests` target. A `WorkoutRepository` is the single bridge between SwiftData records (which store IDs, not embedded values) and `MuscleLoadCore`'s pure value types.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, XcodeGen, XCTest, GitHub Actions (`macos-14` for the app, `ubuntu-latest` for MuscleLoadCore — unchanged from Plan A).

**Spec:** [docs/superpowers/specs/2026-09-26-ios-foundation-design.md](../specs/2026-09-26-ios-foundation-design.md)

## Global Constraints

- No Mac, no Xcode, no local Swift toolchain on this machine — every task's verification happens by pushing and checking the real GitHub Actions run in a browser, never by trusting a report.
- `.xcodeproj` is never created or committed by hand — it's generated in CI from `project.yml` via `xcodegen generate`.
- iOS 17+, SwiftUI, SwiftData only, local storage only — no network, no accounts (per app spec).
- `MuscleLoadCore`'s existing public API (from Plan A) must not change signature — only additive functions are allowed, and they must keep passing the existing `ubuntu-latest` CI pipeline at `MuscleLoadCore/`.
- `SetEntryRecord` stores `exerciseID: String`, never an embedded `Exercise` value — so a future coefficient recalibration in the catalog applies retroactively to old workouts (design doc §5).
- `WorkoutSessionRecord.duration` lives in this app-layer record, not in `MuscleLoadCore.WorkoutSession` — the engine doesn't need it, the summary screen (Plan B2) will (design doc §5).
- Bodyweight handling (`pullUp`/`pushUp`/`crunch` defaulting to the user's bodyweight) is entirely an app-layer concern (a hardcoded `Set<String>`) — `MuscleLoadCore` never changes for this (design doc §6).
- Built-in exercises are never duplicated into SwiftData — only user-created ones (`CustomExerciseRecord`) are persisted; built-ins are resolved from `ExerciseCatalog.all` at read time.

## Verifying a task

- **Tasks touching `MuscleLoadCore/`** (Task 1 only): commit, `git push`, then open `https://github.com/IDVhack/MuscleLoadApp/actions`, find the run for your commit (match by subject — get the real numeric run ID from the link's `href`, never from the commit SHA), wait for it to finish, confirm Success.
- **Tasks touching `MuscleLoadApp/`** (Tasks 2-5): same process, but the run appears under the `MuscleLoadApp CI` workflow (`macos-14`, slower — expect a few minutes, not seconds, since it boots an iOS Simulator).

---

## Task 1: MuscleLoadCore catalog lookup helpers

**Files:**
- Modify: `MuscleLoadCore/Sources/MuscleLoadCore/MovementPatternCatalog.swift`
- Modify: `MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift`
- Modify: `MuscleLoadCore/Tests/MuscleLoadCoreTests/MovementPatternCatalogTests.swift`
- Modify: `MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift`

**Interfaces:**
- Consumes: `MovementPatternCatalog.all: [MovementPattern]`, `ExerciseCatalog.all: [Exercise]` (already shipped in Plan A)
- Produces: `MovementPatternCatalog.pattern(id: String) -> MovementPattern?` and `ExerciseCatalog.exercise(id: String) -> Exercise?` — consumed by Task 4's `WorkoutRepository`.

- [ ] **Step 1: Write the failing tests**

Append to `MuscleLoadCore/Tests/MuscleLoadCoreTests/MovementPatternCatalogTests.swift`:

```swift
    func test_pattern_returnsMatchingPatternByID() {
        let squat = MovementPatternCatalog.pattern(id: "squat")
        XCTAssertEqual(squat?.id, "squat")
        XCTAssertEqual(squat?.heavinessCoefficient, 1.8)
    }

    func test_pattern_returnsNilForUnknownID() {
        XCTAssertNil(MovementPatternCatalog.pattern(id: "doesNotExist"))
    }
```

Append to `MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift`:

```swift
    func test_exercise_returnsMatchingExerciseByID() {
        let squat = ExerciseCatalog.exercise(id: "barbellSquat")
        XCTAssertEqual(squat?.name, "Приседания со штангой")
    }

    func test_exercise_returnsNilForUnknownID() {
        XCTAssertNil(ExerciseCatalog.exercise(id: "doesNotExist"))
    }
```

- [ ] **Step 2: Implement the lookups**

In `MuscleLoadCore/Sources/MuscleLoadCore/MovementPatternCatalog.swift`, add inside the `MovementPatternCatalog` enum (after the `all` array):

```swift

    public static func pattern(id: String) -> MovementPattern? {
        all.first { $0.id == id }
    }
```

In `MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift`, add inside the `ExerciseCatalog` enum (after the `all` array):

```swift

    public static func exercise(id: String) -> Exercise? {
        all.first { $0.id == id }
    }
```

- [ ] **Step 3: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add id-based lookups to MovementPatternCatalog and ExerciseCatalog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

Verify the `MuscleLoadCore CI` run for this commit is green (per "Verifying a task" above).

---

## Task 2: XcodeGen project scaffold and macOS CI

**Files:**
- Create: `project.yml`
- Create: `.github/workflows/app-ci.yml`
- Create: `MuscleLoadApp/App/MuscleLoadAppApp.swift`
- Create: `MuscleLoadApp/Navigation/RootTabView.swift`
- Create: `MuscleLoadAppTests/PipelineSanityTests.swift`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: a buildable, testable empty iOS app shell; a CI workflow proven to catch failures and report success — the foundation every later task's `xcodebuild test` run relies on.

- [ ] **Step 1: Add Xcode/XcodeGen build artifacts to `.gitignore`**

Append to `.gitignore`:

```
*.xcodeproj
xcuserdata/
```

- [ ] **Step 2: Create the XcodeGen project spec**

`project.yml`:

```yaml
name: MuscleLoadApp
options:
  bundleIdPrefix: com.muscleload
  deploymentTarget:
    iOS: "17.0"
packages:
  MuscleLoadCore:
    path: MuscleLoadCore
targets:
  MuscleLoadApp:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: MuscleLoadApp/App
      - path: MuscleLoadApp/Navigation
    dependencies:
      - package: MuscleLoadCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.muscleload.app
        PRODUCT_NAME: MuscleLoadApp
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_CFBundleDisplayName: MuscleLoad
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "5.10"
  MuscleLoadAppTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: MuscleLoadAppTests
    dependencies:
      - target: MuscleLoadApp
    settings:
      base:
        SWIFT_VERSION: "5.10"
schemes:
  MuscleLoadApp:
    build:
      targets:
        MuscleLoadApp: all
        MuscleLoadAppTests: [test]
    test:
      targets:
        - MuscleLoadAppTests
```

- [ ] **Step 3: Create the minimal app entry point**

`MuscleLoadApp/App/MuscleLoadAppApp.swift`:

```swift
import SwiftUI

@main
struct MuscleLoadAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
```

- [ ] **Step 4: Create the tab shell (placeholders only)**

`MuscleLoadApp/Navigation/RootTabView.swift`:

```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Text("Главная")
                .tabItem { Label("Главная", systemImage: "heart.text.square") }

            Text("Тренировки")
                .tabItem { Label("Тренировки", systemImage: "figure.strengthtraining.traditional") }

            Text("Упражнения")
                .tabItem { Label("Упражнения", systemImage: "list.bullet") }
        }
    }
}
```

- [ ] **Step 5: Write a deliberately failing sanity test**

`MuscleLoadAppTests/PipelineSanityTests.swift`:

```swift
import XCTest

final class PipelineSanityTests: XCTestCase {
    func test_ciPipelineCatchesFailures() {
        XCTAssertTrue(false, "this must fail until Step 7")
    }
}
```

- [ ] **Step 6: Create the CI workflow**

`.github/workflows/app-ci.yml`:

```yaml
name: MuscleLoadApp CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Run MuscleLoadApp tests
        run: |
          xcodebuild test \
            -project MuscleLoadApp.xcodeproj \
            -scheme MuscleLoadApp \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 7: Commit and push, verify CI goes RED**

```bash
git add project.yml .github MuscleLoadApp MuscleLoadAppTests .gitignore
git commit -m "$(cat <<'EOF'
Scaffold MuscleLoadApp XcodeGen project and macOS CI pipeline

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

Verify the `MuscleLoadApp CI` run for this commit finishes with a **failure** (the sanity test asserts `false`). This proves `xcodegen generate` → `xcodebuild test` → simulator boot → XCTest execution → result reporting all actually work end to end. If it shows green here, something in the pipeline is silently not running the test — fix before continuing.

- [ ] **Step 8: Fix the sanity test to pass**

Edit `MuscleLoadAppTests/PipelineSanityTests.swift`:

```swift
import XCTest

final class PipelineSanityTests: XCTestCase {
    func test_ciPipelineCatchesFailures() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 9: Commit, push, verify CI goes GREEN**

```bash
git add MuscleLoadAppTests/PipelineSanityTests.swift
git commit -m "$(cat <<'EOF'
Fix sanity test to confirm green macOS CI path

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

Confirm the new run is green. From this task onward, every task pushes test + implementation together in one commit.

---

## Task 3: SwiftData persistence models

**Files:**
- Modify: `project.yml` (add `MuscleLoadApp/Persistence` to `MuscleLoadApp` target's `sources`)
- Delete: `MuscleLoadAppTests/PipelineSanityTests.swift`
- Create: `MuscleLoadApp/Persistence/WorkoutSessionRecord.swift`
- Create: `MuscleLoadApp/Persistence/SetEntryRecord.swift`
- Create: `MuscleLoadApp/Persistence/CustomExerciseRecord.swift`
- Create: `MuscleLoadApp/Persistence/UserProfileRecord.swift`
- Create: `MuscleLoadAppTests/PersistenceModelTests.swift`

**Interfaces:**
- Consumes: nothing new
- Produces: four `@Model` classes — `WorkoutSessionRecord` (`id: UUID`, `date: Date`, `duration: TimeInterval`, `perceivedEffort: Int?`, `sets: [SetEntryRecord]`), `SetEntryRecord` (`id: UUID`, `exerciseID: String`, `weightKg: Double`, `reps: Int`, `setNumber: Int`, `session: WorkoutSessionRecord?`), `CustomExerciseRecord` (`id: String`, `name: String`, `movementPatternID: String`, `techniqueDescription: String?`, `imageAssetName: String?`), `UserProfileRecord` (`bodyweightKg: Double?`, `notificationsEnabled: Bool`) — consumed by Task 4's `WorkoutRepository`.

- [ ] **Step 1: Remove the placeholder sanity test**

```bash
git rm MuscleLoadAppTests/PipelineSanityTests.swift
```

- [ ] **Step 2: Add the Persistence source folder to the Xcode project**

In `project.yml`, under the `MuscleLoadApp` target's `sources`, add the new path so it reads:

```yaml
    sources:
      - path: MuscleLoadApp/App
      - path: MuscleLoadApp/Navigation
      - path: MuscleLoadApp/Persistence
```

- [ ] **Step 3: Write the model tests**

`MuscleLoadAppTests/PersistenceModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import MuscleLoadApp

final class PersistenceModelTests: XCTestCase {
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

    func test_workoutSessionRecord_persistsWithSets() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSessionRecord(date: .now, duration: 3600, perceivedEffort: 7)
        let set = SetEntryRecord(exerciseID: "barbellSquat", weightKg: 80, reps: 8, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)

        try context.save()

        let descriptor = FetchDescriptor<WorkoutSessionRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sets.count, 1)
        XCTAssertEqual(fetched.first?.sets.first?.exerciseID, "barbellSquat")
    }

    func test_customExerciseRecord_persists() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(name: "Моё упражнение", movementPatternID: "bicepCurl")
        context.insert(custom)
        try context.save()

        let descriptor = FetchDescriptor<CustomExerciseRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Моё упражнение")
        XCTAssertEqual(fetched.first?.movementPatternID, "bicepCurl")
    }

    func test_userProfileRecord_persistsWithDefaults() throws {
        let context = try makeInMemoryContext()
        let profile = UserProfileRecord()
        context.insert(profile)
        try context.save()

        let descriptor = FetchDescriptor<UserProfileRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched.first?.bodyweightKg)
        XCTAssertEqual(fetched.first?.notificationsEnabled, true)
    }
}
```

- [ ] **Step 4: Implement the four models**

`MuscleLoadApp/Persistence/WorkoutSessionRecord.swift`:

```swift
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
```

`MuscleLoadApp/Persistence/SetEntryRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SetEntryRecord {
    var id: UUID
    var exerciseID: String
    var weightKg: Double
    var reps: Int
    var setNumber: Int
    var session: WorkoutSessionRecord?

    init(
        id: UUID = UUID(),
        exerciseID: String,
        weightKg: Double,
        reps: Int,
        setNumber: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.weightKg = weightKg
        self.reps = reps
        self.setNumber = setNumber
    }
}
```

`MuscleLoadApp/Persistence/CustomExerciseRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CustomExerciseRecord {
    var id: String
    var name: String
    var movementPatternID: String
    var techniqueDescription: String?
    var imageAssetName: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        movementPatternID: String,
        techniqueDescription: String? = nil,
        imageAssetName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.movementPatternID = movementPatternID
        self.techniqueDescription = techniqueDescription
        self.imageAssetName = imageAssetName
    }
}
```

`MuscleLoadApp/Persistence/UserProfileRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class UserProfileRecord {
    var bodyweightKg: Double?
    var notificationsEnabled: Bool

    init(bodyweightKg: Double? = nil, notificationsEnabled: Bool = true) {
        self.bodyweightKg = bodyweightKg
        self.notificationsEnabled = notificationsEnabled
    }
}
```

- [ ] **Step 5: Commit, push, verify CI green**

```bash
git add project.yml MuscleLoadApp MuscleLoadAppTests
git commit -m "$(cat <<'EOF'
Add SwiftData persistence models for workouts, custom exercises, and profile

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 4: WorkoutRepository bridge to MuscleLoadCore

**Files:**
- Create: `MuscleLoadApp/Persistence/WorkoutRepository.swift`
- Create: `MuscleLoadAppTests/WorkoutRepositoryTests.swift`

**Interfaces:**
- Consumes: `WorkoutSessionRecord`, `SetEntryRecord`, `CustomExerciseRecord` (Task 3); `ExerciseCatalog.exercise(id:)`, `MovementPatternCatalog.pattern(id:)` (Task 1); `MuscleLoadCore.Exercise`, `SetEntry`, `WorkoutSession`, `RecoveryEngine`, `MuscleRecoveryStatus` (Plan A)
- Produces: `WorkoutRepository` with `resolveExercise(id: String) -> Exercise?` and `currentRecoveryStatuses(asOf: Date) throws -> [MuscleRecoveryStatus]` — this is what Plan B2's recovery-map screen calls directly.

- [ ] **Step 1: Write the repository tests**

`MuscleLoadAppTests/WorkoutRepositoryTests.swift`:

```swift
import XCTest
import SwiftData
import MuscleLoadCore
@testable import MuscleLoadApp

final class WorkoutRepositoryTests: XCTestCase {
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

    func test_resolveExercise_returnsBuiltInFromCatalog() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let exercise = repository.resolveExercise(id: "barbellSquat")

        XCTAssertEqual(exercise?.name, "Приседания со штангой")
        XCTAssertEqual(exercise?.movementPattern.id, "squat")
    }

    func test_resolveExercise_returnsCustomExerciseFromStore() throws {
        let context = try makeInMemoryContext()
        let custom = CustomExerciseRecord(id: "myCurl", name: "Мой подъём", movementPatternID: "bicepCurl")
        context.insert(custom)
        let repository = WorkoutRepository(modelContext: context)

        let exercise = repository.resolveExercise(id: "myCurl")

        XCTAssertEqual(exercise?.name, "Мой подъём")
        XCTAssertEqual(exercise?.movementPattern.id, "bicepCurl")
        XCTAssertFalse(exercise?.isBuiltIn ?? true)
    }

    func test_resolveExercise_returnsNilForUnknownID() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        XCTAssertNil(repository.resolveExercise(id: "doesNotExist"))
    }

    func test_currentRecoveryStatuses_reflectsPersistedSession() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSessionRecord(date: .now, duration: 3600)
        let set = SetEntryRecord(exerciseID: "barbellSquat", weightKg: 80, reps: 8, setNumber: 1)
        set.session = session
        session.sets = [set]
        context.insert(session)
        try context.save()

        let repository = WorkoutRepository(modelContext: context)
        let statuses = try repository.currentRecoveryStatuses(asOf: .now)

        XCTAssertEqual(statuses.count, 13)
        let quadriceps = statuses.first { $0.muscleGroup == .quadriceps }
        XCTAssertNotNil(quadriceps)
        XCTAssertLessThan(quadriceps!.recoveryPercent, 100)
    }

    func test_currentRecoveryStatuses_withNoSessions_isFullyRecovered() throws {
        let context = try makeInMemoryContext()
        let repository = WorkoutRepository(modelContext: context)

        let statuses = try repository.currentRecoveryStatuses(asOf: .now)

        XCTAssertEqual(statuses.count, 13)
        XCTAssertTrue(statuses.allSatisfy { $0.recoveryPercent == 100 })
    }
}
```

- [ ] **Step 2: Implement `WorkoutRepository`**

`MuscleLoadApp/Persistence/WorkoutRepository.swift`:

```swift
import Foundation
import SwiftData
import MuscleLoadCore

struct WorkoutRepository {
    let modelContext: ModelContext

    /// Resolves an exercise id to its `MuscleLoadCore.Exercise` value —
    /// built-in exercises come from `ExerciseCatalog`, custom ones are
    /// rehydrated from `CustomExerciseRecord` through the pattern catalog.
    func resolveExercise(id: String) -> Exercise? {
        if let builtIn = ExerciseCatalog.exercise(id: id) {
            return builtIn
        }

        let targetID = id
        let descriptor = FetchDescriptor<CustomExerciseRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard
            let record = try? modelContext.fetch(descriptor).first,
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

        let sessions: [WorkoutSession] = records.map { record in
            let sets: [SetEntry] = record.sets.compactMap { setRecord in
                guard let exercise = resolveExercise(id: setRecord.exerciseID) else { return nil }
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
```

- [ ] **Step 3: Commit, push, verify CI green**

```bash
git add MuscleLoadApp MuscleLoadAppTests
git commit -m "$(cat <<'EOF'
Add WorkoutRepository bridging SwiftData records to MuscleLoadCore

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 5: Wire SwiftData into the app entry point

**Files:**
- Modify: `MuscleLoadApp/App/MuscleLoadAppApp.swift`

**Interfaces:**
- Consumes: `WorkoutSessionRecord`, `SetEntryRecord`, `CustomExerciseRecord`, `UserProfileRecord` (Task 3)
- Produces: a running app with a real `ModelContainer` — the last thing Plan B2's screens need before they can start reading/writing data.

- [ ] **Step 1: Add the SwiftData model container to the app scene**

Replace the contents of `MuscleLoadApp/App/MuscleLoadAppApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct MuscleLoadAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            WorkoutSessionRecord.self,
            SetEntryRecord.self,
            CustomExerciseRecord.self,
            UserProfileRecord.self
        ])
    }
}
```

There is no dedicated unit test for this step — `.modelContainer(for:)` wires a real on-disk store into the app scene, which only a running app (not an XCTest target) instantiates. Correctness here is verified by the app target building successfully as part of Step 2's CI run, and functionally by Plan B2's screens actually reading/writing data through it.

- [ ] **Step 2: Commit, push, verify CI green**

```bash
git add MuscleLoadApp/App/MuscleLoadAppApp.swift
git commit -m "$(cat <<'EOF'
Wire SwiftData ModelContainer into the app entry point

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push
```

- [ ] **Step 3: Final check**

Open `https://github.com/IDVhack/MuscleLoadApp/actions`, confirm the latest `MuscleLoadApp CI` run on this commit is green, and confirm the latest `MuscleLoadCore CI` run (from Task 1) is still green. Spot-check `MuscleLoadApp/` contains exactly: `App/MuscleLoadAppApp.swift`, `Navigation/RootTabView.swift`, `Persistence/{WorkoutSessionRecord,SetEntryRecord,CustomExerciseRecord,UserProfileRecord,WorkoutRepository}.swift` — no leftover sanity-test files anywhere.

---

## Self-Review

**Spec coverage:** Design doc §3 (catalog lookups) → Task 1. §4 (XcodeGen + CI) → Task 2. §5 (SwiftData models + bridge) → Tasks 3-4. §6 (bodyweight handling) is explicitly a Plan B2 UI concern — no task here implements it, correctly deferred. §7 (nav shell) → Task 2's `RootTabView`. §8 (testing) → every task's CI verification step. §9 (out of scope) — Plan B2 features correctly absent from this plan.

**Placeholder scan:** no TBD/TODO. Task 5's "no dedicated unit test" note is an explicit, justified statement about SwiftUI App lifecycle testability, not a skipped requirement.

**Type consistency:** `WorkoutRepository.resolveExercise(id:) -> Exercise?` (Task 4) is used with the same signature inside `currentRecoveryStatuses` in the same task. `ExerciseCatalog.exercise(id:)` / `MovementPatternCatalog.pattern(id:)` (Task 1) are called with identical names in Task 4. `WorkoutSessionRecord`/`SetEntryRecord`/`CustomExerciseRecord`/`UserProfileRecord` property names introduced in Task 3 (`exerciseID`, `weightKg`, `reps`, `setNumber`, `movementPatternID`, `bodyweightKg`, `notificationsEnabled`) are used with matching names in Task 4's repository and Task 5's `modelContainer(for:)` call — checked against each task's Interfaces block.
