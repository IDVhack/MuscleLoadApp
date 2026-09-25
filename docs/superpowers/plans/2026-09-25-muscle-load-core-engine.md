# MuscleLoadCore Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and fully unit-test the platform-independent `MuscleLoadCore` Swift package — muscle/exercise data model, the 23-exercise / 20-pattern catalog, and the `RecoveryEngine` load/recovery algorithm — with zero SwiftUI/SwiftData/UIKit dependencies, verified by GitHub Actions on `ubuntu-latest`.

**Architecture:** A standalone Swift Package at the repo root (`MuscleLoadCore/`), MVVM-agnostic, pure value types (`struct`/`enum`), no persistence framework. This becomes the local Swift package dependency for the future iOS app (Plan B) without any changes to its public API.

**Tech Stack:** Swift 5.10, Swift Package Manager, XCTest, GitHub Actions (`ubuntu-latest`, `swift-actions/setup-swift@v2`).

**Spec:** [docs/superpowers/specs/2026-09-25-muscle-load-app-design.md](../specs/2026-09-25-muscle-load-app-design.md)

## Global Constraints

- No Xcode, no SwiftData, no SwiftUI, no UIKit imports anywhere in this plan — `MuscleLoadCore` must build and test on Linux (`ubuntu-latest`) via `swift test`. That's how tests get verified from this session: there is no local Swift toolchain and no Mac available.
- All muscle/pattern/exercise names and UI-facing strings are Russian, matching the spec's screens and table (spec §5, §6) — no localization system, just literal Russian strings.
- `MovementPattern` is the single source of truth for muscles + heaviness coefficient (spec §3) — `Exercise` never duplicates muscle lists.
- Recovery formula, thresholds (40% / 85%) and fixed windows (72h / 48h / 24h) are exactly as calibrated in spec §4 and §10 — these are named "starting values, subject to tuning" in the spec, not placeholders; they must appear as concrete numbers in code, not TODOs.
- Push directly to `main` after each task (solo project, no branch protection, no PR review configured yet).
- Verifying a task means: `git push origin main`, then open `https://github.com/IDVhack/MuscleLoadApp/actions` in the browser pane, wait for the run on the pushed commit to finish, and confirm it is green. If red, open the failing job's log, fix, and re-push before moving to the next task.

## Note on this plan's data vs. the spec

While enumerating the exercise table with the user, three movement-pattern
names were reused for exercises whose heaviness coefficient actually
differs (pull-ups vs. lat pulldowns; seated vs. standing overhead press;
cable pushdown vs. skull crusher). Since a coefficient lives on the pattern
alone (spec §3), reusing one pattern name with two different coefficients
is a contradiction. This plan resolves it by splitting those three into six
patterns (`verticalPullBodyweight`/`verticalPullCable`,
`overheadPressSeated`/`overheadPressStanding`,
`tricepExtensionCable`/`tricepExtensionLying`), bringing the total from 16
to **20 movement patterns** for the same **23 exercises**. All muscle
assignments and coefficients otherwise match what was agreed in chat.

---

## Task 1: Package scaffolding and CI pipeline

**Files:**
- Create: `MuscleLoadCore/Package.swift`
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/MuscleLoadCore.swift` (empty placeholder, deleted in Task 2)
- Create: `MuscleLoadCore/Tests/MuscleLoadCoreTests/PipelineSanityTests.swift`
- Create: `.github/workflows/core-ci.yml`
- Create: `.gitignore`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: a buildable, testable empty package; a CI workflow that runs `swift test` on every push

- [ ] **Step 1: Create the package manifest**

`MuscleLoadCore/Package.swift`:

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MuscleLoadCore",
    products: [
        .library(name: "MuscleLoadCore", targets: ["MuscleLoadCore"])
    ],
    targets: [
        .target(name: "MuscleLoadCore"),
        .testTarget(name: "MuscleLoadCoreTests", dependencies: ["MuscleLoadCore"])
    ]
)
```

No `platforms:` entry — this must stay buildable on Linux (`ubuntu-latest`), so it cannot be restricted to Apple platforms.

- [ ] **Step 2: Create a placeholder source file**

`MuscleLoadCore/Sources/MuscleLoadCore/MuscleLoadCore.swift`:

```swift
// Placeholder so the target has at least one file. Removed in Task 2
// once MuscleGroup.swift exists.
public enum MuscleLoadCorePlaceholder {}
```

- [ ] **Step 3: Write a deliberately failing sanity test**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/PipelineSanityTests.swift`:

```swift
import XCTest

final class PipelineSanityTests: XCTestCase {
    func test_ciPipelineCatchesFailures() {
        XCTAssertTrue(false, "this must fail until Step 5")
    }
}
```

- [ ] **Step 4: Create the CI workflow**

`.github/workflows/core-ci.yml`:

```yaml
name: MuscleLoadCore CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Set up Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "5.10"
      - name: Run MuscleLoadCore tests
        working-directory: MuscleLoadCore
        run: swift test
```

- [ ] **Step 5: Create `.gitignore`**

`.gitignore`:

```
.build/
.swiftpm/
DerivedData/
*.xcuserstate
.DS_Store
```

- [ ] **Step 6: Commit and push, verify CI goes RED**

```bash
git add MuscleLoadCore .github .gitignore
git commit -m "$(cat <<'EOF'
Scaffold MuscleLoadCore package and CI pipeline

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Open `https://github.com/IDVhack/MuscleLoadApp/actions` in the browser pane, wait for the run on this commit, and confirm it finished with a **failure** (the sanity test asserts `false`). This proves the pipeline actually runs `swift test` and surfaces failures — if it shows green here, the workflow is misconfigured and must be fixed before continuing.

