import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var moodRating: Int?        // 1-5
    var intensityRating: Int?   // 1-5
    var notes: String = ""
    var syncedToHealthKit: Bool = false
    var burnedCalories: Double?
    var averageHeartRate: Double?
    var calorieSource: String?

    var plan: TrainingPlan?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?

    init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil, moodRating: Int? = nil, intensityRating: Int? = nil, notes: String = "", syncedToHealthKit: Bool = false, burnedCalories: Double? = nil, averageHeartRate: Double? = nil, calorieSource: String? = nil, plan: TrainingPlan? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.moodRating = moodRating
        self.intensityRating = intensityRating
        self.notes = notes
        self.syncedToHealthKit = syncedToHealthKit
        self.burnedCalories = burnedCalories
        self.averageHeartRate = averageHeartRate
        self.calorieSource = calorieSource
        self.plan = plan
    }
}
