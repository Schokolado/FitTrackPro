import Foundation

// MARK: - AppStorage Keys
// Centralised to avoid raw string literals scattered across the codebase.

enum AppStorageKeys {
    // MARK: HealthKit
    static let healthKitAutoSync    = "healthkit_auto_sync"       // Bool, default: true

    // MARK: Seeding
    static let hasSeededExercises   = "has_seeded_exercises_v3"   // Bool, default: false

    // MARK: Units
    static let weightUnit           = "weight_unit"               // String: "kg" | "lbs", default: "kg"

    // MARK: Notifications
    static let notificationsEnabled = "notifications_enabled"     // Bool, default: true

    // MARK: Nutrition Goals
    static let targetCalories       = "target_calories"           // Double
    static let targetProtein        = "target_protein"            // Double
    static let targetCarbs          = "target_carbs"              // Double
    static let targetFat            = "target_fat"                // Double

    // MARK: Workout
    static let defaultRestDuration  = "default_rest_duration"     // TimeInterval, default: 90
    static let prefillExerciseHistory = "prefillExerciseHistory"  // Bool, default: true

    // MARK: Rest Timer Favourites
    static let requireRestTimerConfirm = "requireRestTimerConfirm" // Bool, default: true
    static let timerFav1               = "timerFav1"               // Int (seconds), default: 30
    static let timerFav2               = "timerFav2"               // Int (seconds), default: 60
    static let timerFav3               = "timerFav3"               // Int (seconds), default: 90
}
