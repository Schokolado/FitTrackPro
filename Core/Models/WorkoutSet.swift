import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var setNumber: Int = 1
    var actualWeight: Double = 0.0
    var actualReps: Int = 0
    var isCompleted: Bool = false
    var timestamp: Date = Date()

    var session: WorkoutSession?
    var exercise: Exercise?
    var planExercise: PlanExercise? // Um zu wissen, welcher Soll-Wert zugrunde lag

    init(id: UUID = UUID(), setNumber: Int = 1, actualWeight: Double = 0.0, actualReps: Int = 0, isCompleted: Bool = false, timestamp: Date = Date(), session: WorkoutSession? = nil, exercise: Exercise? = nil, planExercise: PlanExercise? = nil) {
        self.id = id
        self.setNumber = setNumber
        self.actualWeight = actualWeight
        self.actualReps = actualReps
        self.isCompleted = isCompleted
        self.timestamp = timestamp
        self.session = session
        self.exercise = exercise
        self.planExercise = planExercise
    }
}
