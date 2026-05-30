import Foundation
import SwiftData

@Model
final class PlanExercise {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var supersetGroup: Int?       // nil = kein Supersatz; gleiche Zahl = gleicher Supersatz
    var targetSets: Int = 0
    var targetReps: Int = 0
    var targetWeight: Double?
    var restDuration: TimeInterval = 90.0

    var plan: TrainingPlan?
    var exercise: Exercise?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.planExercise)
    var workoutSets: [WorkoutSet]?

    init(id: UUID = UUID(), sortOrder: Int = 0, supersetGroup: Int? = nil, targetSets: Int = 0, targetReps: Int = 0, targetWeight: Double? = nil, restDuration: TimeInterval = 90.0, plan: TrainingPlan? = nil, exercise: Exercise? = nil) {
        self.id = id
        self.sortOrder = sortOrder
        self.supersetGroup = supersetGroup
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.restDuration = restDuration
        self.plan = plan
        self.exercise = exercise
    }
}
