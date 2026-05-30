import Foundation

// MARK: - ExerciseGroup
// Represents either a single exercise or a group of exercises linked as a superset.

struct ExerciseGroup: Identifiable {
    let id = UUID()
    var exercises: [PlanExercise]
    var supersetGroupId: Int?
}

// MARK: - TrainingPlan + Grouping

extension TrainingPlan {
    /// Returns the plan's exercises sorted by `sortOrder` and grouped into superset blocks.
    var groupedPlanExercises: [ExerciseGroup] {
        let validExercises = (planExercises ?? []).filter { $0.exercise != nil }
        let sorted = validExercises.sorted { $0.sortOrder < $1.sortOrder }
        var groups: [ExerciseGroup] = []
        
        for exercise in sorted {
            // Feature temporarily hidden: ignoring supersetGroup
            groups.append(ExerciseGroup(exercises: [exercise], supersetGroupId: nil))
        }
        
        return groups
    }
}
