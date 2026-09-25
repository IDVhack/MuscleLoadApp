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
