import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID = UUID()
    var dateString: String = "" // ISO 8601 "YYYY-MM-DD" für einfaches Querying
    var waterIntakeML: Double = 0.0

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.dailyLog)
    var foodEntries: [FoodEntry]?

    init(id: UUID = UUID(), dateString: String = "", waterIntakeML: Double = 0.0) {
        self.id = id
        self.dateString = dateString
        self.waterIntakeML = waterIntakeML
    }
}