- [ ] **Step 7: Fix the sanity test to pass**

Edit `PipelineSanityTests.swift`:

```swift
import XCTest

final class PipelineSanityTests: XCTestCase {
    func test_ciPipelineCatchesFailures() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 8: Commit, push, verify CI goes GREEN**

```bash
git add MuscleLoadCore/Tests/MuscleLoadCoreTests/PipelineSanityTests.swift
git commit -m "$(cat <<'EOF'
Fix sanity test to confirm green CI path

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Confirm the new run on `https://github.com/IDVhack/MuscleLoadApp/actions` is green. From this task onward, every subsequent task pushes test + implementation together in one commit and expects a single green run (the red/green pipeline check doesn't need repeating).

---

## Task 2: `MuscleGroup`

**Files:**
- Delete: `MuscleLoadCore/Sources/MuscleLoadCore/MuscleLoadCore.swift`
- Delete: `MuscleLoadCore/Tests/MuscleLoadCoreTests/PipelineSanityTests.swift`
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/MuscleGroup.swift`
- Test: `MuscleLoadCore/Tests/MuscleLoadCoreTests/MuscleGroupTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `public enum MuscleGroup: String, CaseIterable, Codable, Hashable, Sendable` with 13 cases, `.displayName: String`, `.recoveryWindowHours: Double`, `.fullLoadThreshold: Double` — used by every later task.

- [ ] **Step 1: Remove the placeholder files**

```bash
git rm MuscleLoadCore/Sources/MuscleLoadCore/MuscleLoadCore.swift
git rm MuscleLoadCore/Tests/MuscleLoadCoreTests/PipelineSanityTests.swift
```

- [ ] **Step 2: Write the test file**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/MuscleGroupTests.swift`:

```swift
import XCTest
@testable import MuscleLoadCore

final class MuscleGroupTests: XCTestCase {
    func test_hasThirteenCases() {
        XCTAssertEqual(MuscleGroup.allCases.count, 13)
    }

    func test_recoveryWindow_largeMuscles_is72Hours() {
        XCTAssertEqual(MuscleGroup.quadriceps.recoveryWindowHours, 72)
        XCTAssertEqual(MuscleGroup.glutes.recoveryWindowHours, 72)
        XCTAssertEqual(MuscleGroup.upperBack.recoveryWindowHours, 72)
        XCTAssertEqual(MuscleGroup.chest.recoveryWindowHours, 72)
    }

    func test_recoveryWindow_mediumMuscles_is48Hours() {
        XCTAssertEqual(MuscleGroup.hamstrings.recoveryWindowHours, 48)
        XCTAssertEqual(MuscleGroup.lowerBack.recoveryWindowHours, 48)
        XCTAssertEqual(MuscleGroup.shoulders.recoveryWindowHours, 48)
    }

    func test_recoveryWindow_smallMuscles_is24Hours() {
        XCTAssertEqual(MuscleGroup.biceps.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.triceps.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.calves.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.forearms.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.adductors.recoveryWindowHours, 24)
        XCTAssertEqual(MuscleGroup.absCore.recoveryWindowHours, 24)
    }

    func test_fullLoadThreshold_matchesSizeCategory() {
        XCTAssertEqual(MuscleGroup.quadriceps.fullLoadThreshold, 4500)
        XCTAssertEqual(MuscleGroup.hamstrings.fullLoadThreshold, 3000)
        XCTAssertEqual(MuscleGroup.biceps.fullLoadThreshold, 1500)
    }

    func test_allCases_haveNonEmptyDisplayName() {
        for muscle in MuscleGroup.allCases {
            XCTAssertFalse(muscle.displayName.isEmpty, "\(muscle) has empty displayName")
        }
    }
}
```

- [ ] **Step 3: Implement `MuscleGroup`**

`MuscleLoadCore/Sources/MuscleLoadCore/MuscleGroup.swift`:

```swift
public enum MuscleGroup: String, CaseIterable, Codable, Hashable, Sendable {
    case shoulders
    case biceps
    case triceps
    case chest
    case upperBack
    case lowerBack
    case absCore
    case glutes
    case quadriceps
    case hamstrings
    case adductors
    case calves
    case forearms

    public var displayName: String {
        switch self {
        case .shoulders: return "Плечи"
        case .biceps: return "Бицепс"
        case .triceps: return "Трицепс"
        case .chest: return "Грудь"
        case .upperBack: return "Верх спины"
        case .lowerBack: return "Поясница"
        case .absCore: return "Пресс и кор"
        case .glutes: return "Ягодицы"
        case .quadriceps: return "Квадрицепс"
        case .hamstrings: return "Задняя поверхность бедра"
        case .adductors: return "Приводящие"
        case .calves: return "Икры"
        case .forearms: return "Предплечья"
        }
    }

    /// Fixed recovery window in hours, per spec section 4.
    public var recoveryWindowHours: Double {
        switch self {
        case .quadriceps, .glutes, .upperBack, .chest:
            return 72
        case .hamstrings, .lowerBack, .shoulders:
            return 48
        case .biceps, .triceps, .calves, .forearms, .adductors, .absCore:
            return 24
        }
    }

    /// Raw load units needed to reach ~100% momentary load in one session.
    /// Starting calibration value per spec section 10 — subject to tuning
    /// once real workout data is available.
    public var fullLoadThreshold: Double {
        switch self {
        case .quadriceps, .glutes, .upperBack, .chest:
            return 4500
        case .hamstrings, .lowerBack, .shoulders:
            return 3000
        case .biceps, .triceps, .calves, .forearms, .adductors, .absCore:
            return 1500
        }
    }
}
```

- [ ] **Step 4: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add MuscleGroup with recovery windows and load thresholds

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Open the Actions run for this commit and confirm green before starting Task 3.

---

## Task 3: `MovementPattern` and the pattern catalog

**Files:**
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/MovementPattern.swift`
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/MovementPatternCatalog.swift`
- Test: `MuscleLoadCore/Tests/MuscleLoadCoreTests/MovementPatternCatalogTests.swift`

**Interfaces:**
- Consumes: `MuscleGroup` (Task 2)
- Produces: `public struct MovementPattern: Identifiable, Equatable, Codable, Sendable` (`id: String`, `name: String`, `primaryMuscles: [MuscleGroup]`, `secondaryMuscles: [MuscleGroup]`, `heavinessCoefficient: Double`), and `public enum MovementPatternCatalog` exposing 20 named `static let` patterns plus `static let all: [MovementPattern]` — consumed by Task 4.

- [ ] **Step 1: Write the catalog test**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/MovementPatternCatalogTests.swift`:

```swift
import XCTest
@testable import MuscleLoadCore

final class MovementPatternCatalogTests: XCTestCase {
    func test_hasTwentyPatterns() {
        XCTAssertEqual(MovementPatternCatalog.all.count, 20)
    }

    func test_allPatternIDsAreUnique() {
        let ids = MovementPatternCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_squat_hasExpectedMusclesAndCoefficient() {
        let squat = MovementPatternCatalog.squat
        XCTAssertEqual(squat.primaryMuscles, [.quadriceps, .glutes])
        XCTAssertEqual(squat.secondaryMuscles, [.hamstrings, .lowerBack, .absCore])
        XCTAssertEqual(squat.heavinessCoefficient, 1.8)
    }

    func test_verticalPullPatterns_haveDifferentCoefficients() {
        // Split from one "Тяга вертикальная" pattern name in chat because
        // bodyweight pull-ups and cable lat pulldowns have different
        // heaviness — see plan header note.
        XCTAssertEqual(MovementPatternCatalog.verticalPullBodyweight.heavinessCoefficient, 1.5)
        XCTAssertEqual(MovementPatternCatalog.verticalPullCable.heavinessCoefficient, 1.3)
    }

    func test_overheadPressPatterns_haveDifferentCoefficients() {
        XCTAssertEqual(MovementPatternCatalog.overheadPressSeated.heavinessCoefficient, 1.3)
        XCTAssertEqual(MovementPatternCatalog.overheadPressStanding.heavinessCoefficient, 1.4)
    }

    func test_tricepExtensionPatterns_haveDifferentCoefficients() {
        XCTAssertEqual(MovementPatternCatalog.tricepExtensionCable.heavinessCoefficient, 0.8)
        XCTAssertEqual(MovementPatternCatalog.tricepExtensionLying.heavinessCoefficient, 0.9)
    }

    func test_hipAbduction_hasNoSecondaryMuscles() {
        XCTAssertTrue(MovementPatternCatalog.hipAbduction.secondaryMuscles.isEmpty)
    }
}
```

- [ ] **Step 2: Implement `MovementPattern`**

`MuscleLoadCore/Sources/MuscleLoadCore/MovementPattern.swift`:

```swift
public struct MovementPattern: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let primaryMuscles: [MuscleGroup]
    public let secondaryMuscles: [MuscleGroup]
    public let heavinessCoefficient: Double

    public init(
        id: String,
        name: String,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        heavinessCoefficient: Double
    ) {
        self.id = id
        self.name = name
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.heavinessCoefficient = heavinessCoefficient
    }
}
```

- [ ] **Step 3: Implement the 20-pattern catalog**

`MuscleLoadCore/Sources/MuscleLoadCore/MovementPatternCatalog.swift`:

```swift
public enum MovementPatternCatalog {
    public static let squat = MovementPattern(
        id: "squat",
        name: "Присед",
        primaryMuscles: [.quadriceps, .glutes],
        secondaryMuscles: [.hamstrings, .lowerBack, .absCore],
        heavinessCoefficient: 1.8
    )

    public static let squatMachine = MovementPattern(
        id: "squatMachine",
        name: "Присед (тренажёр)",
        primaryMuscles: [.quadriceps, .glutes],
        secondaryMuscles: [.hamstrings],
        heavinessCoefficient: 1.5
    )

    public static let hipHinge = MovementPattern(
        id: "hipHinge",
        name: "Тазобедренный шарнир",
        primaryMuscles: [.hamstrings, .glutes],
        secondaryMuscles: [.lowerBack, .upperBack],
        heavinessCoefficient: 1.7
    )

    public static let hipExtension = MovementPattern(
        id: "hipExtension",
        name: "Разгибание бедра",
        primaryMuscles: [.glutes],
        secondaryMuscles: [.hamstrings, .lowerBack, .absCore],
        heavinessCoefficient: 1.3
    )

    public static let legCurl = MovementPattern(
        id: "legCurl",
        name: "Сгибание ноги",
        primaryMuscles: [.hamstrings],
        secondaryMuscles: [.calves],
        heavinessCoefficient: 1.0
    )

    public static let hipAbduction = MovementPattern(
        id: "hipAbduction",
        name: "Отведение бедра",
        primaryMuscles: [.glutes],
        secondaryMuscles: [],
        heavinessCoefficient: 0.8
    )

    public static let horizontalPress = MovementPattern(
        id: "horizontalPress",
        name: "Жим горизонтальный",
        primaryMuscles: [.chest, .triceps],
        secondaryMuscles: [.shoulders, .absCore],
        heavinessCoefficient: 1.2
    )

    public static let crunch = MovementPattern(
        id: "crunch",
        name: "Скручивание",
        primaryMuscles: [.absCore],
        secondaryMuscles: [],
        heavinessCoefficient: 0.8
    )

    public static let verticalPullBodyweight = MovementPattern(
        id: "verticalPullBodyweight",
        name: "Тяга вертикальная (свой вес)",
        primaryMuscles: [.upperBack],
        secondaryMuscles: [.biceps, .forearms],
        heavinessCoefficient: 1.5
    )

    public static let verticalPullCable = MovementPattern(
        id: "verticalPullCable",
        name: "Тяга вертикальная (блок)",
        primaryMuscles: [.upperBack],
        secondaryMuscles: [.biceps, .shoulders, .forearms],
        heavinessCoefficient: 1.3
    )

    public static let horizontalPull = MovementPattern(
        id: "horizontalPull",
        name: "Тяга горизонтальная",
        primaryMuscles: [.upperBack],
        secondaryMuscles: [.biceps, .shoulders, .forearms],
        heavinessCoefficient: 1.3
    )

    public static let pullover = MovementPattern(
        id: "pullover",
        name: "Пуловер",
        primaryMuscles: [.upperBack, .chest],
        secondaryMuscles: [.triceps],
        heavinessCoefficient: 1.0
    )

    public static let bicepCurl = MovementPattern(
        id: "bicepCurl",
        name: "Сгибание руки",
        primaryMuscles: [.biceps],
        secondaryMuscles: [.forearms],
        heavinessCoefficient: 0.8
    )

    public static let overheadPressSeated = MovementPattern(
        id: "overheadPressSeated",
        name: "Жим вертикальный (сидя)",
        primaryMuscles: [.shoulders],
        secondaryMuscles: [.triceps, .chest],
        heavinessCoefficient: 1.3
    )

    public static let overheadPressStanding = MovementPattern(
        id: "overheadPressStanding",
        name: "Жим вертикальный (стоя)",
        primaryMuscles: [.shoulders],
        secondaryMuscles: [.triceps, .absCore],
        heavinessCoefficient: 1.4
    )

    public static let tricepExtensionCable = MovementPattern(
        id: "tricepExtensionCable",
        name: "Разгибание руки (блок)",
        primaryMuscles: [.triceps],
        secondaryMuscles: [.forearms],
        heavinessCoefficient: 0.8
    )

    public static let tricepExtensionLying = MovementPattern(
        id: "tricepExtensionLying",
        name: "Разгибание руки (жим лёжа)",
        primaryMuscles: [.triceps],
        secondaryMuscles: [],
        heavinessCoefficient: 0.9
    )

    public static let lateralRaise = MovementPattern(
        id: "lateralRaise",
        name: "Разведение/мах",
        primaryMuscles: [.shoulders],
        secondaryMuscles: [.upperBack],
        heavinessCoefficient: 0.8
    )

    public static let backExtension = MovementPattern(
        id: "backExtension",
        name: "Разгибание спины",
        primaryMuscles: [.lowerBack],
        secondaryMuscles: [.glutes, .hamstrings],
        heavinessCoefficient: 1.2
    )

    public static let lunge = MovementPattern(
        id: "lunge",
        name: "Выпад",
        primaryMuscles: [.quadriceps, .glutes],
        secondaryMuscles: [.hamstrings, .absCore],
        heavinessCoefficient: 1.4
    )

    public static let all: [MovementPattern] = [
        squat, squatMachine, hipHinge, hipExtension, legCurl, hipAbduction,
        horizontalPress, crunch, verticalPullBodyweight, verticalPullCable,
        horizontalPull, pullover, bicepCurl, overheadPressSeated,
        overheadPressStanding, tricepExtensionCable, tricepExtensionLying,
        lateralRaise, backExtension, lunge
    ]
}
```

- [ ] **Step 4: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add MovementPattern and 20-pattern catalog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 4: `Exercise` and the 23-exercise catalog

**Files:**
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/Exercise.swift`
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift`
- Test: `MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift`

**Interfaces:**
- Consumes: `MovementPattern`, `MovementPatternCatalog` (Task 3)
- Produces: `public struct Exercise: Identifiable, Equatable, Codable, Sendable` (`id: String`, `name: String`, `movementPattern: MovementPattern`, `isBuiltIn: Bool`, `techniqueDescription: String?`, `imageAssetName: String?`), and `public enum ExerciseCatalog` with `static let all: [Exercise]` (23 entries) — consumed by Task 5 and Task 6's tests.

- [ ] **Step 1: Write the catalog test**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/ExerciseCatalogTests.swift`:

```swift
import XCTest
@testable import MuscleLoadCore

final class ExerciseCatalogTests: XCTestCase {
    func test_hasTwentyThreeBuiltInExercises() {
        XCTAssertEqual(ExerciseCatalog.all.count, 23)
        XCTAssertTrue(ExerciseCatalog.all.allSatisfy(\.isBuiltIn))
    }

    func test_allExerciseIDsAreUnique() {
        let ids = ExerciseCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_barbellSquat_usesSquatPattern() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }
        XCTAssertEqual(squat?.movementPattern.id, "squat")
    }

    func test_hipAbductionExercises_shareSamePattern() {
        let cable = ExerciseCatalog.all.first { $0.id == "cableHipAbduction" }
        let seated = ExerciseCatalog.all.first { $0.id == "seatedHipAbduction" }
        XCTAssertEqual(cable?.movementPattern.id, "hipAbduction")
        XCTAssertEqual(seated?.movementPattern.id, "hipAbduction")
    }

    func test_pullUp_usesBodyweightVerticalPull() {
        let pullUp = ExerciseCatalog.all.first { $0.id == "pullUp" }
        XCTAssertEqual(pullUp?.movementPattern.id, "verticalPullBodyweight")
    }

    func test_imageAndTechniqueDefaultToNil() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }
        XCTAssertNil(squat?.imageAssetName)
        XCTAssertNil(squat?.techniqueDescription)
    }
}
```

- [ ] **Step 2: Implement `Exercise`**

`MuscleLoadCore/Sources/MuscleLoadCore/Exercise.swift`:

```swift
public struct Exercise: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let movementPattern: MovementPattern
    public let isBuiltIn: Bool
    public let techniqueDescription: String?
    public let imageAssetName: String?

    public init(
        id: String,
        name: String,
        movementPattern: MovementPattern,
        isBuiltIn: Bool,
        techniqueDescription: String? = nil,
        imageAssetName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.movementPattern = movementPattern
        self.isBuiltIn = isBuiltIn
        self.techniqueDescription = techniqueDescription
        self.imageAssetName = imageAssetName
    }
}
```

- [ ] **Step 3: Implement the 23-exercise catalog**

`MuscleLoadCore/Sources/MuscleLoadCore/ExerciseCatalog.swift`:

```swift
public enum ExerciseCatalog {
    public static let all: [Exercise] = [
        Exercise(id: "barbellSquat", name: "Приседания со штангой", movementPattern: MovementPatternCatalog.squat, isBuiltIn: true),
        Exercise(id: "pullUp", name: "Подтягивания", movementPattern: MovementPatternCatalog.verticalPullBodyweight, isBuiltIn: true),
        Exercise(id: "romanianDeadlift", name: "Румынская тяга", movementPattern: MovementPatternCatalog.hipHinge, isBuiltIn: true),
        Exercise(id: "gluteBridge", name: "Ягодичный мост", movementPattern: MovementPatternCatalog.hipExtension, isBuiltIn: true),
        Exercise(id: "legPress", name: "Жим ногами", movementPattern: MovementPatternCatalog.squatMachine, isBuiltIn: true),
        Exercise(id: "lyingLegCurl", name: "Сгибание ног лёжа", movementPattern: MovementPatternCatalog.legCurl, isBuiltIn: true),
        Exercise(id: "cableHipAbduction", name: "Отведение ноги в кроссовере", movementPattern: MovementPatternCatalog.hipAbduction, isBuiltIn: true),
        Exercise(id: "seatedHipAbduction", name: "Разводка ног сидя", movementPattern: MovementPatternCatalog.hipAbduction, isBuiltIn: true),
        Exercise(id: "pushUp", name: "Отжимания", movementPattern: MovementPatternCatalog.horizontalPress, isBuiltIn: true),
        Exercise(id: "crunch", name: "Пресс", movementPattern: MovementPatternCatalog.crunch, isBuiltIn: true),
        Exercise(id: "wideGripLatPulldown", name: "Вертикальная тяга (широкий хват)", movementPattern: MovementPatternCatalog.verticalPullCable, isBuiltIn: true),
        Exercise(id: "closeGripLatPulldown", name: "Вертикальная тяга (узкий хват)", movementPattern: MovementPatternCatalog.verticalPullCable, isBuiltIn: true),
        Exercise(id: "seatedCableRow", name: "Горизонтальная тяга", movementPattern: MovementPatternCatalog.horizontalPull, isBuiltIn: true),
        Exercise(id: "pullover", name: "Пуловер", movementPattern: MovementPatternCatalog.pullover, isBuiltIn: true),
        Exercise(id: "dumbbellBicepCurl", name: "Подъём гантелей на бицепс", movementPattern: MovementPatternCatalog.bicepCurl, isBuiltIn: true),
        Exercise(id: "seatedDumbbellPress", name: "Жим гантелей сидя", movementPattern: MovementPatternCatalog.overheadPressSeated, isBuiltIn: true),
        Exercise(id: "cableTricepPushdown", name: "Разгибание рук (верхний блок)", movementPattern: MovementPatternCatalog.tricepExtensionCable, isBuiltIn: true),
        Exercise(id: "skullCrusher", name: "Французский жим", movementPattern: MovementPatternCatalog.tricepExtensionLying, isBuiltIn: true),
        Exercise(id: "standingLateralRaise", name: "Разведение гантелей стоя", movementPattern: MovementPatternCatalog.lateralRaise, isBuiltIn: true),
        Exercise(id: "standingDumbbellPress", name: "Жим гантелей стоя", movementPattern: MovementPatternCatalog.overheadPressStanding, isBuiltIn: true),
        Exercise(id: "reverseMachineFly", name: "Обратные разведения в тренажёре", movementPattern: MovementPatternCatalog.lateralRaise, isBuiltIn: true),
        Exercise(id: "hyperextension", name: "Гиперэкстензия", movementPattern: MovementPatternCatalog.backExtension, isBuiltIn: true),
        Exercise(id: "bulgarianSplitSquat", name: "Болгарские выпады", movementPattern: MovementPatternCatalog.lunge, isBuiltIn: true)
    ]
}
```

- [ ] **Step 4: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add Exercise and 23-exercise built-in catalog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 5: `SetEntry` and `WorkoutSession`

**Files:**
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/SetEntry.swift`
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/WorkoutSession.swift`
- Test: `MuscleLoadCore/Tests/MuscleLoadCoreTests/SetEntryTests.swift`

**Interfaces:**
- Consumes: `Exercise`, `ExerciseCatalog` (Task 4)
- Produces: `public struct SetEntry: Identifiable, Equatable, Codable, Sendable` (`id: UUID`, `exercise: Exercise`, `weightKg: Double`, `reps: Int`, `setNumber: Int`, computed `rawLoad: Double`), and `public struct WorkoutSession: Identifiable, Equatable, Codable, Sendable` (`id: UUID`, `date: Date`, `sets: [SetEntry]`, `perceivedEffort: Int?`) — both consumed directly by `RecoveryEngine` in Task 6.

- [ ] **Step 1: Write the test**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/SetEntryTests.swift`:

