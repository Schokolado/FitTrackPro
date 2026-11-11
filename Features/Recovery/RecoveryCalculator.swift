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

// MARK: - Biologisches Alter / Fitness-Alter

enum FitnessAgeFactorKind: String, CaseIterable {
    case rhr, steps, workouts, sleep, waist, bodyFat, bmi, vo2max
}

struct FitnessAgeFactor: Identifiable {
    var id: String { kind.rawValue }
    let kind: FitnessAgeFactorKind
    let title: String
    let systemIcon: String
    let valueText: String
    let targetText: String
    let deltaYears: Double
    let hasData: Bool
    let tip: String
}

struct FitnessAgeResult {
    let chronologicalAge: Int
    let estimatedFitnessAge: Int
    let rawDeltaYears: Double
    let hasBirthDate: Bool
    let factors: [FitnessAgeFactor]

    var ageDifference: Int {
        estimatedFitnessAge - chronologicalAge
    }
}

struct FitnessAgeCalculator {
    static func calculate(
        birthDateTimestamp: Double,
        biologicalSex: String,
        heightCm: Double,
        weightKg: Double?,
        bodyFatPercent: Double? = nil,
        waistCm: Double? = nil,
        restingHR: Double?,
        avgDailySteps: Double?,
        workoutsLast28Days: Int,
        avgSleepHours: Double?,
        sleepGoalHours: Double,
        vo2Max: Double?,
        referenceDate: Date = Date()
    ) -> FitnessAgeResult {
        let hasBirthDate = birthDateTimestamp > 0
        let chronologicalAge: Int = {
            guard hasBirthDate else { return 30 }
            let birth = Date(timeIntervalSince1970: birthDateTimestamp)
            let years = Calendar.current.dateComponents([.year], from: birth, to: referenceDate).year ?? 30
            return min(max(years, 16), 95)
        }()

        var factors: [FitnessAgeFactor] = []

        // 1. Ruhepuls (Baseline ~68 bpm, niedriger = jünger)
        if let rhr = restingHR, rhr > 0 {
            let delta = clamp((rhr - 68.0) / 5.0, min: -4.0, max: 4.0)
            factors.append(FitnessAgeFactor(
                kind: .rhr,
                title: "Ruhepuls",
                systemIcon: "heart.fill",
                valueText: "\(Int(rhr.rounded())) bpm",
                targetText: "Optimal: 50–62 bpm",
                deltaYears: delta,
                hasData: true,
                tip: "Regelmäßiges Ausdauertraining (Zone 2) senkt den Ruhepuls nachhaltig."
            ))
        } else {
            factors.append(FitnessAgeFactor(
                kind: .rhr,
                title: "Ruhepuls",
                systemIcon: "heart.fill",
                valueText: "Keine Daten",
                targetText: "Optimal: 50–62 bpm",
                deltaYears: 0,
                hasData: false,
                tip: "Trage eine Apple Watch oder erfasse den Ruhepuls in Apple Health."
            ))
        }

        // 2. Aktivität / Schritte (14-Tage Durchschnitt)
        if let steps = avgDailySteps, steps > 0 {
            let delta = clamp((7500.0 - steps) / 1800.0, min: -2.8, max: 2.2)
            factors.append(FitnessAgeFactor(
                kind: .steps,
                title: "Schritte (Ø 14 Tage)",
                systemIcon: "figure.walk",
                valueText: "\(Int(steps.rounded()).formatted()) / Tag",
                targetText: "Optimal: ≥ 9.000 / Tag",
                deltaYears: delta,
                hasData: true,
                tip: "Zusätzliche 2.000–3.000 Alltagsschritte senken das metabolische Risiko deutlich."
            ))
        } else {
            factors.append(FitnessAgeFactor(
                kind: .steps,
                title: "Schritte (Ø 14 Tage)",
                systemIcon: "figure.walk",
                valueText: "Keine Daten",
                targetText: "Optimal: ≥ 9.000 / Tag",
                deltaYears: 0,
                hasData: false,
                tip: "Erfasse Schritte über Apple Health oder manuell im Schritt-Tracker."
            ))
        }

        // 3. Trainingsfrequenz (letzte 28 Tage)
        let workoutsPerWeek = Double(workoutsLast28Days) / 4.0
        let workoutDelta: Double = {
            if workoutsPerWeek >= 4.0 { return -2.5 }
            if workoutsPerWeek >= 3.0 { return -2.0 }
            if workoutsPerWeek >= 2.0 { return -1.2 }
            if workoutsPerWeek >= 1.0 { return -0.3 }
            return 2.0
        }()
        factors.append(FitnessAgeFactor(
            kind: .workouts,
            title: "Trainingsfrequenz (4 Wochen)",
            systemIcon: "dumbbell.fill",
            valueText: String(format: "%.1f× / Woche (%d)", workoutsPerWeek, workoutsLast28Days),
            targetText: "Optimal: 3–4× / Woche",
            deltaYears: workoutDelta,
            hasData: true,
            tip: "3 bis 4 Kraft- oder Ausdauereinheiten pro Woche sind der stärkste Hebel für das Fitness-Alter."
        ))

        // 4. Schlaf (7-Tage Durchschnitt oder letzte Nacht)
        if let sleep = avgSleepHours, sleep > 0 {
            let sleepDelta: Double = {
                if sleep >= 7.2 && sleep <= 9.0 { return -1.2 }
                if sleep >= 6.5 && sleep < 7.2 { return 0.2 }
                if sleep > 9.0 { return -0.3 }
                return 1.4
            }()
            let h = Int(sleep)
            let m = Int(((sleep - Double(h)) * 60).rounded())
            factors.append(FitnessAgeFactor(
                kind: .sleep,
                title: "Schlafqualität / -dauer",
                systemIcon: "moon.zzz.fill",
                valueText: "\(h)h \(m)m (Ziel \(Int(sleepGoalHours))h)",
                targetText: "Optimal: 7–9 Stunden",
                deltaYears: sleepDelta,
                hasData: true,
                tip: "Konstante Schlafzeiten zwischen 7 und 9 Stunden verbessern Regeneration und Hormonhaushalt."
            ))
        }

        // 5. Körperkomposition: Echte Metriken (WHtR / KFA) vor BMI-Fallback
        var usedDirectCompositionMetric = false

        if let waist = waistCm, waist > 0, heightCm > 0 {
            usedDirectCompositionMetric = true
            let whtr = waist / heightCm
            let whtrDelta: Double = {
                if whtr >= 0.42 && whtr <= 0.49 { return -1.8 }
                if whtr < 0.42 || (whtr > 0.49 && whtr <= 0.52) { return -0.6 }
                if whtr <= 0.56 { return 0.7 }
                return 2.0
            }()
            factors.append(FitnessAgeFactor(
                kind: .waist,
                title: "Taille / WHtR",
                systemIcon: "ruler.fill",
                valueText: String(format: "%.2f (%d cm)", whtr, Int(waist.rounded())),
                targetText: "Optimal: 0,42–0,49",
                deltaYears: whtrDelta,
                hasData: true,
                tip: "Das Taille-zu-Größe-Verhältnis (WHtR) bewertet viszerales Fett unabhängig von deiner Muskelmasse."
            ))
        }

        if let kfa = bodyFatPercent, kfa > 0 {
            usedDirectCompositionMetric = true
            let (optimalLow, optimalHigh, okHigh): (Double, Double, Double) = {
                switch biologicalSex {
                case "male":   return (10.0, 18.0, 22.5)
                case "female": return (18.0, 26.0, 30.5)
                default:       return (14.0, 22.0, 26.5)
                }
            }()
            let kfaDelta: Double = {
                if kfa >= optimalLow && kfa <= optimalHigh { return -1.6 }
                if (kfa >= optimalLow - 3 && kfa < optimalLow) || (kfa > optimalHigh && kfa <= okHigh) { return 0.0 }
                if kfa > okHigh && kfa <= okHigh + 4 { return 0.9 }
                return 1.8
            }()
            factors.append(FitnessAgeFactor(
                kind: .bodyFat,
                title: "Körperfettanteil (KFA)",
                systemIcon: "figure.arms.open",
                valueText: String(format: "%.1f %%", kfa),
                targetText: String(format: "Optimal: %.0f–%.0f %%", optimalLow, optimalHigh),
                deltaYears: kfaDelta,
                hasData: true,
                tip: "Der KFA trennt Fett- und Muskelmasse sauber – ideal für Kraftsportler."
            ))
        }

        // BMI nur als Fallback, wenn weder Taillenumfang noch KFA vorliegt (ohne Malus bei aktivem Krafttraining)
        if !usedDirectCompositionMetric, let w = weightKg, w > 0, heightCm > 0 {
            let hM = heightCm / 100.0
            let bmi = w / (hM * hM)
            let isActiveAthlete = workoutsPerWeek >= 2.0
            let upperHealthy = isActiveAthlete ? 28.5 : 24.9
            let bmiDelta: Double = {
                if bmi >= 19.0 && bmi <= 24.9 { return -0.8 }
                if isActiveAthlete && bmi > 24.9 && bmi <= upperHealthy { return 0.0 }
                if (bmi > upperHealthy && bmi <= 30.0) || (bmi >= 18.0 && bmi < 19.0) { return 0.6 }
                return 1.6
            }()
            factors.append(FitnessAgeFactor(
                kind: .bmi,
                title: "BMI (Hinweiswert)",
                systemIcon: "scalemass.fill",
                valueText: String(format: "%.1f (%.1f kg)", bmi, w),
                targetText: isActiveAthlete ? "Athleten-Toleranz aktiv" : "Optimal: 19–24,9",
                deltaYears: bmiDelta,
                hasData: true,
                tip: "BMI unterscheidet nicht zwischen Muskel- und Fettmasse. Erfasse KFA oder Taillenumfang im Gewichts-Tracker für echte Präzision."
            ))
        }

        // 6. Optional: VO2max (Apple Watch)
        if let vo2 = vo2Max, vo2 > 0 {
            let ageOffset = Double(max(0, chronologicalAge - 25))
            let referenceVO2: Double = {
                switch biologicalSex {
                case "male":   return max(30.0, 44.0 - ageOffset * 0.25)
                case "female": return max(26.0, 38.0 - ageOffset * 0.22)
                default:       return max(28.0, 41.0 - ageOffset * 0.23)
                }
            }()
            let vo2Delta = clamp((referenceVO2 - vo2) / 3.0, min: -3.0, max: 3.0)
            factors.append(FitnessAgeFactor(
                kind: .vo2max,
                title: "VO2max (Kardio-Fitness)",
                systemIcon: "lungs.fill",
                valueText: String(format: "%.1f ml/kg/min", vo2),
                targetText: String(format: "Altersnorm: ~%.0f", referenceVO2),
                deltaYears: vo2Delta,
                hasData: true,
                tip: "Intervalltraining oder längere zügige Läufe/Radfahrten steigern die maximale Sauerstoffaufnahme."
            ))
        }

        let rawDelta = factors.reduce(0.0) { $0 + $1.deltaYears }
        let clampedDelta = clamp(rawDelta, min: -14.0, max: 14.0)
        let estimatedAge = max(18, Int((Double(chronologicalAge) + clampedDelta).rounded()))

        return FitnessAgeResult(
            chronologicalAge: chronologicalAge,
            estimatedFitnessAge: estimatedAge,
            rawDeltaYears: clampedDelta,
            hasBirthDate: hasBirthDate,
            factors: factors
        )
    }

    private static func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        Swift.max(minVal, Swift.min(maxVal, value))
    }
}
