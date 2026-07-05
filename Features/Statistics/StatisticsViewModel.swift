import Foundation
import SwiftData

enum TimeRange: String, CaseIterable, Identifiable {
    case week   = "7 Tage"
    case month  = "30 Tage"
    case quarter = "90 Tage"
    case all    = "Gesamt"

    var id: String { rawValue }

    /// Gibt das früheste Datum für diesen Zeitraum zurück (oder nil für "Gesamt")
    var startDate: Date? {
        let cal = Calendar.current
        switch self {
        case .week:    return cal.date(byAdding: .day, value: -7, to: Date())
        case .month:   return cal.date(byAdding: .day, value: -30, to: Date())
        case .quarter: return cal.date(byAdding: .day, value: -90, to: Date())
        case .all:     return nil
        }
    }
}

enum StatisticsMetric: String, CaseIterable, Identifiable {
    case volume     = "Volumen (kg)"
    case maxWeight  = "Max. Gewicht"
    case avgWeight  = "Ø Gewicht"
    case reps       = "Reps."

    var id: String { rawValue }
}

struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double  // Volumen in kg oder Max-Gewicht in kg oder Satz-Anzahl
}

struct PersonalRecord {
    let exercise: Exercise
    let weightKg: Double
    let achievedAt: Date
    let totalReps: Int
}

@Observable
final class StatisticsViewModel {

    // MARK: - Published State
    var selectedTimeRange: TimeRange = .month
    var selectedMetric: StatisticsMetric = .volume
    var selectedExercise: Exercise? = nil
    var selectedPlan: TrainingPlan? = nil

    // MARK: - Aggregationsmethoden

    /// Filtert Sessions nach Zeitraum und optionalem Plan
    func filteredSessions(
        from allSessions: [WorkoutSession],
        timeRange: TimeRange,
        plan: TrainingPlan? = nil
    ) -> [WorkoutSession] {
        var sessions = allSessions.filter { $0.endTime != nil }

        if let startDate = timeRange.startDate {
            sessions = sessions.filter { ($0.startTime) >= startDate }
        }
        if let plan = plan {
            sessions = sessions.filter { $0.plan?.id == plan.id }
        }
        return sessions.sorted { $0.startTime < $1.startTime }
    }

    /// Volumen (kg) pro Trainingstag für eine Übung
    /// Volumen = Σ(actualReps × actualWeight) aller completed Sets
    func volumeData(
        for exercise: Exercise,
        in sessions: [WorkoutSession]
    ) -> [VolumeDataPoint] {
        sessions.compactMap { session in
            guard let endTime = session.endTime else { return nil }
            let sets = (session.sets ?? []).filter {
                $0.exercise?.id == exercise.id && $0.isCompleted
            }
            let volume = sets.reduce(0.0) { $0 + Double($1.actualReps) * $1.actualWeight }
            guard volume > 0 else { return nil }
            return VolumeDataPoint(date: endTime, value: volume)
        }
    }

    /// Max. Gewicht pro Trainingstag für eine Übung
    func maxWeightData(
        for exercise: Exercise,
        in sessions: [WorkoutSession]
    ) -> [VolumeDataPoint] {
        sessions.compactMap { session in
            guard let endTime = session.endTime else { return nil }
            let sets = (session.sets ?? []).filter {
                $0.exercise?.id == exercise.id && $0.isCompleted
            }
            guard let maxW = sets.map({ $0.actualWeight }).max(), maxW > 0 else { return nil }
            return VolumeDataPoint(date: endTime, value: maxW)
        }
    }

    /// Wiederholungen pro Trainingstag für eine Übung
    func repCountData(
        for exercise: Exercise,
        in sessions: [WorkoutSession]
    ) -> [VolumeDataPoint] {
        sessions.compactMap { session in
            guard let endTime = session.endTime else { return nil }
            let reps = (session.sets ?? []).filter {
                $0.exercise?.id == exercise.id && $0.isCompleted
            }.reduce(0) { $0 + $1.actualReps }
            guard reps > 0 else { return nil }
            return VolumeDataPoint(date: endTime, value: Double(reps))
        }
    }