```swift
import XCTest
@testable import MuscleLoadCore

final class SetEntryTests: XCTestCase {
    func test_rawLoad_multipliesWeightRepsAndCoefficient() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }!
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        // 80 * 8 * 1.8 = 1152, per spec section 4's raw_load formula.
        XCTAssertEqual(set.rawLoad, 1152, accuracy: 0.001)
    }

    func test_workoutSession_holdsMultipleSets() {
        let squat = ExerciseCatalog.all.first { $0.id == "barbellSquat" }!
        let sets = (1...3).map { SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: $0) }
        let session = WorkoutSession(date: .now, sets: sets, perceivedEffort: 7)

        XCTAssertEqual(session.sets.count, 3)
        XCTAssertEqual(session.perceivedEffort, 7)
    }
}
```

- [ ] **Step 2: Implement `SetEntry`**

`MuscleLoadCore/Sources/MuscleLoadCore/SetEntry.swift`:

```swift
import Foundation

public struct SetEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let exercise: Exercise
    public let weightKg: Double
    public let reps: Int
    public let setNumber: Int

    public init(id: UUID = UUID(), exercise: Exercise, weightKg: Double, reps: Int, setNumber: Int) {
        self.id = id
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.setNumber = setNumber
    }

    /// raw_load = вес × повторы × heaviness_coefficient, per spec section 4.
    public var rawLoad: Double {
        weightKg * Double(reps) * exercise.movementPattern.heavinessCoefficient
    }
}
```

