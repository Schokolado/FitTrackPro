import Foundation

struct EnergyResult {
    let currentEnergy: Int
    let morningCapacity: Int
    let sleepPoints: Int
    let recoveryPoints: Int
    
    let passiveDrain: Int
    let stepsDrain: Int
    let workoutDrain: Int
    let totalDrain: Int
    
    let activeCaloriesBurned: Double?
    let steps: Int
    let workoutsCount: Int
    
    let lastNightSleepHours: Double?
    let sleepGoalHours: Double
    let recoveryScore: Double?
}
