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
