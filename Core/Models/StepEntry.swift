import Foundation
import SwiftData

@Model
final class StepEntry {
    var id: UUID = UUID()
    var steps: Int = 0
    var dateString: String = "" // ISO8601 string, e.g. "2026-06-07"
    var timestamp: Date = Date()
    var isManual: Bool = true
    
    init(id: UUID = UUID(), steps: Int, date: Date = Date(), isManual: Bool = true) {
        self.id = id
        self.steps = steps
        self.timestamp = date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current
        self.dateString = formatter.string(from: date)
        self.isManual = isManual
    }
}
