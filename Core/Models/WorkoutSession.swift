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

    var plan: TrainingPlan?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?

    init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil, moodRating: Int? = nil, intensityRating: Int? = nil, notes: String = "", syncedToHealthKit: Bool = false, plan: TrainingPlan? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.moodRating = moodRating
        self.intensityRating = intensityRating
        self.notes = notes
        self.syncedToHealthKit = syncedToHealthKit
        self.plan = plan
    }
}
