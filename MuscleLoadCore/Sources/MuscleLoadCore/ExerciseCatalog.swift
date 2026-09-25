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
