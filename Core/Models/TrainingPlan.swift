import Foundation
import SwiftData

enum PlanFocus: String, CaseIterable, Identifiable, Codable {
    case auto = "Automatisch"
    case fullBody = "Ganzkörper"
    case upperBody = "Oberkörper"
    case lowerBody = "Unterkörper / Beine"
    case push = "Push (Druck)"
    case pull = "Pull (Zug)"
    case mobility = "Mobilität"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .auto:      return "Auto"
        case .fullBody:  return "Ganzkörper"
        case .upperBody: return "Oberkörper"
        case .lowerBody: return "Beine"
        case .push:      return "Push"
        case .pull:      return "Pull"
        case .mobility:  return "Mobilität"
        }
    }
}

@Model
final class TrainingPlan {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var focusRawValue: String = PlanFocus.auto.rawValue

    var focus: PlanFocus {
        get { PlanFocus(rawValue: focusRawValue) ?? .auto }
        set { focusRawValue = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.plan)
    var planExercises: [PlanExercise]?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession]?
    
    @Relationship(deleteRule: .nullify)
    var group: PlanGroup?

    init(
        id: UUID = UUID(),
        name: String = "",
        notes: String = "",
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        focusRawValue: String = PlanFocus.auto.rawValue,
        group: PlanGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.focusRawValue = focusRawValue
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
