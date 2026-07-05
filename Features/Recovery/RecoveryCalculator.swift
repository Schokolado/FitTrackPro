import Foundation
import SwiftData

enum RecoveryFactor: String, CaseIterable, Identifiable {
    case sleep, training, rest, bio
    var id: String { rawValue }
}

struct RecoveryResult {
    let score: Int // 0-100
    let level: RecoveryLevel
    
    // Breakdown
    let sleepScore: Int
    let sleepMax: Int
    
    let trainingScore: Int
    let trainingMax: Int
    
    let restScore: Int
    let restMax: Int
    
    let hrvScore: Int?
    let hrvMax: Int?
    
    let usesHRV: Bool
    
    // Raw data
    let rawLastNightSleepHours: Double?
    let rawSleepGoalHours: Double
    let rawWorkoutSessionsLast3Days: Int
    let rawDaysSinceLastWorkout: Int
    let rawHRV: Double?
    let rawHRVBaseline: Double?
    let rawRHR: Double?
    let rawRHRBaseline: Double?
}

enum RecoveryLevel: String {
    case low = "Niedrig"
    case moderate = "Moderat"
    case good = "Gut"
    case optimal = "Optimal"
    
    var description: String {
        switch self {
        case .low: return "Gönn dir einen Ruhetag"
        case .moderate: return "Leichtes Training empfohlen"
        case .good: return "Bereit für moderates Training"
        case .optimal: return "Bereit für intensives Training!"
        }
    }
}

struct RecoveryCalculator {
    static func calculate(
        lastNightSleepHours: Double?,
        sleepGoalHours: Double,
        workoutSessionsLast3Days: Int, // Count of sessions
        daysSinceLastWorkout: Int,
        hrvScore: Double?,        // Heart Rate Variability (SDNN)
        restingHR: Double?,       // Ruheherzfrequenz
        hrvBaseline: Double?,
        rhrBaseline: Double?
    ) -> RecoveryResult {
        
        let usesHRVorRHR = (hrvScore != nil && hrvBaseline != nil) || (restingHR != nil && rhrBaseline != nil)
        
        // Gewichte anpassen, je nachdem ob wir Bio-Feedback (HRV/RHR) haben
        let weightSleep = usesHRVorRHR ? 20.0 : 35.0
        let weightTraining = usesHRVorRHR ? 30.0 : 40.0
        let weightRest = usesHRVorRHR ? 10.0 : 25.0
        let weightBio = usesHRVorRHR ? 40.0 : 0.0
        
        // 1. Schlaf (0 - weightSleep)
        let sleepRatio = min((lastNightSleepHours ?? (sleepGoalHours * 0.7)) / sleepGoalHours, 1.0)
        let sleepPoints = Int(sleepRatio * weightSleep)
        
        // 2. Trainingsbelastung (0 - weightTraining)
        // Optimal: 1-2 Sessions in letzten 3 Tagen. Zu viele = weniger Punkte
        var trainingRatio = 1.0
        if workoutSessionsLast3Days > 3 {
            trainingRatio = 0.3
        } else if workoutSessionsLast3Days == 3 {
            trainingRatio = 0.6
        } else if workoutSessionsLast3Days == 2 {
            trainingRatio = 0.8
        } else {
            trainingRatio = 1.0
        }
        let trainingPoints = Int(trainingRatio * weightTraining)
        
        // 3. Erholungstage (0 - weightRest)
        var restRatio = 0.0
        if daysSinceLastWorkout >= 2 {
            restRatio = 1.0
        } else if daysSinceLastWorkout == 1 {
            restRatio = 0.7
        } else {
            restRatio = 0.3
        }
        let restPoints = Int(restRatio * weightRest)
        
        // 4. Bio-Feedback (HRV / RHR) (0 - weightBio)
        var bioPoints = 0
        if let hrv = hrvScore, let baseline = hrvBaseline {
            // Höhere HRV als Baseline = besser erholt
            let ratio = hrv / baseline
            var mappedRatio = 1.0
            if ratio < 0.8 { mappedRatio = 0.3 }
            else if ratio < 0.95 { mappedRatio = 0.7 }
            else { mappedRatio = 1.0 }
            bioPoints = Int(mappedRatio * weightBio)
        } else if let rhr = restingHR, let baseline = rhrBaseline {
            // Niedrigere RHR als Baseline = besser erholt
            let ratio = baseline / rhr // Inverted: baseline 60, current 65 -> 60/65 = 0.92
            var mappedRatio = 1.0
            if ratio < 0.9 { mappedRatio = 0.3 }
            else if ratio < 1.0 { mappedRatio = 0.7 }
            else { mappedRatio = 1.0 }
            bioPoints = Int(mappedRatio * weightBio)
        }
        
        let totalScore = sleepPoints + trainingPoints + restPoints + bioPoints
        
        let level: RecoveryLevel
        if totalScore < 40 {
            level = .low
        } else if totalScore < 65 {
            level = .moderate
        } else if totalScore < 85 {
            level = .good
        } else {
            level = .optimal
        }
        
        return RecoveryResult(
            score: totalScore,
            level: level,
            sleepScore: sleepPoints,
            sleepMax: Int(weightSleep),
            trainingScore: trainingPoints,
            trainingMax: Int(weightTraining),
            restScore: restPoints,
            restMax: Int(weightRest),
            hrvScore: usesHRVorRHR ? bioPoints : nil,
            hrvMax: usesHRVorRHR ? Int(weightBio) : nil,
            usesHRV: usesHRVorRHR,
            rawLastNightSleepHours: lastNightSleepHours,
            rawSleepGoalHours: sleepGoalHours,
            rawWorkoutSessionsLast3Days: workoutSessionsLast3Days,
            rawDaysSinceLastWorkout: daysSinceLastWorkout,
            rawHRV: hrvScore,
            rawHRVBaseline: hrvBaseline,
            rawRHR: restingHR,
            rawRHRBaseline: rhrBaseline
        )
    }
}
