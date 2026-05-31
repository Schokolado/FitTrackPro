import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, CaseIterable {
    case machine        = "Maschinen"
    case freeWeight     = "Freie Gewichte"
    case cable          = "Kabelzug"
    case bodyweight     = "Eigengewicht"
}

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = "Freie Gewichte"
    var notes: String = ""
    var externalVideoURL: URL?
    var localMediaPaths: [String] = []
    var defaultRestDuration: TimeInterval = 90.0
    var isCustom: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \PlanExercise.exercise)
    var planExercises: [PlanExercise]?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.exercise)
    var workoutSets: [WorkoutSet]?

    init(id: UUID = UUID(), name: String = "", category: String = "Freie Gewichte", notes: String = "", externalVideoURL: URL? = nil, localMediaPaths: [String] = [], defaultRestDuration: TimeInterval = 90.0, isCustom: Bool = false, sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.notes = notes
        self.externalVideoURL = externalVideoURL
        self.localMediaPaths = localMediaPaths
        self.defaultRestDuration = defaultRestDuration
        self.isCustom = isCustom
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    /// Deletes the exercise, cascades to PlanExercises, and resolves superset relationships.
    func deleteCascading(in context: ModelContext) {
        let linkedPlanExercises = self.planExercises ?? []
        for planEx in linkedPlanExercises {
            if let plan = planEx.plan {
                if let groupId = planEx.supersetGroup {
                    let others = plan.planExercises?.filter { $0.id != planEx.id && $0.supersetGroup == groupId } ?? []
                    // If only 1 other exercise is left in the superset, break the superset
                    if others.count == 1, let remaining = others.first {
                        remaining.supersetGroup = nil
                    }
                }
                // Explicitly remove from the plan's array so the UI updates and SwiftData registers it
                plan.planExercises?.removeAll { $0.id == planEx.id }
            }
            context.delete(planEx)
        }
        context.delete(self)
        try? context.save()
    }
}

import SwiftUI

extension Exercise {
    var themeColor: Color {
        switch category.lowercased() {
        case "brust", "chest": return .blue
        case "rücken", "back": return .indigo
        case "beine", "legs": return .orange
        case "schultern", "shoulders": return .purple
        case "arme", "arms": return .cyan
        case "bauch / core", "abs / core", "bauch": return .green
        case "cardio": return .red
        case "ganzkörper", "full body": return .mint
        default: return .gray
        }
    }
    
    var themeIcon: String {
        switch category.lowercased() {
        case "cardio": return "figure.run"
        case "beine", "legs": return "figure.walk" // Fallback since no custom icon
        case "ganzkörper", "full body": return "figure.mixed.cardio" // Fallback since no custom icon
        default: return "dumbbell.fill"
        }
    }
    
    var customIconName: String? {
        return nil
    }
}
