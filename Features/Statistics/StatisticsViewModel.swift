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

struct MuscleBalanceInsight {
    let title: String
    let message: String
    let isBalanced: Bool
    let effectiveFocus: PlanFocus
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

    /// Personal Record: Maximales Gewicht (oder längste Dauer bei Zeit-/Cardio-Übungen)
    func personalRecord(for exercise: Exercise, in allSessions: [WorkoutSession]) -> PersonalRecord? {
        if !exercise.usesWeightInput {
            var bestDuration = 0
            var bestLevel: Double = 0
            var bestDate: Date = Date.distantPast

            for session in allSessions {
                guard let endTime = session.endTime else { continue }
                let sets = (session.sets ?? []).filter {
                    $0.exercise?.id == exercise.id && $0.isCompleted && $0.actualReps > 0
                }
                for set in sets {
                    if set.actualReps > bestDuration || (set.actualReps == bestDuration && set.actualWeight > bestLevel) {
                        bestDuration = set.actualReps
                        bestLevel = set.actualWeight
                        bestDate = endTime
                    }
                }
            }

            guard bestDuration > 0 else { return nil }
            return PersonalRecord(
                exercise: exercise,
                weightKg: bestLevel,
                achievedAt: bestDate,
                totalReps: bestDuration
            )
        }

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
    func muscleBalanceInsight(
        from stats: [MuscleGroupStat],
        configuredFocus: PlanFocus = .auto,
        planName: String? = nil
    ) -> MuscleBalanceInsight? {
        Self.muscleBalanceInsight(from: stats, configuredFocus: configuredFocus, planName: planName)
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

    /// Ermittelt den effektiven Trainingsfokus (explizit gesetzt oder automatisch aus Planname & Muskelgruppen erkannt)
    static func resolvedPlanFocus(
        for configuredFocus: PlanFocus,
        planName: String? = nil,
        stats: [MuscleGroupStat]
    ) -> PlanFocus {
        if configuredFocus != .auto {
            return configuredFocus
        }

        if let detectedByName = detectFocusFromName(planName) {
            return detectedByName
        }

        let units: ([String]) -> Int = { keywords in
            stats
                .filter { keywords.contains($0.category.lowercased()) }
                .reduce(0) { $0 + ($1.setCount > 0 ? $1.setCount : $1.exerciseCount) }
        }

        let totalUnits = stats.reduce(0) { $0 + ($1.setCount > 0 ? $1.setCount : $1.exerciseCount) }
        let mobilityUnits = units(["mobilität", "mobility"])
        let pushUnits = units(["brust", "schultern", "chest", "shoulders"])
        let pullUnits = units(["rücken", "back"])
        let legUnits = units(["beine", "legs"])
        let armCoreUnits = units(["arme", "bauch / core", "arms", "abs / core"])

        if mobilityUnits > 0 && totalUnits > 0 && Double(mobilityUnits) >= Double(totalUnits) * 0.6 {
            return .mobility
        }

        if legUnits > 0 && pushUnits == 0 && pullUnits == 0 {
            return .lowerBody
        }

        if legUnits == 0 {
            if pushUnits > 0 && pullUnits == 0 {
                return .push
            }
            if pullUnits > 0 && pushUnits == 0 {
                return .pull
            }
            if pushUnits > 0 || pullUnits > 0 || armCoreUnits > 0 {
                return .upperBody
            }
        }

        return .fullBody
    }

    private static func detectFocusFromName(_ planName: String?) -> PlanFocus? {
        guard let raw = planName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return nil
        }
        let tokens = raw.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }

        if raw.contains("mobilität") || raw.contains("mobility") || raw.contains("stretch") || raw.contains("dehn") {
            return .mobility
        }
        if raw.contains("ganzkörper") || raw.contains("full body") || raw.contains("fullbody") || tokens.contains("gk") {
            return .fullBody
        }
        if raw.contains("oberkörper") || raw.contains("upper") || tokens.contains("ok") {
            return .upperBody
        }
        if raw.contains("unterkörper") || raw.contains("lower") || raw.contains("beine") || raw.contains("legs") || tokens.contains("uk") {
            return .lowerBody
        }
        if tokens.contains("push") || raw.contains("push") {
            return .push
        }
        if tokens.contains("pull") || raw.contains("pull") {
            return .pull
        }
        return nil
    }

