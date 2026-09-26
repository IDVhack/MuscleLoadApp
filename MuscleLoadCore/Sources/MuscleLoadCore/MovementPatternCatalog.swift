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

    /// `secondaryMuscles` is a deliberate union of the spec's two lat-pulldown-grip
    /// variants: wide grip lists [biceps, shoulders], close grip lists [biceps, forearms].
    /// Not split into two patterns because both grips share the same 1.3 coefficient.
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

    public static func pattern(id: String) -> MovementPattern? {
        all.first { $0.id == id }
    }
}
