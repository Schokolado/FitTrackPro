import Foundation

enum AppStorageKeys {
    static let healthKitAutoSync        = "healthkit_auto_sync"          // Bool, default: true
    static let healthKitEnabled         = "healthkit_enabled"            // Bool, default: true
    static let hasSeededExercises       = "has_seeded_exercises_v3"      // Bool, default: false
    static let weightUnit               = "weight_unit"                  // String: "kg" | "lbs", default: "kg"
    static let notificationsEnabled     = "notifications_enabled"        // Bool, default: true
    static let prefillExerciseHistory   = "prefillExerciseHistory"       // Bool, default: true
    static let targetCalories           = "target_calories"              // Double
    static let targetProtein            = "target_protein"               // Double
    static let targetCarbs              = "target_carbs"                 // Double
    static let targetFat                = "target_fat"                   // Double
    static let defaultRestDuration      = "default_rest_duration"        // TimeInterval, default: 90

    // Onboarding & Profil
    static let hasCompletedOnboarding   = "has_completed_onboarding"     // Bool, default: false
    static let userName                 = "userName"                     // String, default: ""
    static let userBirthDate            = "user_birth_date"              // Double (timeIntervalSince1970)
    static let userBiologicalSex        = "user_biological_sex"          // String: "male"|"female"|"other"
    static let userHeightCm             = "user_height_cm"               // Double, default: 175

    // Dashboard-Ziele
    static let dailyCalorieGoal         = "dailyCalorieGoal"             // Double, default: 2500
    static let dailyStepGoal            = "daily_step_goal"              // Int, default: 10000
    static let targetWeightKg           = "target_weight_kg"             // Double, default: 0 (disabled)
}
