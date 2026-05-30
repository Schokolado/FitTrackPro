import Foundation

enum AppStorageKeys {
    static let healthKitAutoSync    = "healthkit_auto_sync"       // Bool, default: true
    static let hasSeededExercises   = "has_seeded_exercises"      // Bool, default: false
    static let weightUnit           = "weight_unit"               // String: "kg" | "lbs", default: "kg"
    static let notificationsEnabled = "notifications_enabled"     // Bool, default: true
    static let targetCalories       = "target_calories"           // Double
    static let targetProtein        = "target_protein"            // Double
    static let targetCarbs          = "target_carbs"              // Double
    static let targetFat            = "target_fat"                // Double
    static let defaultRestDuration  = "default_rest_duration"     // TimeInterval, default: 90
}
