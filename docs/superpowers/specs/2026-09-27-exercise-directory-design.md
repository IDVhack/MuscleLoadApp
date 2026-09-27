# Plan B3: Справочник упражнений + свои упражнения — Design

Дата: 2026-09-27
Статус: согласован, готов к реализации

## 1. Контекст

Plan B2 закрыл основной цикл (тренировка → карта восстановления) с
минимальным выбором упражнения: `ExerciseCatalog.all` (23 встроенных) без
поиска по мышце, без своих упражнений, без техники и картинок — это было
явно отложено на Plan B3 (см. [дизайн Plan B2](2026-09-26-core-loop-design.md)
§6). Plan B3 закрывает третий таб приложения («Упражнения»), который сейчас
заглушка (`Text("Упражнения")` в `RootTabView`).

Инфраструктура для своих упражнений уже заложена в Plan B1 и не требует
изменений в `MuscleLoadCore`:
- `Exercise.isBuiltIn: Bool` отличает встроенные от своих.
- `CustomExerciseRecord` (`@Model`) хранит `name` + `movementPatternID` —
  своё упражнение это просто имя, привязанное к одному из 20 существующих
  `MovementPatternCatalog` (готовая мышечная разметка и коэффициент
  тяжести), а не свободный ввод мышц.
- `WorkoutRepository.resolveExercise(id:)` уже умеет рехайдрировать и
  встроенные, и свои упражнения в `Exercise` — `RecoveryEngine` не видит
  разницы между источниками.

Также обнаружено (не было в исходной спеке приложения на момент Plan B2):
готовый набор из 23 PNG-иллюстраций техники для всех встроенных
упражнений лежит в `image/exercises/` (вне git), пронумерован 01–23 в том
же порядке, что и `ExerciseCatalog.all`. Plan B3 включает их подключение.

Ссылки: [спека приложения](2026-09-25-muscle-load-app-design.md) (§ про
таб «Упражнения»), [дизайн Plan B2](2026-09-26-core-loop-design.md).

## 2. Окружение

Без изменений от Plan B1/B2: разработка на Windows без Mac, вся
верификация через `MuscleLoadApp CI` (`macos-14`) и `MuscleLoadCore CI`
(`ubuntu-latest`) в GitHub Actions, проверяется вручную через браузер по
реальному запуску, а не на слово агента.

## 3. Слияние встроенных и своих упражнений

Новый метод `WorkoutRepository.allExercises() throws -> [Exercise]`:
`ExerciseCatalog.all` + все `CustomExerciseRecord` из контекста,
рехайдрированные через тот же путь, что уже использует `resolveExercise`
(общий приватный хелпер `exercise(from record: CustomExerciseRecord) ->
Exercise?`, чтобы не дублировать логику). Результат отсортирован по
`name`. Это единственная точка, где справочник, форма создания/
редактирования и пикер в конструкторе тренировки берут список упражнений
— ни одно View не работает с `CustomExerciseRecord`/SwiftData напрямую,
только с типом `Exercise` из `MuscleLoadCore`. Решение принято, чтобы не
заводить второй мост между слоями (правило из Plan B2: `WorkoutRepository`
остаётся единственным типом, импортирующим и `SwiftData`, и
`MuscleLoadCore`).

Новые операции над своими упражнениями, там же:
- `createCustomExercise(name: String, movementPatternID: String, techniqueDescription: String?) throws -> Exercise`
- `updateCustomExercise(id: String, name: String, movementPatternID: String, techniqueDescription: String?) throws`
  — не имеет смысла для встроенного id; вызывающая сторона (форма) никогда
  не вызывает его для `isBuiltIn == true` упражнений, отдельная защита в
  репозитории не добавляется (UI не даёт такой возможности).
- `deleteCustomExercise(id: String) throws` — сначала проверяет, есть ли
  хоть один `SetEntryRecord.exerciseID == id` (`FetchDescriptor` с
  `#Predicate`, `fetchLimit = 1` достаточно); если да — бросает
  `WorkoutRepositoryError.exerciseInUse` вместо удаления записи. Так
  выбрано намеренно: экрана истории тренировок ещё нет (Plan B4), поэтому
  тихая порча уже сохранённых подходов (drop-unresolvable, как сейчас
  работает `currentRecoveryStatuses`) была бы незаметна пользователю и
  необратима — блокировка удаления безопаснее для v1.

`WorkoutRepositoryError: Error { case exerciseInUse }` — новый тип ошибки,
единственный в файле (сейчас `throws` использовался только для
проброса ошибок SwiftData).

## 4. Экран «Упражнения» — справочник

**`ExerciseDirectoryViewModel`** (`MuscleLoadApp/Features/ExerciseDirectory/`):
- `@Observable`, хранит `allExercises: [Exercise]` (из
  `WorkoutRepository.allExercises()`), `searchText: String`,
  `selectedMuscle: MuscleGroup?` (`nil` = «Все»).