    /// Kontextabhängige Analyse von Push/Pull, Ober-/Unterkörper & Mobilität anhand des Fokus
    static func muscleBalanceInsight(
        from stats: [MuscleGroupStat],
        configuredFocus: PlanFocus = .auto,
        planName: String? = nil
    ) -> MuscleBalanceInsight? {
        guard !stats.isEmpty else { return nil }
        let focus = resolvedPlanFocus(for: configuredFocus, planName: planName, stats: stats)

        let unitCount: ([String]) -> Int = { categories in
            stats
                .filter { categories.contains($0.category.lowercased()) }
                .reduce(0) { $0 + ($1.setCount > 0 ? $1.setCount : $1.exerciseCount) }
        }

        let strengthCategories = Set(["brust", "rücken", "beine", "schultern", "arme", "bauch / core", "chest", "back", "legs", "shoulders", "arms", "abs / core"])
        let totalAllUnits = stats.reduce(0) { $0 + ($1.setCount > 0 ? $1.setCount : $1.exerciseCount) }
        let totalStrengthUnits = stats
            .filter { strengthCategories.contains($0.category.lowercased()) }
            .reduce(0) { $0 + ($1.setCount > 0 ? $1.setCount : $1.exerciseCount) }

        let mobilityUnits = unitCount(["mobilität", "mobility"])
        let chestUnits = unitCount(["brust", "chest"])
        let shoulderUnits = unitCount(["schultern", "shoulders"])
        let pushUnits = chestUnits + shoulderUnits
        let pullUnits = unitCount(["rücken", "back"])
        let legUnits = unitCount(["beine", "legs"])
        let usesSets = stats.contains { $0.setCount > 0 }
        let unitWord = usesSets ? "Sätze" : "Übungen"

        if focus == .mobility {
            guard totalAllUnits >= 1 else { return nil }
            let pct = Int(round((Double(mobilityUnits) / Double(max(totalAllUnits, 1))) * 100))
            if mobilityUnits == 0 {
                return MuscleBalanceInsight(
                    title: "Kein Mobilitätsanteil",
                    message: "Dieser Plan hat den Fokus Mobilität, enthält aber aktuell keine Mobilitätsübungen.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            if pct < 60 {
                return MuscleBalanceInsight(
                    title: "Mobilitätsanteil ausbaufähig",
                    message: "Aktuell entfallen \(pct)% der \(unitWord) (\(mobilityUnits) von \(totalAllUnits)) auf Mobilität.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            return MuscleBalanceInsight(
                title: "Fokus: Mobilität",
                message: "\(mobilityUnits) von \(totalAllUnits) \(unitWord) (\(pct)%) decken gezielt Mobilität und Beweglichkeit ab.",
                isBalanced: true,
                effectiveFocus: focus
            )
        }

        guard totalStrengthUnits >= 4 else { return nil }

        switch focus {
        case .upperBody:
            if pushUnits > 0 && pullUnits == 0 && totalStrengthUnits >= 6 {
                return MuscleBalanceInsight(
                    title: "Rücken-Ausgleich fehlt",
                    message: "Für eine ausgewogene Oberkörper-Einheit empfiehlt sich mindestens eine Zugübung für den Rücken als Ausgleich zu Brust/Schultern.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            if pullUnits > 0 && pushUnits == 0 && totalStrengthUnits >= 6 {
                return MuscleBalanceInsight(
                    title: "Push-Ausgleich fehlt",
                    message: "Im Oberkörper-Fokus ergänzt mindestens eine Druckübung (Brust/Schultern) dein Rückentraining sinnvoll.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            if pullUnits > 0 && Double(pushUnits) > Double(pullUnits) * 2.0 {
                return MuscleBalanceInsight(
                    title: "Push-Dominanz im Oberkörper",
                    message: "Deutlich mehr Druck- (\(pushUnits) \(unitWord)) als Zug-Übungen für den Rücken (\(pullUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            if pushUnits > 0 && Double(pullUnits) > Double(pushUnits) * 2.2 {
                return MuscleBalanceInsight(
                    title: "Zug-Dominanz im Oberkörper",
                    message: "Starker Fokus auf Rücken (\(pullUnits) \(unitWord)) gegenüber Brust/Schultern (\(pushUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            return MuscleBalanceInsight(
                title: "Ausgewogener Oberkörper-Fokus",
                message: "Druck- (\(pushUnits) \(unitWord)) und Zugmuskulatur (\(pullUnits) \(unitWord)) im Oberkörper sind gut ausbalanciert.",
                isBalanced: true,
                effectiveFocus: focus
            )

        case .push:
            if pushUnits == 0 {
                return MuscleBalanceInsight(
                    title: "Keine Push-Übung enthalten",
                    message: "Fokus ist Push, aktuell sind aber keine Brust- oder Schulterübungen enthalten.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            if pullUnits > pushUnits {
                return MuscleBalanceInsight(
                    title: "Abweichung vom Push-Fokus",
                    message: "Der Rücken-Anteil (\(pullUnits) \(unitWord)) überwiegt den Push-Anteil (\(pushUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            return MuscleBalanceInsight(
                title: "Fokus: Push-Einheit",
                message: "Brust (\(chestUnits) \(unitWord)) und Schultern (\(shoulderUnits) \(unitWord)) decken deinen Push-Schwerpunkt gezielt ab.",
                isBalanced: true,
                effectiveFocus: focus
            )

        case .pull:
            if pullUnits == 0 {
                return MuscleBalanceInsight(
                    title: "Keine Rückenübung enthalten",
                    message: "Fokus ist Pull, aktuell enthält die Einheit aber keine Rückenübungen.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            if pushUnits > pullUnits {
                return MuscleBalanceInsight(
                    title: "Abweichung vom Pull-Fokus",
                    message: "Brust/Schultern (\(pushUnits) \(unitWord)) überwiegen aktuell das Rückentraining (\(pullUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            return MuscleBalanceInsight(
                title: "Fokus: Pull-Einheit",
                message: "\(pullUnits) Rücken-\(unitWord) bilden den klaren Schwerpunkt deiner Zug-Einheit.",
                isBalanced: true,
                effectiveFocus: focus
            )

        case .lowerBody:
            if legUnits == 0 {
                return MuscleBalanceInsight(
                    title: "Keine Beinübung enthalten",
                    message: "Fokus ist Unterkörper / Beine, aktuell sind aber keine Beinübungen enthalten.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            let legPct = Int(round((Double(legUnits) / Double(max(totalStrengthUnits, 1))) * 100))
            if legPct < 50 && totalStrengthUnits >= 6 {
                return MuscleBalanceInsight(
                    title: "Bein-Anteil gering",
                    message: "Für einen Bein-Fokus entfallen aktuell nur \(legPct)% (\(legUnits) von \(totalStrengthUnits) \(unitWord)) auf die Beine.",
                    isBalanced: false,
                    effectiveFocus: focus
                )
            }
            return MuscleBalanceInsight(
                title: "Fokus: Unterkörper / Beine",
                message: "\(legUnits) von \(totalStrengthUnits) \(unitWord) (\(legPct)%) zielen gezielt auf deine Beinmuskulatur.",
                isBalanced: true,
                effectiveFocus: focus
            )

        case .fullBody, .auto:
            if Double(legUnits) < Double(totalStrengthUnits) * 0.15 && totalStrengthUnits >= 8 {
                let legPct = Int((Double(legUnits) / Double(totalStrengthUnits)) * 100)
                return MuscleBalanceInsight(
                    title: "Beintraining ausbaufähig",
                    message: "Nur \(legPct)% deiner Kraft-\(unitWord) entfallen auf die Beine (\(legUnits) von \(totalStrengthUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: .fullBody
                )
            }
            if pullUnits > 0 && Double(pushUnits) > Double(pullUnits) * 2.0 {
                return MuscleBalanceInsight(
                    title: "Push-Dominanz erkannt",
                    message: "Deutlich mehr Druck- (\(pushUnits) \(unitWord)) als Zug-Übungen für den Rücken (\(pullUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: .fullBody
                )
            }
            if pushUnits > 0 && Double(pullUnits) > Double(pushUnits) * 2.2 {
                return MuscleBalanceInsight(
                    title: "Zug-Dominanz erkannt",
                    message: "Starker Fokus auf Rücken (\(pullUnits) \(unitWord)) im Vergleich zu Brust/Schultern (\(pushUnits) \(unitWord)).",
                    isBalanced: false,
                    effectiveFocus: .fullBody
                )
            }
            return MuscleBalanceInsight(
                title: "Ausgewogene Ganzkörper-Balance",
                message: "Ober- und Unterkörper sowie Druck- und Zugübungen sind gut aufeinander abgestimmt.",
                isBalanced: true,
                effectiveFocus: .fullBody
            )

        case .mobility:
            return nil
        }
    }
}
