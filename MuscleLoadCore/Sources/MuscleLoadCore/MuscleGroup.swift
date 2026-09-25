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