- `filteredExercises: [Exercise]` — вычисляемое свойство: подстрока
  `searchText` в `name` (без учёта регистра) И (`selectedMuscle == nil`
  ИЛИ `selectedMuscle` есть в `movementPattern.primaryMuscles`) — фильтр
  по **основной** мышце, один выбор одновременно (не мультивыбор, не по
  вторичным мышцам — решение согласовано в диалоге).
- `load()` вызывает `repository.allExercises()`.

**`ExerciseDirectoryView`**: `List` с `.searchable(text:)`, строка фильтра
по мышце сверху (горизонтальный ряд/меню — 13 вариантов + «Все»), каждая
строка — имя + короткий бейдж «своё» для `!isBuiltIn`. Тап → `ExerciseDetailView`.
Кнопка «+» в тулбаре открывает `ExerciseFormView` в режиме создания
(sheet).

**`ExerciseDetailView`**: картинка (`Image(exercise.imageAssetName)`, если
не `nil`, иначе плейсхолдер `systemImage`), название, список основных и
вторичных мышц (`MuscleGroup.displayName`), текст техники (если есть). Для
`!exercise.isBuiltIn` — кнопки Edit (открывает `ExerciseFormView` в режиме
редактирования, предзаполненную) и Delete. Delete вызывает
`deleteCustomExercise`; при `exerciseInUse` — алерт «Упражнение
используется в сохранённой тренировке и не может быть удалено», запись не
трогается.

**`ExerciseFormView`**: одна форма на создание и редактирование (как
`SetEntrySheet` в Plan B2 — без отдельной ViewModel, работает через
`WorkoutRepository` напрямую из View). Поля: имя (`TextField`, обязательное
— Save недоступен при пустой/пробельной строке), выбор шаблона движения
(плоский `List` из `MovementPatternCatalog.all`, 20 штук, отсортирован по
имени — без группировки по мышце ради простоты v1), опциональное
многострочное описание техники. Дубликаты имён не проверяются (id всё
равно уникален по UUID, это не критично для v1).

## 5. Картинки встроенных упражнений

`MuscleLoadApp/App/Assets.xcassets` создаётся файлами напрямую (без
Xcode, т.к. разработка на Windows): корневой `Contents.json` + один
imageset на упражнение (`Contents.json` + PNG), имя ассета = `id`
упражнения (`barbellSquat`, `pullUp`, ...). Источник — 23 PNG из
`image/exercises/` (порядок 01–23 совпадает с порядком `ExerciseCatalog.all`).
XcodeGen подхватывает `.xcassets`-папки как ресурсы автоматически внутри
уже существующего `sources: MuscleLoadApp/App`, отдельная запись в
`project.yml` не нужна.

`ExerciseCatalog.all` — для каждой из 23 записей проставляется
`imageAssetName: "<id>"` и короткое (1 предложение) `techniqueDescription`
на русском, авторства модели-исполнителя (в исходных данных текстов
техники не было, только картинки — решение согласовано в диалоге:
писать самим). У своих упражнений `imageAssetName` остаётся `nil` в этом
плане — фото для своих упражнений не входит в v1 (согласовано в диалоге).

## 6. Интеграция с конструктором тренировки

`ExercisePickerView` (Plan B2) сейчас берёт список из `ExerciseCatalog.all`
напрямую. Меняется на `WorkoutRepository.allExercises()`, загружаемый при
появлении экрана — иначе создание своих упражнений было бы бессмысленным
(их нельзя залогировать в тренировке). Текстовый поиск по подстроке имени
сохраняется без изменений. `WorkoutBuilderViewModel` и `SetEntrySheet` не
меняются — они уже работают с типом `Exercise` независимо от источника.

## 7. `RootTabView`

Третий таб (сейчас `Text("Упражнения")`) заменяется на
`ExerciseDirectoryView(modelContext: modelContext)`.

## 8. Вне скоупа Plan B3

Фото для своих упражнений, мультивыбор/фильтр по вторичным мышцам,
проверка на дублирующиеся имена, группировка списка шаблонов движения по
мышце в форме создания, история тренировок и статистика, уведомления —
Plan B4 или явно принятое упрощение (см. §3–5).

## 9. Тестирование

- `WorkoutRepositoryTests`: `allExercises()` возвращает 23 + N своих;
  `createCustomExercise` персистит и возвращает корректный `Exercise`;
  `updateCustomExercise` меняет поля существующей записи;
  `deleteCustomExercise` удаляет неиспользуемую запись и бросает
  `exerciseInUse`, если на неё ссылается `SetEntryRecord` (запись при этом
  не удаляется).
- `ExerciseDirectoryViewModelTests`: фильтрация по тексту, по мышце,
  комбинация обоих фильтров, пустой результат.
- Экраны (`ExerciseDirectoryView`, `ExerciseDetailView`, `ExerciseFormView`)
  без отдельных unit-тестов — как и в Plan B2, корректность верифицируется
  сборкой в CI поверх уже покрытой тестами логики репозитория и ViewModel.
