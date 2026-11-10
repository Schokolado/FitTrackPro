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

enum MuscleBalanceMetric: String, CaseIterable, Identifiable {
    case sets      = "Sätze"
    case volume    = "Volumen (kg)"
    case exercises = "Übungen"
    case workouts  = "Workouts"

    var id: String { rawValue }
}

struct MuscleGroupStat: Identifiable {
    var id: String { category }
    let category: String
    let setCount: Int
    let volumeKg: Double
    let exerciseCount: Int
    let workoutCount: Int
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

    /// Gesamte Trainingsdauer in Sekunden
    func totalWorkoutDuration(in sessions: [WorkoutSession]) -> TimeInterval {
        sessions.filter { $0.endTime != nil }.reduce(0.0) { acc, s in
            guard let end = s.endTime else { return acc }
            return acc + max(0, end.timeIntervalSince(s.startTime))
        }
    }

    /// Gesamtanzahl abgeschlossener Sätze
    func totalSets(in sessions: [WorkoutSession]) -> Int {
        sessions.reduce(0) { acc, session in
            acc + (session.sets ?? []).filter { $0.isCompleted }.count
        }
    }

    /// Aufschlüsselung nach Muskelgruppe / Übungs-Kategorie für mehrere Sessions
    func muscleGroupBreakdown(in sessions: [WorkoutSession]) -> [MuscleGroupStat] {
        Self.muscleGroupBreakdown(in: sessions)
    }

    /// Analysiert Push/Pull & Ober-/Unterkörper-Balance
    func muscleBalanceInsight(from stats: [MuscleGroupStat]) -> (title: String, message: String, isBalanced: Bool)? {
        Self.muscleBalanceInsight(from: stats)
    }

    // MARK: - Wiederverwendbare Balance-Berechnung (Statistik, Plan, Workout-Auswertung)

    /// Aufschlüsselung nach Muskelgruppe für beliebig viele Workout-Sessions
    static func muscleGroupBreakdown(in sessions: [WorkoutSession]) -> [MuscleGroupStat] {
        var setCounts: [String: Int] = [:]
        var volumes: [String: Double] = [:]
        var exerciseIdsByCategory: [String: Set<UUID>] = [:]
        var sessionIdsByCategory: [String: Set<UUID>] = [:]

        for session in sessions {
            for set in (session.sets ?? []) where set.isCompleted {
                guard let exercise = set.exercise else { continue }
                let category = exercise.category.isEmpty ? "Sonstiges" : exercise.category
                setCounts[category, default: 0] += 1
                volumes[category, default: 0] += Double(set.actualReps) * set.actualWeight
                exerciseIdsByCategory[category, default: []].insert(exercise.id)
                sessionIdsByCategory[category, default: []].insert(session.id)
            }
        }

        return sortStats(setCounts.keys.map { category in
            MuscleGroupStat(
                category: category,
                setCount: setCounts[category, default: 0],
                volumeKg: volumes[category, default: 0],
                exerciseCount: exerciseIdsByCategory[category]?.count ?? 0,
                workoutCount: sessionIdsByCategory[category]?.count ?? 0
            )
        })
    }

    /// Aufschlüsselung nach Muskelgruppe für eine einzelne Workout-Session
    static func muscleGroupBreakdown(in session: WorkoutSession) -> [MuscleGroupStat] {
        muscleGroupBreakdown(in: [session])
    }

    /// Aufschlüsselung nach Muskelgruppe für einen Trainingsplan (Soll-Sätze, Übungen & Soll-Volumen)
    static func muscleGroupBreakdown(for plan: TrainingPlan) -> [MuscleGroupStat] {
        var setCounts: [String: Int] = [:]
        var volumes: [String: Double] = [:]
        var exerciseIdsByCategory: [String: Set<UUID>] = [:]

        for planEx in (plan.planExercises ?? []) {
            guard let exercise = planEx.exercise else { continue }
            let category = exercise.category.isEmpty ? "Sonstiges" : exercise.category
            let sets = max(0, planEx.targetSets)
            let reps = max(0, planEx.targetReps)
            let weight = planEx.targetWeight ?? 0

            setCounts[category, default: 0] += sets
            volumes[category, default: 0] += Double(sets * reps) * weight
            exerciseIdsByCategory[category, default: []].insert(exercise.id)
        }

        return sortStats(exerciseIdsByCategory.keys.map { category in
            MuscleGroupStat(
                category: category,
                setCount: setCounts[category, default: 0],
                volumeKg: volumes[category, default: 0],
                exerciseCount: exerciseIdsByCategory[category]?.count ?? 0,
                workoutCount: 1
            )
        })
    }

    private static func sortStats(_ stats: [MuscleGroupStat]) -> [MuscleGroupStat] {
        stats.sorted {
            if $0.setCount != $1.setCount {
                return $0.setCount > $1.setCount
            }
            if $0.exerciseCount != $1.exerciseCount {
                return $0.exerciseCount > $1.exerciseCount
            }
            return $0.volumeKg > $1.volumeKg
        }
    }

    /// Analysiert Push/Pull & Ober-/Unterkörper-Balance
    static func muscleBalanceInsight(from stats: [MuscleGroupStat]) -> (title: String, message: String, isBalanced: Bool)? {
        let strengthCategories = Set(["brust", "rücken", "beine", "schultern", "arme", "bauch / core", "chest", "back", "legs", "shoulders", "arms", "abs / core"])
        let strengthStats = stats.filter { strengthCategories.contains($0.category.lowercased()) }
        let totalStrengthSets = strengthStats.reduce(0) { $0 + $1.setCount }
        guard totalStrengthSets >= 6 else { return nil }

        let pushSets = stats
            .filter { ["brust", "schultern", "chest", "shoulders"].contains($0.category.lowercased()) }
            .reduce(0) { $0 + $1.setCount }
        let pullSets = stats
            .filter { ["rücken", "back"].contains($0.category.lowercased()) }
            .reduce(0) { $0 + $1.setCount }
        let legSets = stats
            .filter { ["beine", "legs"].contains($0.category.lowercased()) }
            .reduce(0) { $0 + $1.setCount }

        if pullSets > 0 && Double(pushSets) > Double(pullSets) * 2.0 {
            return (
                "Push-Dominanz erkannt",
                "Du trainierst deutlich mehr Druck- (\(pushSets) Sätze) als Zug-Übungen für den Rücken (\(pullSets) Sätze). Etwas mehr Rücken-Volumen schützt die Schultergesundheit.",
                false
            )
        }
        if pushSets > 0 && Double(pullSets) > Double(pushSets) * 2.2 {
            return (
                "Zug-Dominanz erkannt",
                "Sehr starker Fokus auf Rücken (\(pullSets) Sätze) im Vergleich zu Brust/Schultern (\(pushSets) Sätze).",
                false
            )
        }
        if Double(legSets) < Double(totalStrengthSets) * 0.15 && totalStrengthSets >= 12 {
            return (
                "Beintraining ausbaufähig",
                "Nur \(Int((Double(legSets) / Double(totalStrengthSets)) * 100))% deiner Kraft-Sätze entfallen auf die Beine (\(legSets) von \(totalStrengthSets) Sätzen).",
                false
            )
        }

        return (
            "Ausgewogene Balance",
            "Deine Muskelgruppen sind gut aufeinander abgestimmt verteilt.",
            true
        )
    }
}