- [ ] **Step 3: Implement `WorkoutSession`**

`MuscleLoadCore/Sources/MuscleLoadCore/WorkoutSession.swift`:

```swift
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
```

- [ ] **Step 4: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add SetEntry raw load calculation and WorkoutSession

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 6: `RecoveryEngine` — momentary load

**Files:**
- Create: `MuscleLoadCore/Sources/MuscleLoadCore/RecoveryEngine.swift`
- Test: `MuscleLoadCore/Tests/MuscleLoadCoreTests/RecoveryEngineMomentaryLoadTests.swift`

**Interfaces:**
- Consumes: `MuscleGroup`, `SetEntry`, `WorkoutSession` (Tasks 2, 5)
- Produces: `public struct RecoveryEngine: Sendable` with `public func momentaryLoad(for session: WorkoutSession) -> [MuscleGroup: Double]` — consumed by Task 7's `recoveryStatus`.

- [ ] **Step 1: Write the momentary-load tests**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/RecoveryEngineMomentaryLoadTests.swift`:

```swift
import XCTest
@testable import MuscleLoadCore

final class RecoveryEngineMomentaryLoadTests: XCTestCase {
    let engine = RecoveryEngine()

    private func exercise(_ id: String) -> Exercise {
        ExerciseCatalog.all.first { $0.id == id }!
    }

