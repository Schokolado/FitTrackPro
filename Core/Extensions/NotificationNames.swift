import Foundation

// MARK: - App Notification Names
// Centralised to avoid magic strings scattered across the codebase.

extension Notification.Name {
    /// Posted when a workout summary is saved or discarded,
    /// signalling the parent `WorkoutSessionView` to dismiss itself.
    static let workoutFinished = Notification.Name("com.fittrackpro.workoutFinished")
}
