import Foundation
import SwiftData

@Model
final class SleepEntry {
    var id: UUID = UUID()
    var dateString: String = ""        // "YYYY-MM-DD" (Tag des Aufwachens)
    var bedTime: Date = Date()
    var wakeTime: Date = Date()
    var durationMinutes: Double = 0
    var qualityRaw: String = SleepQuality.unknown.rawValue
    var source: String = "manual"      // "manual" oder "healthkit"
    var healthKitUUID: String?
    
    var quality: SleepQuality {
        get { SleepQuality(rawValue: qualityRaw) ?? .unknown }
        set { qualityRaw = newValue.rawValue }
    }
    
    init(bedTime: Date, wakeTime: Date, durationMinutes: Double, quality: SleepQuality = .unknown, source: String = "manual", healthKitUUID: String? = nil) {
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.durationMinutes = durationMinutes
        self.qualityRaw = quality.rawValue
        self.source = source
        self.healthKitUUID = healthKitUUID
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: wakeTime) // Das Aufwachdatum gilt als Schlaftag
    }
}

enum SleepQuality: String, Codable, CaseIterable {
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .poor: return "Schlecht"
        case .fair: return "Mittel"
        case .good: return "Gut"
        case .excellent: return "Exzellent"
        case .unknown: return "Unbekannt"
        }
    }
}
