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

enum WorkoutPrefillSource: String, CaseIterable {
    case last = "last"
    case highest = "highest"
}

extension Sequence where Element == WorkoutSet {
    /// Selects a reference completed set for `exerciseId` based on the configured prefill mode:
    /// - `.last`: most recent completed set
    /// - `.highest`: highest measured weight (tie-broken by reps, then recency)
    func preferredReferenceSet(for exerciseId: UUID, source: WorkoutPrefillSource) -> WorkoutSet? {
        let completed = self.filter { $0.exercise?.id == exerciseId && $0.isCompleted }
        switch source {
        case .last:
            return completed.max(by: { $0.timestamp < $1.timestamp })
        case .highest:
            return completed.max(by: { a, b in
                if a.actualWeight != b.actualWeight {
                    return a.actualWeight < b.actualWeight
                }
                if a.actualReps != b.actualReps {
                    return a.actualReps < b.actualReps
                }
                return a.timestamp < b.timestamp
            })
        }
    }
}
