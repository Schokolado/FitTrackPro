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

enum WorkoutPrefillSource: String, CaseIterable, Identifiable {
    case last = "last"
    case highest = "highest"
    case exerciseDefault = "exerciseDefault"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last:            return "Werte aus letzter Einheit"
        case .highest:         return "Höchster gemessener Wert"
        case .exerciseDefault: return "Standard der Übung (Manuell)"
        }
    }

    var descriptionText: String {
        switch self {
        case .last:
            return "Übernimmt Gewicht und Wiederholungen/Dauer aus deinem zuletzt abgeschlossenen Satz."
        case .highest:
            return "Übernimmt deinen bisher höchsten gemessenen Satz (Bestwert) als Zielwert."
        case .exerciseDefault:
            return "Übernimmt keine Historien-Werte – nutzt Standardwerte (3×10) bzw. deine manuell im Plan eingetragenen Ziele."
        }
    }
}

extension Sequence where Element == WorkoutSet {
    /// Selects a reference completed set for `exerciseId` based on the configured prefill mode:
    /// - `.last`: most recent completed set
    /// - `.highest`: highest measured weight (tie-broken by reps, then recency)
    /// - `.exerciseDefault`: returns `nil` so manual/default exercise values stay untouched
    func preferredReferenceSet(for exerciseId: UUID, source: WorkoutPrefillSource) -> WorkoutSet? {
        guard source != .exerciseDefault else { return nil }
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
        case .exerciseDefault:
            return nil
        }
    }
}
