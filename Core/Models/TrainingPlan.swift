import Foundation
import SwiftData

@Model
final class TrainingPlan {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.plan)
    var planExercises: [PlanExercise]?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession]?

    init(id: UUID = UUID(), name: String = "", notes: String = "", createdAt: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