    func test_momentaryLoad_singleSet_splitsPrimaryAndSecondary() {
        let squat = exercise("barbellSquat")
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: .now, sets: [set])

        let load = engine.momentaryLoad(for: session)

        // rawLoad = 80 * 8 * 1.8 = 1152.
        // Primary (quadriceps, glutes) get full 1152, threshold 4500 (large).
        XCTAssertEqual(load[.quadriceps] ?? 0, 1152 / 4500 * 100, accuracy: 0.01)
        XCTAssertEqual(load[.glutes] ?? 0, 1152 / 4500 * 100, accuracy: 0.01)

        // Secondary (hamstrings, lowerBack, absCore) get half: 576.
        XCTAssertEqual(load[.hamstrings] ?? 0, 576 / 3000 * 100, accuracy: 0.01)
        XCTAssertEqual(load[.lowerBack] ?? 0, 576 / 3000 * 100, accuracy: 0.01)
        XCTAssertEqual(load[.absCore] ?? 0, 576 / 1500 * 100, accuracy: 0.01)
    }

    func test_momentaryLoad_capsAtOneHundredPercent() {
        let squat = exercise("barbellSquat")
        let sets = (1...10).map { SetEntry(exercise: squat, weightKg: 150, reps: 12, setNumber: $0) }
        let session = WorkoutSession(date: .now, sets: sets)

        let load = engine.momentaryLoad(for: session)

        XCTAssertEqual(load[.quadriceps] ?? 0, 100, accuracy: 0.01)
    }

    func test_momentaryLoad_multipleExercises_accumulatePerMuscle() {
        let squat = exercise("barbellSquat")
        let lunge = exercise("bulgarianSplitSquat")
        let squatSet = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let lungeSet = SetEntry(exercise: lunge, weightKg: 20, reps: 10, setNumber: 1)
        let session = WorkoutSession(date: .now, sets: [squatSet, lungeSet])

        // Both exercises have quadriceps as primary, so their contributions add up.
        let load = engine.momentaryLoad(for: session)
        let squatRaw = 80.0 * 8 * 1.8
        let lungeRaw = 20.0 * 10 * 1.4
        let expected = min(100, (squatRaw + lungeRaw) / 4500 * 100)
        XCTAssertEqual(load[.quadriceps] ?? 0, expected, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Implement `RecoveryEngine.momentaryLoad`**

`MuscleLoadCore/Sources/MuscleLoadCore/RecoveryEngine.swift`:

```swift
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
```

- [ ] **Step 3: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add RecoveryEngine.momentaryLoad per-session muscle load calc

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 7: `RecoveryEngine` — recovery status over time

**Files:**
- Modify: `MuscleLoadCore/Sources/MuscleLoadCore/RecoveryEngine.swift`
- Test: `MuscleLoadCore/Tests/MuscleLoadCoreTests/RecoveryEngineRecoveryStatusTests.swift`

**Interfaces:**
- Consumes: `RecoveryEngine.momentaryLoad` (Task 6)
- Produces: `public enum RecoveryStatus: Equatable, Sendable { case early, soon, ready }`, `public struct MuscleRecoveryStatus: Equatable, Sendable` (`muscleGroup: MuscleGroup`, `recoveryPercent: Double`, `status: RecoveryStatus`), and `public func recoveryStatus(asOf date: Date, sessions: [WorkoutSession]) -> [MuscleRecoveryStatus]` on `RecoveryEngine` — this is the function the future app's dashboard ViewModel (Plan B) calls directly.

- [ ] **Step 1: Write the recovery-status tests**

`MuscleLoadCore/Tests/MuscleLoadCoreTests/RecoveryEngineRecoveryStatusTests.swift`:

```swift
import XCTest
@testable import MuscleLoadCore

final class RecoveryEngineRecoveryStatusTests: XCTestCase {
    let engine = RecoveryEngine()

    private func exercise(_ id: String) -> Exercise {
        ExerciseCatalog.all.first { $0.id == id }!
    }

    func test_recoveryStatus_returnsAllThirteenMuscleGroups() {
        let statuses = engine.recoveryStatus(asOf: .now, sessions: [])
        XCTAssertEqual(statuses.count, 13)
        XCTAssertTrue(statuses.allSatisfy { $0.recoveryPercent == 100 && $0.status == .ready })
    }

    func test_recoveryStatus_immediatelyAfterSession_isEarly() {
        let squat = exercise("barbellSquat")
        let sets = (1...4).map { SetEntry(exercise: squat, weightKg: 100, reps: 8, setNumber: $0) }
        let sessionDate = Date()
        let session = WorkoutSession(date: sessionDate, sets: sets)

        let statuses = engine.recoveryStatus(asOf: sessionDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        // 4 * 100kg * 8 reps * 1.8 = 5760 raw, capped at 100% momentary load.
        // Right at session end: recoveryPercent = 100 - 100 = 0%.
        XCTAssertEqual(quadStatus.recoveryPercent, 0, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .early)
    }

    func test_recoveryStatus_atEndOfWindow_isFullyRecovered() {
        let squat = exercise("barbellSquat")
        let sessionDate = Date(timeIntervalSince1970: 0)
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: sessionDate, sets: [set])

        // Quadriceps window is 72h.
        let checkDate = sessionDate.addingTimeInterval(72 * 3600)
        let statuses = engine.recoveryStatus(asOf: checkDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertEqual(quadStatus.recoveryPercent, 100, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .ready)
    }

    func test_recoveryStatus_halfwayThroughWindow_isPartiallyRecovered() {
        let squat = exercise("barbellSquat")
        let sessionDate = Date(timeIntervalSince1970: 0)
        let sets = (1...4).map { SetEntry(exercise: squat, weightKg: 100, reps: 8, setNumber: $0) }
        let session = WorkoutSession(date: sessionDate, sets: sets)

        // Momentary load for quadriceps is capped at 100% (huge session).
        // Halfway through the 72h window (36h): remaining load = 100 * 0.5 = 50.
        // recoveryPercent = 100 - 50 = 50 -> status .soon (40..<85).
        let checkDate = sessionDate.addingTimeInterval(36 * 3600)
        let statuses = engine.recoveryStatus(asOf: checkDate, sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertEqual(quadStatus.recoveryPercent, 50, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .soon)
    }

    func test_recoveryStatus_stacksLoadFromOverlappingSessions() {
        let squat = exercise("barbellSquat")
        let firstSessionDate = Date(timeIntervalSince1970: 0)
        let secondSessionDate = firstSessionDate.addingTimeInterval(24 * 3600)

        let firstSet = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let secondSet = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)

        let sessions = [
            WorkoutSession(date: firstSessionDate, sets: [firstSet]),
            WorkoutSession(date: secondSessionDate, sets: [secondSet])
        ]

        // Right after the second session, session 1's partially-decayed load
        // stacks with session 2's fresh load, so recovery must be lower than
        // if only session 2 had happened.
        let checkDate = secondSessionDate
        let stackedStatuses = engine.recoveryStatus(asOf: checkDate, sessions: sessions)
        let stackedQuad = stackedStatuses.first { $0.muscleGroup == .quadriceps }!

        let singleSessionStatuses = engine.recoveryStatus(asOf: checkDate, sessions: [sessions[1]])
        let singleQuad = singleSessionStatuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertLessThan(stackedQuad.recoveryPercent, singleQuad.recoveryPercent)
    }

    func test_recoveryStatus_futureSessionsAreIgnored() {
        let squat = exercise("barbellSquat")
        let futureDate = Date(timeIntervalSince1970: 1_000_000)
        let set = SetEntry(exercise: squat, weightKg: 80, reps: 8, setNumber: 1)
        let session = WorkoutSession(date: futureDate, sets: [set])

        let statuses = engine.recoveryStatus(asOf: Date(timeIntervalSince1970: 0), sessions: [session])
        let quadStatus = statuses.first { $0.muscleGroup == .quadriceps }!

        XCTAssertEqual(quadStatus.recoveryPercent, 100, accuracy: 0.01)
        XCTAssertEqual(quadStatus.status, .ready)
    }
}
```

- [ ] **Step 2: Implement `RecoveryStatus`, `MuscleRecoveryStatus`, and `recoveryStatus(asOf:sessions:)`**

Replace the contents of `MuscleLoadCore/Sources/MuscleLoadCore/RecoveryEngine.swift` with:

```swift
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
```

- [ ] **Step 3: Commit, push, verify CI green**

```bash
git add MuscleLoadCore
git commit -m "$(cat <<'EOF'
Add RecoveryEngine.recoveryStatus with decay, stacking and thresholds

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 8: Final verification

**Files:** none (verification only)

**Interfaces:**
- Consumes: the full `MuscleLoadCore` public API built in Tasks 2–7
- Produces: nothing new — confirms the package is ready to be consumed as a local Swift package dependency in Plan B

- [ ] **Step 1: Confirm the full test suite is green on `main`**

Open `https://github.com/IDVhack/MuscleLoadApp/actions`, find the latest run on `main`, and confirm it is green. It should now be running every test file added in Tasks 2–7 (`MuscleGroupTests`, `MovementPatternCatalogTests`, `ExerciseCatalogTests`, `SetEntryTests`, `RecoveryEngineMomentaryLoadTests`, `RecoveryEngineRecoveryStatusTests`).

- [ ] **Step 2: Spot-check the public API surface matches this plan**

Open `MuscleLoadCore/Sources/MuscleLoadCore/` in the repo and confirm exactly these files exist: `MuscleGroup.swift`, `MovementPattern.swift`, `MovementPatternCatalog.swift`, `Exercise.swift`, `ExerciseCatalog.swift`, `SetEntry.swift`, `WorkoutSession.swift`, `RecoveryEngine.swift`. No leftover placeholder files from Task 1.

- [ ] **Step 3: Note follow-up for Plan B**

Plan B (iOS app shell: Xcode project via XcodeGen, SwiftData persistence, SwiftUI screens, notifications) adds `MuscleLoadCore` as a local Swift package dependency and builds on top of `RecoveryEngine.recoveryStatus(asOf:sessions:)` and `ExerciseCatalog.all` without modifying this package's public API. No action needed here — this task just confirms Plan A is a stable foundation before Plan B starts.

---

## Self-Review

**Spec coverage:** §3 data model → Tasks 2–5. §4 algorithm (raw_load formula, primary/secondary split, fixed recovery windows, thresholds 40/85) → Tasks 6–7. §5 exercise/pattern table (23 exercises, movement-pattern-driven muscle assignment) → Tasks 3–4, with the three pattern splits documented in the plan header note. §9/§10 (out of scope, open questions on thresholds) → explicitly not implemented here, matches spec. Screens (§6), notifications (§7) belong to Plan B, correctly excluded from this plan's scope.

**Placeholder scan:** no TBD/TODO; `fullLoadThreshold` and recovery-status boundary numbers are concrete calibration constants carried over from the spec's own "starting values" framing, not unresolved gaps.

**Type consistency:** `RecoveryEngine.momentaryLoad(for:) -> [MuscleGroup: Double]` (Task 6) is reused unchanged inside `recoveryStatus(asOf:sessions:)` (Task 7). `SetEntry.rawLoad`, `Exercise.movementPattern`, `MovementPattern.heavinessCoefficient/primaryMuscles/secondaryMuscles`, and `MuscleGroup.recoveryWindowHours/fullLoadThreshold` are used with identical names and types across every task that references them — checked against each task's Interfaces block.
