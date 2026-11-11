import Foundation

// MARK: - ExerciseGroup
// Represents either a single exercise or a group of exercises linked as a superset.

struct ExerciseGroup: Identifiable {
    var id: String {
        if let groupId = supersetGroupId {
            return "superset-\(groupId)"
        } else {
            return "single-\(exercises.first?.id.uuidString ?? UUID().uuidString)"
        }
    }
    var exercises: [PlanExercise]
    var supersetGroupId: Int?
}

// MARK: - TrainingPlan + Grouping

extension TrainingPlan {
    /// Returns the plan's exercises sorted by `sortOrder` and grouped into superset blocks.
    var groupedPlanExercises: [ExerciseGroup] {
        let validExercises = (planExercises ?? []).filter { $0.exercise != nil }
        let sorted = validExercises.sorted { $0.sortOrder < $1.sortOrder }
        var groups: [ExerciseGroup] = []
        
        for exercise in sorted {
            // Feature temporarily hidden: ignoring supersetGroup
            groups.append(ExerciseGroup(exercises: [exercise], supersetGroupId: nil))
        }
        
        return groups
    }

    /// Geschätzte Gesamtdauer des Trainingsplans in Sekunden (Sätze + Pausen + Gerätewechsel).
    var estimatedDurationSeconds: TimeInterval {
        let activeExercises = (planExercises ?? [])
            .filter { $0.exercise != nil && $0.targetSets > 0 }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard !activeExercises.isEmpty else { return 0 }

        var totalSeconds: TimeInterval = 0

        for (index, item) in activeExercises.enumerated() {
            let sets = max(1, item.targetSets)
            let workPerSet: TimeInterval = {
                if let exercise = item.exercise, exercise.usesTimeInput {
                    if exercise.effectiveTimeUnit == "Min" {
                        return TimeInterval(max(item.targetReps, 1)) * 60.0
                    } else {
                        return TimeInterval(max(item.targetReps, 10))
                    }
                }
                let reps = max(1, item.targetReps)
                return max(25.0, Double(reps) * 3.5 + 10.0)
            }()

            let rest = max(0, item.restDuration)
            totalSeconds += Double(sets) * workPerSet
            totalSeconds += Double(max(0, sets - 1)) * rest

            if index < activeExercises.count - 1 {
                totalSeconds += min(max(rest, 45.0), 90.0)
            }
        }

        return totalSeconds
    }

    /// Formatierte Kurz-Schätzung für Plan-Karten und Detail-Header (z. B. "~45 Min").
    var estimatedDurationText: String? {
        let totalSeconds = estimatedDurationSeconds
        guard totalSeconds > 0 else { return nil }
        let totalMinutes = max(1, Int((totalSeconds / 60.0).rounded()))
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins == 0 ? "~\(hours) Std." : "~\(hours)h \(mins)m"
        }
        return "~\(totalMinutes) Min"
    }
}
