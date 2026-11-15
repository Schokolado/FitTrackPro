import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, CaseIterable {
    case machine        = "Maschinen"
    case freeWeight     = "Freie Gewichte"
    case cable          = "Kabelzug"
    case bodyweight     = "Eigengewicht"
    case mobility       = "Mobilität"
    case cardio         = "Cardio"
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
    var isArchived: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var isTimeBased: Bool = false
    var timeUnit: String = "Min"
    var tracksWeightForTimeBased: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \PlanExercise.exercise)
    var planExercises: [PlanExercise]?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.exercise)
    var workoutSets: [WorkoutSet]?

    init(id: UUID = UUID(), name: String = "", category: String = "Freie Gewichte", notes: String = "", externalVideoURL: URL? = nil, localMediaPaths: [String] = [], defaultRestDuration: TimeInterval = 90.0, isCustom: Bool = false, isArchived: Bool = false, sortOrder: Int = 0, createdAt: Date = Date(), isTimeBased: Bool = false, timeUnit: String = "Min", tracksWeightForTimeBased: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.notes = notes
        self.externalVideoURL = externalVideoURL
        self.localMediaPaths = localMediaPaths
        self.defaultRestDuration = defaultRestDuration
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isTimeBased = isTimeBased
        self.timeUnit = timeUnit
        self.tracksWeightForTimeBased = tracksWeightForTimeBased
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
    var isCardioExercise: Bool {
        category.lowercased() == "cardio"
    }

    var usesTimeInput: Bool {
        isTimeBased || isCardioExercise
    }

    var effectiveTimeUnit: String {
        if !timeUnit.isEmpty && timeUnit != "Wdh" {
            return timeUnit
        }
        return isCardioExercise ? "Min" : "Sek"
    }

    var usesLevelInput: Bool {
        isCardioExercise
    }

    var usesWeightInput: Bool {
        !isCardioExercise && (!isTimeBased || tracksWeightForTimeBased)
    }

    var showsSecondaryInput: Bool {
        usesLevelInput || usesWeightInput
    }

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
        case "mobilität", "mobility": return .teal
        default: return .gray
        }
    }
    
    var themeIcon: String {
        switch category.lowercased() {
        case "brust", "chest": return "figure.strengthtraining.traditional"
        case "rücken", "back": return "figure.rowing"
        case "beine", "legs": return "figure.step.training"
        case "schultern", "shoulders": return "figure.arms.open"
        case "arme", "arms": return "dumbbell.fill"
        case "bauch / core", "abs / core", "bauch": return "figure.core.training"
        case "cardio": return "figure.run"
        case "ganzkörper", "full body": return "figure.highintensity.intervaltraining"
        case "mobilität", "mobility": return "figure.flexibility"
        default: return "dumbbell.fill"
        }
    }
    
    var customIconName: String? {
        switch category.lowercased() {
        case "brust", "chest": return "IconChest"
        case "rücken", "back": return "IconBack"
        case "beine", "legs": return "IconLegs"
        case "schultern", "shoulders": return "IconShoulders"
        case "arme", "arms": return "IconArms"
        case "bauch / core", "abs / core", "bauch": return "IconAbs"
        case "cardio": return "IconCardio"
        case "ganzkörper", "full body": return "IconFullBody"
        case "mobilität", "mobility": return "IconMobility"
        default: return nil
        }
    }
}
