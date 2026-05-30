import Foundation
import SwiftData
import os

// MARK: - ExerciseService

/// Handles business logic for Exercise lifecycle operations.
/// Using a service avoids duplicating archive/delete logic across views.
@MainActor
final class ExerciseService {

    static let shared = ExerciseService()
    private init() {}

    // MARK: - Archive

    /// Archives an exercise (soft delete).
    ///
    /// - Sets `isArchived = true` so the exercise disappears from the library and plan selection.
    /// - Removes all associated `PlanExercise` entries from every training plan (cascade-style).
    /// - Preserves all `WorkoutSet` history so statistics remain intact.
    ///
    /// - Parameters:
    ///   - exercise: The exercise to archive.
    ///   - context: The active `ModelContext`.
    func archive(_ exercise: Exercise, in context: ModelContext) {
        // Remove from all training plans
        let linkedPlanExercises = exercise.planExercises ?? []
        for planExercise in linkedPlanExercises {
            context.delete(planExercise)
        }

        exercise.isArchived = true

        do {
            try context.save()
            AppLogger.data.info("Archived exercise: \(exercise.name)")
        } catch {
            AppLogger.data.error("Failed to archive exercise '\(exercise.name)': \(error)")
        }
    }

    /// Returns how many training plans currently contain this exercise.
    func planCount(for exercise: Exercise) -> Int {
        (exercise.planExercises ?? []).count
    }
}
