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
    static let onboardingWeightKg       = "onboarding_weight_kg"         // Double, default: 0

    // Dashboard-Ziele
    static let dailyCalorieGoal         = "dailyCalorieGoal"             // Double, default: 2500
    static let dailyStepGoal            = "daily_step_goal"              // Int, default: 10000
    static let dailyWaterGoalML         = "dailyWaterGoalML"             // Double
    static let dailySleepGoalHours      = "dailySleepGoalHours"          // Double
    
    // Wasser Presets
    static let waterQuickAddPreset1     = "waterQuickAddPreset1"         // Double
    static let waterQuickAddPreset2     = "waterQuickAddPreset2"         // Double
    static let waterQuickAddPreset3     = "waterQuickAddPreset3"         // Double

    static let targetWeightKg           = "target_weight_kg"             // Double, default: 0 (disabled)
}

import Combine

/// A service to synchronize key user preferences between local UserDefaults and iCloud NSUbiquitousKeyValueStore.
@MainActor
class CloudProfileService {
    static let shared = CloudProfileService()
    
    private let store = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    
    // The keys we want to sync
    private let stringKeys = [
        AppStorageKeys.userName,
        AppStorageKeys.userBiologicalSex
    ]
    
    private let doubleKeys = [
        AppStorageKeys.userBirthDate,
        AppStorageKeys.userHeightCm,
        AppStorageKeys.onboardingWeightKg,
        AppStorageKeys.dailyCalorieGoal,
        "nutritionGoalProtein",
        "nutritionGoalCarbs",
        "nutritionGoalFat"
    ]
    
    private let intKeys = [
        AppStorageKeys.dailyStepGoal
    ]
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        // Background synchronize to avoid blocking main thread
        Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    /// Checks if a profile exists in iCloud by looking for a saved username.
    func hasCloudProfile() -> Bool {
        if let name = store.string(forKey: AppStorageKeys.userName), !name.isEmpty {
            return true
        }
        return false
    }
    
    /// Pushes local UserDefaults values to iCloud Key-Value store.
    func pushLocalToCloud() {
        for key in stringKeys {
            if let val = local.string(forKey: key) {
                store.set(val, forKey: key)
            }
        }
        
        for key in doubleKeys {
            var val = local.double(forKey: key)
            if val == 0 {
                if key == AppStorageKeys.dailyCalorieGoal { val = 2500 }
                else if key == "nutritionGoalProtein" { val = 150 }
                else if key == "nutritionGoalCarbs" { val = 250 }
                else if key == "nutritionGoalFat" { val = 70 }
                else if key == AppStorageKeys.userHeightCm { val = 175 }
            }
            if val > 0 { // Avoid pushing default 0 values if not set
                store.set(val, forKey: key)
            }
        }
        
        for key in intKeys {
            var val = local.integer(forKey: key)
            if val == 0 && key == AppStorageKeys.dailyStepGoal { val = 10000 }
            if val > 0 {
                store.set(val, forKey: key)
            }
        }
        
        Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    /// Pulls values from iCloud Key-Value store and saves them to local UserDefaults.
    func pullCloudToLocal() {
        for key in stringKeys {
            if let val = store.string(forKey: key) {
                local.set(val, forKey: key)
            }
        }
        
        for key in doubleKeys {
            let val = store.double(forKey: key)
            if val > 0 {
                local.set(val, forKey: key)
            }
        }
        
        for key in intKeys {
            let val = Int(store.longLong(forKey: key))
            if val > 0 {
                local.set(val, forKey: key)
            }
        }
    }
    
    /// Called when iCloud data changes on another device.
    @objc private func storeDidChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }
        
        if reasonForChange == NSUbiquitousKeyValueStoreServerChange || reasonForChange == NSUbiquitousKeyValueStoreInitialSyncChange {
            guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
            
            // For simplicity, if any known key changed, just pull everything to local
            let allKnownKeys = stringKeys + doubleKeys + intKeys
            if !Set(changedKeys).isDisjoint(with: allKnownKeys) {
                pullCloudToLocal()
            }
        }
    }
    
    // Helpers to get specific cloud values for the Welcome Back screen
    func getCloudName() -> String {
        return store.string(forKey: AppStorageKeys.userName) ?? ""
    }
    
    func getCloudHeight() -> Double {
        let val = store.double(forKey: AppStorageKeys.userHeightCm)
        return val > 0 ? val : 175
    }
    
    func getCloudWeight() -> Double {
        return store.double(forKey: AppStorageKeys.onboardingWeightKg)
    }
    
    func getCloudCalorieGoal() -> Double {
        let val = store.double(forKey: AppStorageKeys.dailyCalorieGoal)
        return val > 0 ? val : 2500
    }
    
    func getCloudStepGoal() -> Int {
        let val = Int(store.longLong(forKey: AppStorageKeys.dailyStepGoal))
        return val > 0 ? val : 10000
    }
    
    func getCloudBirthday() -> Double {
        return store.double(forKey: AppStorageKeys.userBirthDate)
    }
    
    func getCloudProtein() -> Double {
        let val = store.double(forKey: "nutritionGoalProtein")
        return val > 0 ? val : 150
    }
    
    func getCloudCarbs() -> Double {
        let val = store.double(forKey: "nutritionGoalCarbs")
        return val > 0 ? val : 250
    }
    
    func getCloudFat() -> Double {
        let val = store.double(forKey: "nutritionGoalFat")
        return val > 0 ? val : 70
    }
}