    /// Personal Record: Maximales Gewicht, das jemals mit dieser Übung gehoben wurde
    func personalRecord(for exercise: Exercise, in allSessions: [WorkoutSession]) -> PersonalRecord? {
        var bestWeight: Double = 0
        var bestDate: Date = Date.distantPast
        var bestReps: Int = 0

        for session in allSessions {
            guard let endTime = session.endTime else { continue }
            let sets = (session.sets ?? []).filter {
                $0.exercise?.id == exercise.id && $0.isCompleted && $0.actualWeight > 0
            }
            for set in sets {
                if set.actualWeight > bestWeight {
                    bestWeight = set.actualWeight
                    bestDate = endTime
                    bestReps = set.actualReps
                }
            }
        }

        guard bestWeight > 0 else { return nil }
        return PersonalRecord(
            exercise: exercise,
            weightKg: bestWeight,
            achievedAt: bestDate,
            totalReps: bestReps
        )
    }

    /// Durchschnittsgewicht pro Trainingstag für eine Übung
    func avgWeightData(
        for exercise: Exercise,
        in sessions: [WorkoutSession]
    ) -> [VolumeDataPoint] {
        sessions.compactMap { session in
            guard let endTime = session.endTime else { return nil }
            let sets = (session.sets ?? []).filter {
                $0.exercise?.id == exercise.id && $0.isCompleted && $0.actualWeight > 0
            }
            guard !sets.isEmpty else { return nil }
            let sum = sets.reduce(0.0) { $0 + $1.actualWeight }
            return VolumeDataPoint(date: endTime, value: sum / Double(sets.count))
        }
    }

    /// Daten für die Chart-Anzeige basierend auf gewählter Metrik
    func chartData(
        for exercise: Exercise,
        in sessions: [WorkoutSession],
        metric: StatisticsMetric
    ) -> [VolumeDataPoint] {
        switch metric {
        case .volume:     return volumeData(for: exercise, in: sessions)
        case .maxWeight:  return maxWeightData(for: exercise, in: sessions)
        case .avgWeight:  return avgWeightData(for: exercise, in: sessions)
        case .reps:       return repCountData(for: exercise, in: sessions)
        }
    }

    /// Alle Übungen die in den gefilterten Sessions vorkommen, sortiert nach Häufigkeit
    func usedExercises(in sessions: [WorkoutSession]) -> [Exercise] {
        var exerciseCounts: [UUID: (Exercise, Int)] = [:]
        for session in sessions {
            for set in (session.sets ?? []) where set.isCompleted {
                if let ex = set.exercise {
                    let count = exerciseCounts[ex.id]?.1 ?? 0
                    exerciseCounts[ex.id] = (ex, count + 1)
                }
            }
        }
        return exerciseCounts.values
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    /// Trainingsfrequenz: Anzahl Workouts pro Woche in einem Zeitraum
    func weeklyFrequency(in sessions: [WorkoutSession]) -> [(date: Date, count: Int)] {
        guard !sessions.isEmpty else { return [] }
        let cal = Calendar.current

        var grouped: [Date: Int] = [:]
        for session in sessions {
            guard let weekStart = cal.date(
                from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startTime)
            ) else { continue }
            grouped[weekStart, default: 0] += 1
        }

        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, count: $0.value) }
    }

    /// Gesamtvolumen (kg) über alle Sessions in einem Zeitraum
    func totalVolume(in sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0.0) { sessionTotal, session in
            sessionTotal + (session.sets ?? [])
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + Double($1.actualReps) * $1.actualWeight }
        }
    }

    /// Gesamtanzahl abgeschlossener Workouts
    func completedWorkoutCount(in sessions: [WorkoutSession]) -> Int {
        sessions.filter { $0.endTime != nil }.count
    }

    /// Durchschnittliche Workout-Dauer in Sekunden
    func averageWorkoutDuration(in sessions: [WorkoutSession]) -> TimeInterval {
        let completed = sessions.filter { $0.endTime != nil }
        guard !completed.isEmpty else { return 0 }
        let total = completed.reduce(0.0) { acc, s in
            guard let end = s.endTime else { return acc }
            return acc + end.timeIntervalSince(s.startTime)
        }
        return total / Double(completed.count)
    }
}
