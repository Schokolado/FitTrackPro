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
    
    @Relationship(deleteRule: .nullify)
    var group: PlanGroup?

    init(id: UUID = UUID(), name: String = "", notes: String = "", createdAt: Date = Date(), sortOrder: Int = 0, group: PlanGroup? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.group = group
    }
}

@Model
final class PlanGroup {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \TrainingPlan.group)
    var plans: [TrainingPlan]?
    
    init(id: UUID = UUID(), name: String = "", sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
