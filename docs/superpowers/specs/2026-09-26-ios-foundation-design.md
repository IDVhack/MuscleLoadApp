# Plan B1: iOS App Foundation — Design

Дата: 2026-09-26
Статус: согласован, готов к реализации

## 1. Контекст

Plan A построил `MuscleLoadCore` — чистый Swift-пакет с моделью данных и
алгоритмом нагрузки/восстановления (13 групп мышц, 20 шаблонов движения,
23 упражнения, `RecoveryEngine`), смерженный в `main`. Он не зависит от
SwiftUI/SwiftData/UIKit и тестируется на `ubuntu-latest` — доказано в
Plan A.

Plan B — iOS-оболочка поверх него. Из-за объёма (Xcode-проект, хранение,
3 таба с экранами, уведомления) Plan B разбит на два последовательных
под-плана:

- **Plan B1 (этот документ)** — фундамент: Xcode-проект, CI на macOS,
  SwiftData-слой хранения, каркас навигации без реальных экранов.
- **Plan B2 (следующий)** — сами экраны (карта восстановления, конструктор
  тренировки, справочник упражнений, история/статистика) и уведомления.

Ссылки: [спека приложения](2026-09-25-muscle-load-app-design.md),
[план и реализация MuscleLoadCore](../plans/2026-09-25-muscle-load-core-engine.md).

## 2. Окружение и ограничения

- Разработка ведётся на Windows, без Mac и без Xcode. Всё, что требует
  сборки/тестирования на Apple-платформе, верифицируется через
  GitHub Actions на раннере `macos-14` — так же, как MuscleLoadCore
  верифицировался на `ubuntu-latest` в Plan A.
- `.xcodeproj` не редактируется и не коммитится руками — генерируется в CI
  инструментом XcodeGen из текстового `project.yml`, который живёт в репо
  и редактируется как обычный файл.
- iOS 17+, SwiftUI, только локальное хранение (SwiftData), без сети и
  аккаунтов — согласовано в исходной спеке приложения.

## 3. Аддитивные правки MuscleLoadCore

Финальное ревью Plan A обнаружило: слой хранения должен уметь
восстанавливать `Exercise`/`MovementPattern` по id (пользователь выбирает
готовый шаблон для своего упражнения; тренировки хранят id упражнения, а
не сам объект). Сейчас у каталогов есть только `.all`. Добавляем:

```swift
// MovementPatternCatalog
public static func pattern(id: String) -> MovementPattern? {
    all.first { $0.id == id }
}

// ExerciseCatalog
public static func exercise(id: String) -> Exercise? {
    all.first { $0.id == id }
}
```

Чисто аддитивно, не меняет существующий публичный API, тестируется в уже
настроенном CI-пайплайне MuscleLoadCore (`ubuntu-latest`, `swift test`).
Это первая задача плана — до неё Xcode-часть строить нет смысла.

## 4. Xcode-проект и CI

`project.yml` (XcodeGen) в корне репозитория:

- Таргет `MuscleLoadApp` — iOS-приложение, SwiftUI lifecycle, iOS 17+,
  локальная зависимость на Swift-пакет `MuscleLoadCore` (`path:
  MuscleLoadCore`).
- Таргет `MuscleLoadAppTests` — unit-тесты (SwiftData-модели, слой-мост
  к MuscleLoadCore).

`.github/workflows/app-ci.yml`: раннер `macos-14`, шаги — checkout, выбор
самой новой установленной Xcode (нужна раннеру, чтобы открыть проект в
формате, который генерирует свежий XcodeGen), установка XcodeGen
(`brew install xcodegen`), `xcodegen generate`, динамический выбор
доступного симулятора iPhone через `xcrun simctl` (жёстко заданное имя
модели не гарантированно существует на раннере), затем `xcodebuild test
-scheme MuscleLoadApp -destination "platform=iOS Simulator,name=$DEVICE"`.
Обнаружено и закреплено при реализации Plan B1 (Task 2) — детали в
[плане](../plans/2026-09-26-ios-foundation.md).

