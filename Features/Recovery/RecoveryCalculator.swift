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

// MARK: - Trainingsbelastung & Fitness-Status (ACWR + Verlauf)

enum TrainingStatus: String, CaseIterable {
    case detraining   = "Geringe Aktivität"
    case recovery     = "Erholung"
    case maintaining  = "Erhalt"
    case productive   = "Produktiver Aufbau"
    case peaking      = "Höchstform"
    case overreaching = "Überlastung"

    var subtitle: String {
        switch self {
        case .detraining:   return "Fitness kann abnehmen"
        case .recovery:     return "Aktive Regeneration"
        case .maintaining:  return "Aktuelle Form wird gehalten"
        case .productive:   return "Optimaler Leistungszuwachs"
        case .peaking:      return "Starke Basis & frische Reserven"
        case .overreaching: return "Regeneration priorisieren"
        }
    }

    var systemIcon: String {
        switch self {
        case .detraining:   return "arrow.down.right.circle.fill"
        case .recovery:     return "leaf.fill"
        case .maintaining:  return "equal.circle.fill"
        case .productive:   return "arrow.up.right.circle.fill"
        case .peaking:      return "flame.fill"
        case .overreaching: return "exclamationmark.triangle.fill"
        }
    }

    var explanation: String {
        switch self {
        case .detraining:
            return "Deine Trainingsbelastung der letzten 7 Tage liegt deutlich unter dem Bereich für weitere Anpassung. Bei längerer Inaktivität kann die aufgebaute Fitness langsam zurückgehen."
        case .recovery:
            return "Deine akute Belastung liegt unter deinem 4-Wochen-Schnitt. Das gibt Muskeln und Nervensystem gezielt Raum zur Regeneration."
        case .maintaining:
            return "Deine aktuelle Wochenbelastung entspricht weitgehend deiner chronischen Basis. Du stabilisierst deine Fitness zuverlässig ohne Überlastungsrisiko."
        case .productive:
            return "Deine akute Belastung liegt leicht über deinem 4-Wochen-Durchschnitt (ACWR ca. 1,1–1,45×). Genau in diesem Korridor baut dein Körper nachhaltig neue Leistungsfähigkeit auf."
        case .peaking:
            return "Du hast über die letzten Wochen eine starke Trainingsbasis aufgebaut und die akute Last zuletzt kontrolliert reduziert – ideale Voraussetzungen für Bestleistungen."
        case .overreaching:
            return "Deine akute Trainingsbelastung ist deutlich stärker gestiegen als deine 4-Wochen-Basis gewohnt ist (> 1,45×). Plane zeitnah einen Ruhetag oder eine leichtere Einheit ein."
        }
    }
}

struct TrainingLoadPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let acuteLoad: Double
    let chronicLoad: Double
    let ratio: Double
    let status: TrainingStatus
}

struct TrainingStatusPeriod: Identifiable {
    var id: String { "\(startDate.timeIntervalSince1970)-\(status.rawValue)" }
    let status: TrainingStatus
    let startDate: Date
    let endDate: Date
    let days: Int
}

struct TrainingLoadAnalysis {
    let currentStatus: TrainingStatus
    let acuteLoad: Double
    let chronicLoad: Double
    let acwr: Double
    let workoutsLast7Days: Int
    let workoutsLast28Days: Int
    let historyPoints: [TrainingLoadPoint]
    let statusTimeline: [TrainingStatusPeriod]
}

struct TrainingLoadCalculator {
    static func sessionLoad(for session: WorkoutSession) -> Double {
        guard let end = session.endTime else { return 0 }
        let durationMinutes = max(15.0, end.timeIntervalSince(session.startTime) / 60.0)
        let intensity = min(max(session.intensityRating ?? 3, 1), 5)
        let intensityFactor = 0.55 + Double(intensity) * 0.15 // 0.70 ... 1.30
        let completedSets = (session.sets ?? []).filter { $0.isCompleted }.count
        return (durationMinutes * intensityFactor) + Double(completedSets) * 1.5
    }

