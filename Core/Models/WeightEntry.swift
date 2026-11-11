import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var weightKg: Double = 0.0
    var bodyFatPercent: Double?
    var waistCm: Double?
    var timestamp: Date = Date()
    var notes: String = ""
    var syncedToHealthKit: Bool = false
    
    init(
        id: UUID = UUID(),
        weightKg: Double = 0.0,
        bodyFatPercent: Double? = nil,
        waistCm: Double? = nil,
        timestamp: Date = Date(),
        notes: String = "",
        syncedToHealthKit: Bool = false
    ) {
        self.id = id
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.waistCm = waistCm
        self.timestamp = timestamp
        self.notes = notes
        self.syncedToHealthKit = syncedToHealthKit
    }
}