## 5. Хранение (SwiftData)

- **`WorkoutSessionRecord`** (`@Model`) — id, date, duration
  (`TimeInterval`), perceivedEffort (`Int?`), связь с `SetEntryRecord`.
  Поле `duration` намеренно живёт здесь, а не в `MuscleLoadCore.
  WorkoutSession` — движку оно не нужно для расчёта, а экрану итога
  тренировки нужно.
- **`SetEntryRecord`** (`@Model`) — id, `exerciseID: String`, weightKg,
  reps, setNumber, связь с сессией. Хранит **id** упражнения, а не сам
  объект — так будущая калибровка коэффициентов в каталоге применится и к
  уже сохранённым тренировкам при пересчёте.
- **`CustomExerciseRecord`** (`@Model`) — id, name, `movementPatternID:
  String`, techniqueDescription?, imageAssetName?. Только упражнения,
  которые добавил сам пользователь — 23 встроенных не дублируются в БД,
  они уже есть в `ExerciseCatalog.all`.
- **`UserProfileRecord`** (`@Model`) — bodyweightKg (`Double?`),
  notificationsEnabled (`Bool`). Одна запись на пользователя.

**Слой-мост (`WorkoutRepository`)** — единственное место, которое знает
и про SwiftData, и про MuscleLoadCore:

- `resolveExercise(id:) -> MuscleLoadCore.Exercise?` — сперва
  `ExerciseCatalog.exercise(id:)`, если нет — ищет `CustomExerciseRecord`
  и собирает `Exercise` через `MovementPatternCatalog.pattern(id:)`.
- `currentRecoveryStatuses(asOf: Date) -> [MuscleRecoveryStatus]` —
  достаёт все `WorkoutSessionRecord`, конвертирует в
  `MuscleLoadCore.WorkoutSession` (через `resolveExercise`), зовёт
  `RecoveryEngine().recoveryStatus(asOf:sessions:)`.

## 6. Вес тела для упражнений на своём весе

Подтягивания, отжимания и пресс (`pullUp`, `pushUp`, `crunch`) с нулевым
добавленным весом дают `rawLoad = 0` по формуле MuscleLoadCore — такая
тренировка не нагрузит мышцы на карте. Решение: MuscleLoadCore не
меняется (`weightKg` остаётся «эффективным весом», пакет не знает о
разнице между штангой и собственным телом). В приложении заводим
константу:

```swift
let bodyweightExerciseIDs: Set<String> = ["pullUp", "pushUp", "crunch"]
```

При выборе такого упражнения в конструкторе тренировки (Plan B2) поле
веса предзаполняется значением `UserProfileRecord.bodyweightKg` —
пользователь может оставить как есть или добавить утяжеление сверху.

## 7. Навигация (каркас, без контента)

`TabView` на 3 таба — Главная, Тренировки, Упражнения — каждый с
временной заглушкой (`Text`). Реальные экраны строит Plan B2. Цель Plan
B1 — компилируемое, тестируемое приложение с рабочим хранением, без фич.

## 8. Тестирование

- MuscleLoadCore: `swift test` на `ubuntu-latest`, как в Plan A — новые
  функции каталогов тестируются там же.
- SwiftData-слой и `WorkoutRepository`: `XCTest` в
  `MuscleLoadAppTests`, выполняется через `xcodebuild test` на
  `macos-14` с симулятором в CI — проверить локально без Mac нельзя,
  каждый прогон верифицируется в браузере (как в Plan A) вместо
  доверия отчёту исполнителя.

## 9. Вне скоупа Plan B1

Сами экраны, конструктор тренировки, справочник упражнений, история/
статистика, уведомления — всё это Plan B2. Онбординг (запрос веса тела)
в Plan B1 не строим — `UserProfileRecord.bodyweightKg` может быть `nil`
до Plan B2, где появится реальный UI для его ввода.
