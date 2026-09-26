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