    static func analyze(
        workouts: [WorkoutSession],
        upTo referenceDate: Date = Date(),
        historyDays: Int = 42
    ) -> TrainingLoadAnalysis {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: referenceDate)
        let completed = workouts.filter { $0.endTime != nil }

        var dailyLoads: [Date: Double] = [:]
        for session in completed {
            let day = cal.startOfDay(for: session.startTime)
            dailyLoads[day, default: 0] += sessionLoad(for: session)
        }

        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: todayStart)!
        let twentyEightDaysAgo = cal.date(byAdding: .day, value: -27, to: todayStart)!
        let workouts7 = completed.filter { cal.startOfDay(for: $0.startTime) >= sevenDaysAgo && cal.startOfDay(for: $0.startTime) <= todayStart }.count
        let workouts28 = completed.filter { cal.startOfDay(for: $0.startTime) >= twentyEightDaysAgo && cal.startOfDay(for: $0.startTime) <= todayStart }.count

        var points: [TrainingLoadPoint] = []
        for offset in stride(from: -(historyDays - 1), through: 0, by: 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: todayStart) else { continue }

            var acuteSum: Double = 0
            for d in 0..<7 {
                if let target = cal.date(byAdding: .day, value: -d, to: day) {
                    acuteSum += dailyLoads[target, default: 0]
                }
            }

            var chronicSum: Double = 0
            for d in 0..<28 {
                if let target = cal.date(byAdding: .day, value: -d, to: day) {
                    chronicSum += dailyLoads[target, default: 0]
                }
            }
            let chronicWeeklyAvg = chronicSum / 4.0
            let ratio = chronicWeeklyAvg >= 15.0 ? (acuteSum / chronicWeeklyAvg) : (acuteSum > 0 ? 1.08 : 0.0)
            let status = classifyStatus(acute7: acuteSum, chronicWeeklyAvg: chronicWeeklyAvg, ratio: ratio)

            points.append(
                TrainingLoadPoint(
                    date: day,
                    acuteLoad: acuteSum,
                    chronicLoad: chronicWeeklyAvg,
                    ratio: ratio,
                    status: status
                )
            )
        }

        // Status-Phasen für die Timeline zusammenfassen (neueste zuerst)
        var periods: [TrainingStatusPeriod] = []
        if let first = points.first {
            var currentStatus = first.status
            var periodStart = first.date
            var periodEnd = first.date
            var count = 1

            for pt in points.dropFirst() {
                if pt.status == currentStatus {
                    periodEnd = pt.date
                    count += 1
                } else {
                    periods.append(TrainingStatusPeriod(status: currentStatus, startDate: periodStart, endDate: periodEnd, days: count))
                    currentStatus = pt.status
                    periodStart = pt.date
                    periodEnd = pt.date
                    count = 1
                }
            }
            periods.append(TrainingStatusPeriod(status: currentStatus, startDate: periodStart, endDate: periodEnd, days: count))
        }

        let latest = points.last
        return TrainingLoadAnalysis(
            currentStatus: latest?.status ?? .detraining,
            acuteLoad: latest?.acuteLoad ?? 0,
            chronicLoad: latest?.chronicLoad ?? 0,
            acwr: latest?.ratio ?? 0,
            workoutsLast7Days: workouts7,
            workoutsLast28Days: workouts28,
            historyPoints: points,
            statusTimeline: periods.reversed()
        )
    }

    private static func classifyStatus(acute7: Double, chronicWeeklyAvg: Double, ratio: Double) -> TrainingStatus {
        if acute7 < 20 && chronicWeeklyAvg < 25 {
            return .detraining
        }
        if acute7 < 20 {
            return chronicWeeklyAvg >= 55 ? .recovery : .detraining
        }
        if chronicWeeklyAvg >= 75 && ratio >= 0.65 && ratio < 0.85 {
            return .peaking
        }
        if ratio > 1.45 {
            return .overreaching
        }
        if ratio >= 1.08 {
            return .productive
        }
        if ratio >= 0.80 {
            return .maintaining
        }
        return .recovery
    }
}
