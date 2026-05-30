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
    /// When `true` the exercise is hidden from the library and plan selection,
    /// but all historical workout data is preserved.
    var isArchived: Bool = false
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
}
