import Foundation
import SwiftData

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var amountML: Double = 0
    var timestamp: Date = Date()
    var dateString: String = ""  // "YYYY-MM-DD" für Tagesgruppierung
    
    init(amountML: Double, timestamp: Date = Date()) {
        self.amountML = amountML
        self.timestamp = timestamp
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: timestamp)
    }
}
