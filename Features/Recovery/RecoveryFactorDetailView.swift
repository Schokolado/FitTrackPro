import SwiftUI
import Charts

struct RecoveryFactorDetailView: View {
    let factor: RecoveryFactor
    let result: RecoveryResult
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                
                VStack(spacing: 16) {
                    Text("Berechnung")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    detailsSection
                }
                
                recommendationSection
            }
            .padding(.vertical, 24)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var title: String {
        switch factor {
        case .sleep: return "Schlaf"
        case .training: return "Trainingsbelastung"
        case .rest: return "Erholungstage"
        case .bio: return "HRV / Ruheherzfrequenz"
        }
    }
    
    private var color: Color {
        switch factor {
        case .sleep: return .indigo
        case .training: return .blue
        case .rest: return .orange
        case .bio: return .red
        }
    }
    
    private var icon: String {
        switch factor {
        case .sleep: return "moon.zzz.fill"
        case .training: return "figure.run"
        case .rest: return "pause.circle.fill"
        case .bio: return "heart.fill"
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 8) {
                switch factor {
                case .sleep:
                    let h = Int(result.rawLastNightSleepHours ?? 0)
                    let m = Int(((result.rawLastNightSleepHours ?? 0) - Double(h)) * 60)
                    let goalH = Int(result.rawSleepGoalHours)
                    Text("\(h)h \(m)m")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("von \(goalH)h Ziel erreicht")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                case .training:
                    Text("\(result.rawWorkoutSessionsLast3Days)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Workouts in den letzten 3 Tagen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                case .rest:
                    Text("\(result.rawDaysSinceLastWorkout)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text(result.rawDaysSinceLastWorkout == 1 ? "Tag seit dem letzten Training" : "Tage seit dem letzten Training")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                case .bio:
                    let hasHRV = result.rawHRV != nil && result.rawHRVBaseline != nil
                    let hasRHR = result.rawRHR != nil && result.rawRHRBaseline != nil
                    
                    if hasHRV || hasRHR {
                        HStack(spacing: 32) {
                            if let hrv = result.rawHRV, let baseHRV = result.rawHRVBaseline {
                                VStack(spacing: 8) {
                                    Text("\(Int(hrv)) ms")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                    Text("HRV (Ø \(Int(baseHRV)))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let rhr = result.rawRHR, let baseRHR = result.rawRHRBaseline {
                                VStack(spacing: 8) {
                                    Text("\(Int(rhr)) bpm")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                    Text("RHR (Ø \(Int(baseRHR)))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("Keine Bio-Daten verfügbar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(spacing: 20) {
            // Explanation Text
            Text(explanationText)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Visualizer (Progress bar or Steps)
            visualizer
            
            Divider()
            
            // Score Result
            HStack {
                Text("Ermittelte Punkte:")
                    .font(.subheadline)
                Spacer()
                Text("\(score) / \(maxScore)")
                    .font(.headline.bold())
                    .foregroundColor(color)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }
    
    private var explanationText: String {
        switch factor {
        case .sleep:
            return "Schlaf ist die wichtigste Komponente der Erholung. Dein Score basiert darauf, wie nah du an dein persönliches Schlafziel herankommst. Ab 100% deines Ziels erhältst du die volle Punktzahl."
        case .training:
            return "Zu viel Training ohne Pausen führt zu Übertraining. Optimal sind 1 bis 2 Trainingseinheiten in den letzten 3 Tagen. Bei mehr als 3 Einheiten werden Punkte abgezogen, da der Körper Zeit zur Regeneration braucht."
        case .rest:
            return "Muskeln wachsen in der Ruhephase, nicht während des Trainings. Mindestens ein voller Ruhetag zwischen den Einheiten bringt dir mehr Punkte für die Erholung."
        case .bio:
            return "Herzfrequenzvariabilität (HRV) und Ruheherzfrequenz (RHR) sind starke Indikatoren für körperlichen Stress. Eine höhere HRV oder niedrigere RHR als dein 7-Tage-Durchschnitt bedeutet, dass dein Körper gut erholt ist."
        }
    }
    
    @ViewBuilder
    private var visualizer: some View {
        switch factor {
        case .sleep:
            let ratio = min((result.rawLastNightSleepHours ?? 0) / result.rawSleepGoalHours, 1.0)
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 12)
                        Capsule().fill(color).frame(width: max(0, geo.size.width * ratio), height: 12)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("0%")
                    Spacer()
                    Text("\(Int(ratio * 100))% erfüllt")
                        .foregroundColor(color)
                        .fontWeight(.bold)
                    Spacer()
                    Text("100%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
        case .training:
            HStack(spacing: 4) {
                stepView(label: "0-1", active: result.rawWorkoutSessionsLast3Days <= 1, points: "Max")
                stepView(label: "2", active: result.rawWorkoutSessionsLast3Days == 2, points: "Gut")
                stepView(label: "3", active: result.rawWorkoutSessionsLast3Days == 3, points: "Moderat")
                stepView(label: ">3", active: result.rawWorkoutSessionsLast3Days > 3, points: "Wenig")
            }
            .padding(.vertical, 8)
            
        case .rest:
            HStack(spacing: 4) {
                stepView(label: "0", active: result.rawDaysSinceLastWorkout == 0, points: "Wenig")
                stepView(label: "1", active: result.rawDaysSinceLastWorkout == 1, points: "Gut")
                stepView(label: "2+", active: result.rawDaysSinceLastWorkout >= 2, points: "Max")
            }
            .padding(.vertical, 8)
            
        case .bio:
            VStack(spacing: 16) {
                if let hrv = result.rawHRV, let baseHRV = result.rawHRVBaseline {
                    let ratio = hrv / baseHRV
                    bioVisualizer(ratio: ratio, isGood: ratio >= 0.95, label: "HRV vs Baseline")
                }
                
                if let rhr = result.rawRHR, let baseRHR = result.rawRHRBaseline {
                    let ratio = baseRHR / rhr // Inverted: baseline 60, current 65 -> 60/65 = 0.92
                    bioVisualizer(ratio: ratio, isGood: ratio >= 1.0, label: "RHR vs Baseline")
                }
            }
        }
    }
    
    private func stepView(label: String, active: Bool, points: String) -> some View {
        VStack {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(active ? .white : .secondary)
            Text(points)
                .font(.caption2)
                .foregroundColor(active ? .white.opacity(0.8) : .secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? color : Color.secondary.opacity(0.1))
        )
    }
    
    private func bioVisualizer(ratio: Double, isGood: Bool, label: String) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 12)
                    Capsule().fill(isGood ? Color.green : color)
                        .frame(width: max(0, geo.size.width * min(ratio, 1.0)), height: 12)
                    
                    // Baseline marker
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 2, height: 20)
                        .offset(x: geo.size.width * (ratio > 1.0 ? 1.0 / ratio : 1.0), y: -4)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text(label)
                Spacer()
                Text(isGood ? "Gut erholt" : "Erschöpft")
                    .foregroundColor(isGood ? .green : color)
                    .fontWeight(.bold)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var score: Int {
        switch factor {
        case .sleep: return result.sleepScore
        case .training: return result.trainingScore
        case .rest: return result.restScore
        case .bio: return result.hrvScore ?? 0
        }
    }
    
    private var maxScore: Int {
        switch factor {
        case .sleep: return result.sleepMax
        case .training: return result.trainingMax
        case .rest: return result.restMax
        case .bio: return result.hrvMax ?? 0
        }
    }
    
    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Tipp für dich")
                    .font(.headline)
            }
            
            Text(recommendationText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.yellow.opacity(0.1))
        )
        .padding(.horizontal)
    }
    
    private var recommendationText: String {
        switch factor {
        case .sleep:
            if result.sleepScore >= result.sleepMax {
                return "Perfekt! Du hast dein Schlafziel erreicht. Behalte diese Routine bei."
            } else {
                return "Versuche, heute etwas früher ins Bett zu gehen. Ein konsistenter Schlafrhythmus hilft der Regeneration enorm."
            }
        case .training:
            if result.rawWorkoutSessionsLast3Days > 3 {
                return "Du hast in letzter Zeit sehr viel trainiert. Ein Rest-Day oder leichtes Stretching wäre heute optimal."
            } else {
                return "Dein Trainingsvolumen ist in einem gesunden Bereich. Du kannst heute bedenkenlos trainieren."
            }
        case .rest:
            if result.rawDaysSinceLastWorkout == 0 {
                return "Du hast gestern erst trainiert. Achte darauf, nicht dieselbe Muskelgruppe an aufeinanderfolgenden Tagen schwer zu belasten."
            } else {
                return "Dein Körper hatte genug Zeit zur Erholung. Du bist bereit für das nächste Workout!"
            }
        case .bio:
            if let score = result.hrvScore, let max = result.hrvMax, score < max {
                return "Dein zentrales Nervensystem zeigt leichten Stress. Das kann an hartem Training, wenig Schlaf oder Alltagsstress liegen. Mach heute etwas ruhiger."
            } else {
                return "Dein Bio-Feedback ist hervorragend. Dein Körper ist anpassungsfähig und voll erholt!"
            }
        }
    }
}

// MARK: - Detailansicht für Belastung / Erholung / Schlaf Ringe

enum VitalRingMetric: String, Identifiable {
    case strain = "Belastung"
    case recovery = "Erholung"
    case sleep = "Schlaf"

    var id: String { rawValue }
}

struct VitalMetricsSnapshot {
    let result: RecoveryResult
    let todaySteps: Int
    let dailyStepGoal: Int
    let todayActiveKcal: Double
    let dailyActiveCalorieGoal: Double
    let sleepSourceLabel: String?

    var hasActivityData: Bool {
        todayActiveKcal > 0 || todaySteps > 0
    }

    var sessionLoadRatio: Double {
        min(1.0, Double(result.rawWorkoutSessionsLast3Days) / 3.0)
    }

    var calorieLoadRatio: Double {
        min(1.0, todayActiveKcal / max(dailyActiveCalorieGoal, 1.0))
    }

    var stepLoadRatio: Double {
        min(1.0, Double(todaySteps) / Double(max(dailyStepGoal, 1)))
    }

    var strainPercent: Int {
        if hasActivityData {
            let blended = (0.4 * sessionLoadRatio) + (0.35 * calorieLoadRatio) + (0.25 * stepLoadRatio)
            return Int((min(1.0, max(0.0, blended)) * 100.0).rounded())
        }
        return Int((sessionLoadRatio * 100.0).rounded())
    }

    var sleepPercent: Int {
        if let sleepHours = result.rawLastNightSleepHours {
            let ratio = min(1.0, max(0.0, sleepHours / max(result.rawSleepGoalHours, 1.0)))
            return Int((ratio * 100.0).rounded())
        }
        let fallback = Double(result.sleepScore) / Double(max(result.sleepMax, 1))
        return Int((min(1.0, max(0.0, fallback)) * 100.0).rounded())
    }

    func percent(for metric: VitalRingMetric) -> Int {
        switch metric {
        case .strain:   return strainPercent
        case .recovery: return result.score
        case .sleep:    return sleepPercent
        }
    }

    static func formattedHoursMinutes(_ hours: Double?) -> String {
        guard let hours else { return "Keine Daten" }
        let totalMinutes = max(0, Int((hours * 60).rounded()))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }
}

struct VitalRingDetailView: View {
    let metric: VitalRingMetric
    let snapshot: VitalMetricsSnapshot
    let accentColor: Color

    private var percent: Int {
        min(max(snapshot.percent(for: metric), 0), 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                meaningCard
                inputsBreakdownCard
                takeawayCard
            }
            .padding(.vertical, 20)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(metric.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Ring

    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.2), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: Double(percent) / 100.0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(percent)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                    Text(metric.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 148, height: 148)

            Text(statusHeadline)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(accentColor.opacity(0.14))
                .foregroundColor(accentColor)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Was bedeutet der Wert?

    private var meaningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Was bedeutet das?", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(accentColor)

            Text(explanationText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    // MARK: - Herangezogene Werte

    private var inputsBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Herangezogene Werte")
                .font(.headline)

            switch metric {
            case .strain:
                let hasAct = snapshot.hasActivityData
                factorProgressRow(
                    icon: "dumbbell.fill",
                    color: .blue,
                    title: "Workouts (letzte 3 Tage)",
                    valueText: "\(snapshot.result.rawWorkoutSessionsLast3Days) / 3 Einheiten",
                    weightText: hasAct ? "Gewichtung: 40%" : "Gewichtung: 100%",
                    progress: snapshot.sessionLoadRatio
                )
                factorProgressRow(
                    icon: "flame.fill",
                    color: .orange,
                    title: "Aktive Kalorien heute",
                    valueText: "\(Int(snapshot.todayActiveKcal)) / \(Int(max(snapshot.dailyActiveCalorieGoal, 1))) kcal",
                    weightText: hasAct ? "Gewichtung: 35%" : "Keine Daten heute",
                    progress: snapshot.calorieLoadRatio
                )
                factorProgressRow(
                    icon: "figure.walk",
                    color: .green,
                    title: "Schritte heute",
                    valueText: "\(snapshot.todaySteps.formatted()) / \(snapshot.dailyStepGoal.formatted())",
                    weightText: hasAct ? "Gewichtung: 25%" : "Keine Daten heute",
                    progress: snapshot.stepLoadRatio
                )

            case .recovery:
                let r = snapshot.result
                factorProgressRow(
                    icon: "moon.zzz.fill",
                    color: .indigo,
                    title: "Schlaf",
                    valueText: "\(r.sleepScore) / \(r.sleepMax) Punkte",
                    weightText: r.rawLastNightSleepHours != nil
                        ? "\(VitalMetricsSnapshot.formattedHoursMinutes(r.rawLastNightSleepHours)) (Ziel \(Int(r.rawSleepGoalHours))h)"
                        : "Schätzwert (keine Schlafdaten)",
                    progress: Double(r.sleepScore) / Double(max(r.sleepMax, 1))
                )
                factorProgressRow(
                    icon: "figure.run",
                    color: .blue,
                    title: "Trainingsfrequenz (3 Tage)",
                    valueText: "\(r.trainingScore) / \(r.trainingMax) Punkte",
                    weightText: "\(r.rawWorkoutSessionsLast3Days) Workout(s) in 3 Tagen",
                    progress: Double(r.trainingScore) / Double(max(r.trainingMax, 1))
                )
                factorProgressRow(
                    icon: "pause.circle.fill",
                    color: .orange,
                    title: "Ruhetage",
                    valueText: "\(r.restScore) / \(r.restMax) Punkte",
                    weightText: r.rawDaysSinceLastWorkout == 1 ? "1 Tag Pause" : "\(r.rawDaysSinceLastWorkout) Tage Pause",
                    progress: Double(r.restScore) / Double(max(r.restMax, 1))
                )
                if r.usesHRV, let hrvPts = r.hrvScore, let hrvMax = r.hrvMax {
                    factorProgressRow(
                        icon: "heart.fill",
                        color: .red,
                        title: "HRV / Ruhepuls",
                        valueText: "\(hrvPts) / \(hrvMax) Punkte",
                        weightText: bioSubtitle(for: r),
                        progress: Double(hrvPts) / Double(max(hrvMax, 1))
                    )
                }

            case .sleep:
                let r = snapshot.result
                let goalHours = r.rawSleepGoalHours
                if let slept = r.rawLastNightSleepHours {
                    factorProgressRow(
                        icon: "moon.zzz.fill",
                        color: .indigo,
                        title: "Schlafdauer letzte Nacht",
                        valueText: "\(VitalMetricsSnapshot.formattedHoursMinutes(slept)) / \(Int(goalHours))h 0m",
                        weightText: "Quelle: \(snapshot.sleepSourceLabel ?? "Erfasst")",
                        progress: min(1.0, slept / max(goalHours, 1.0))
                    )
                } else {
                    factorProgressRow(
                        icon: "moon.zzz.fill",
                        color: .indigo,
                        title: "Schlafdauer letzte Nacht",
                        valueText: "Keine Daten / \(Int(goalHours))h Ziel",
                        weightText: "Standard-Schätzwert (70%) genutzt",
                        progress: Double(r.sleepScore) / Double(max(r.sleepMax, 1))
                    )
                }

                factorProgressRow(
                    icon: "bed.double.fill",
                    color: .teal,
                    title: "Beitrag zur Erholung",
                    valueText: "\(r.sleepScore) / \(r.sleepMax) Punkte",
                    weightText: "Anteil am gesamten Erholungs-Score",
                    progress: Double(r.sleepScore) / Double(max(r.sleepMax, 1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    // MARK: - Praktische Einordnung

    private var takeawayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Einordnung für heute", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.orange)

            Text(takeawayText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }

    private func factorProgressRow(
        icon: String,
        color: Color,
        title: String,
        valueText: String,
        weightText: String,
        progress: Double
    ) -> some View {
        let clamped = min(max(progress, 0), 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(valueText)
                    .font(.subheadline.bold())
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * clamped), height: 6)
                }
            }
            .frame(height: 6)

            Text(weightText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func bioSubtitle(for r: RecoveryResult) -> String {
        var parts: [String] = []
        if let hrv = r.rawHRV { parts.append("HRV \(Int(hrv)) ms") }
        if let rhr = r.rawRHR { parts.append("Ruhepuls \(Int(rhr)) bpm") }
        return parts.isEmpty ? "HRV / Ruhepuls Baseline" : parts.joined(separator: " • ")
    }

    // MARK: - Texte

    private var statusHeadline: String {
        switch metric {
        case .strain:
            if percent < 35 { return "Niedrige Belastung" }
            if percent < 70 { return "Moderate Belastung" }
            return "Hohe Belastung"
        case .recovery:
            return snapshot.result.level.rawValue
        case .sleep:
            if percent < 70 { return "Unter Schlafziel" }
            if percent < 90 { return "Solider Schlaf" }
            return "Schlafziel erreicht"
        }
    }

    private var explanationText: String {
        switch metric {
        case .strain:
            return "Die Belastung (0–100%) zeigt, wie stark dein Körper aktuell beansprucht ist. Dazu kombiniert sie deine Workouts der letzten 3 Tage (Referenz: 3 Einheiten), deine heutigen aktiven Kalorien (Ziel: \(Int(max(snapshot.dailyActiveCalorieGoal, 1))) kcal) und deine heutigen Schritte gegen dein Tagesziel."
        case .recovery:
            return "Die Erholung (0–100%) beschreibt, wie gut dein Körper regeneriert und bereit für Belastung ist. Sie setzt sich aus Schlaf, Trainingsfrequenz, Erholungstagen und – sofern von der Apple Watch verfügbar – HRV bzw. Ruhepuls im Vergleich zu deinem 7-Tage-Durchschnitt zusammen."
        case .sleep:
            return "Der Schlafwert zeigt direkt in Prozent, wie viel deines persönlichen Schlafziels (\(Int(snapshot.result.rawSleepGoalHours)) Stunden) du in der letzten Nacht erreicht hast."
        }
    }

    private var takeawayText: String {
        switch metric {
        case .strain:
            if percent < 35 {
                return "Du hast aktuell wenig Vorbelastung. Wenn deine Erholung hoch ist, ist heute ein idealer Tag für ein intensives Training."
            } else if percent < 70 {
                return "Du hast ein aktives, gesundes Pensum. Mit guter Erholung (z. B. > 70%) kannst du problemlos weiter trainieren."
            } else {
                return "Du hast in den letzten Tagen und heute schon viel geleistet. Achte auf ausreichend Schlaf, Protein und plane bei Müdigkeit eine lockere Einheit ein."
            }
        case .recovery:
            return snapshot.result.level.description
        case .sleep:
            if percent >= 90 {
                return "Sehr stark – dein Schlafziel ist praktisch erreicht. Das ist die beste Grundlage für Muskelaufbau und Leistungsfähigkeit."
            } else if percent >= 70 {
                return "Gute Basis für den Tag, auch wenn noch etwas zum Idealziel fehlt. Wenn deine Erholung insgesamt hoch ist, steht dem Training nichts im Weg."
            } else {
                return "Deutlich weniger Schlaf als dein Ziel. Halte das Training heute etwas kontrollierter und versuche heute Abend früher zu schlafen."
            }
        }
    }
}

// MARK: - Trainingsbelastung & Fitness-Status UI

extension TrainingStatus {
    var color: Color {
        switch self {
        case .detraining:   return .gray
        case .recovery:     return .teal
        case .maintaining:  return .blue
        case .productive:   return .green
        case .peaking:      return .purple
        case .overreaching: return .red
        }
    }
}

struct TrainingLoadSummaryCard: View {
    let analysis: TrainingLoadAnalysis

    private var status: TrainingStatus { analysis.currentStatus }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: status.systemIcon)
                    .font(.title2)
                    .foregroundColor(status.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(status.subtitle)
                        .font(.caption)
                        .foregroundColor(status.color)
                }

                Spacer()

                Text(String(format: "%.2f×", analysis.acwr))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(status.color.opacity(0.14))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                metricBox(title: "Akute Last (7T)", value: "\(Int(analysis.acuteLoad.rounded()))")
                metricBox(title: "Chronische Basis (28T Ø)", value: "\(Int(analysis.chronicLoad.rounded()))")
                metricBox(title: "Workouts (7T / 28T)", value: "\(analysis.workoutsLast7Days) / \(analysis.workoutsLast28Days)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.backgroundPrimary.opacity(0.6))
        .cornerRadius(10)
    }
}

struct TrainingLoadDetailView: View {
    let analysis: TrainingLoadAnalysis

    private var status: TrainingStatus { analysis.currentStatus }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusHeroCard
                acuteVsChronicCard
                loadTrendChartCard
                statusTimelineCard
            }
            .padding(.vertical, 20)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Fitness-Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusHeroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: status.systemIcon)
                    .font(.system(size: 38))
                    .foregroundColor(status.color)
            }

            VStack(spacing: 4) {
                Text(status.rawValue)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text(status.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(status.color)
            }

            Text(status.explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private var acuteVsChronicCard: some View {
        let ratio = analysis.acwr
        let clampedMarker = min(max(ratio / 2.0, 0.0), 1.0) // 0.0...2.0 -> 0...1

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Akute vs. Chronische Belastung")
                    .font(.headline)
                Spacer()
                Text(String(format: "ACWR %.2f×", ratio))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Akut (letzte 7 Tage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(analysis.acuteLoad.rounded()))")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundColor(status.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.backgroundPrimary.opacity(0.6))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Chronisch (28T Ø/Woche)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(analysis.chronicLoad.rounded()))")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.backgroundPrimary.opacity(0.6))
                .cornerRadius(12)
            }

            // ACWR Zonen-Skala (0.0 ... 2.0)
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.35))
                                .frame(width: geo.size.width * 0.40) // < 0.8 Unterlast
                            RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.55))
                                .frame(width: geo.size.width * 0.32) // 0.8 - 1.45 Optimal / Aufbau
                            RoundedRectangle(cornerRadius: 3).fill(Color.red.opacity(0.5))
                        }
                        .frame(height: 8)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(status.color, lineWidth: 3))
                            .offset(x: max(0, min(geo.size.width - 14, geo.size.width * clampedMarker - 7)))
                    }
                }
                .frame(height: 14)

                HStack {
                    Text("< 0,8 Unterlast")
                    Spacer()
                    Text("0,8–1,45 Optimal")
                    Spacer()
                    Text("> 1,45 Überlast")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private var loadTrendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Belastungsverlauf (6 Wochen)")
                    .font(.headline)
                Spacer()
                HStack(spacing: 10) {
                    Label("Akut", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(status.color)
                    Label("Basis", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if analysis.historyPoints.allSatisfy({ $0.acuteLoad == 0 && $0.chronicLoad == 0 }) {
                Text("Noch keine abgeschlossenen Workouts in den letzten 6 Wochen vorhanden.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart(analysis.historyPoints) { point in
                    AreaMark(
                        x: .value("Datum", point.date),
                        y: .value("Akute Last", point.acuteLoad)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [status.color.opacity(0.28), status.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("Akute Last", point.acuteLoad)
                    )
                    .foregroundStyle(status.color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("Chronische Basis", point.chronicLoad)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 4]))
                }
                .frame(height: 170)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private var statusTimelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status-Verlauf (wann aufgetreten)")
                .font(.headline)

            if analysis.statusTimeline.isEmpty {
                Text("Noch kein Status-Verlauf verfügbar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(analysis.statusTimeline.enumerated()), id: \.element.id) { idx, period in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(period.status.color)
                                    .frame(width: 12, height: 12)
                                    .padding(.top, 4)
                                if idx < analysis.statusTimeline.count - 1 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.25))
                                        .frame(width: 2)
                                        .frame(minHeight: 34)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(period.status.rawValue)
                                        .font(.subheadline.bold())
                                        .foregroundColor(period.status.color)
                                    Spacer()
                                    Text(period.days == 1 ? "1 Tag" : "\(period.days) Tage")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.backgroundPrimary.opacity(0.7))
                                        .clipShape(Capsule())
                                }

                                Text(periodDateRangeText(period))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, idx < analysis.statusTimeline.count - 1 ? 12 : 0)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private func periodDateRangeText(_ period: TrainingStatusPeriod) -> String {
        let cal = Calendar.current
        let startStr = period.startDate.formatted(.dateTime.day().month())
        if cal.isDateInToday(period.endDate) {
            return cal.isDate(period.startDate, inSameDayAs: period.endDate) ? "Heute" : "\(startStr) – Heute"
        }
        if cal.isDate(period.startDate, inSameDayAs: period.endDate) {
            return startStr
        }
        let endStr = period.endDate.formatted(.dateTime.day().month())
        return "\(startStr) – \(endStr)"
    }
}

// MARK: - Biologisches Alter / Fitness-Alter UI

extension FitnessAgeFactorKind {
    var color: Color {
        switch self {
        case .rhr:      return .red
        case .steps:    return .green
        case .workouts: return .blue
        case .sleep:    return .indigo
        case .waist:    return .orange
        case .bodyFat:  return .mint
        case .bmi:      return .purple
        case .vo2max:   return .teal
        }
    }
}

struct FitnessAgeSummaryCard: View {
    let result: FitnessAgeResult

    private var accentColor: Color {
        if result.ageDifference < 0 { return .green }
        if result.ageDifference == 0 { return .teal }
        return .orange
    }

    private var deltaBadgeText: String {
        if result.ageDifference < 0 {
            return "\(abs(result.ageDifference)) J. jünger"
        } else if result.ageDifference == 0 {
            return "Im Schnitt"
        } else {
            return "+\(result.ageDifference) J. älter"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 54, height: 54)
                VStack(spacing: 0) {
                    Text("\(result.estimatedFitnessAge)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(accentColor)
                    Text("Jahre")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Fitness-Alter")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(result.hasBirthDate
                     ? "Chronologisch: \(result.chronologicalAge) Jahre"
                     : "Geburtsdatum in Einstellungen ergänzen")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(deltaBadgeText)
                .font(.caption.bold())
                .foregroundColor(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accentColor.opacity(0.14))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
    }
}

struct FitnessAgeDetailView: View {
    let result: FitnessAgeResult

    private var accentColor: Color {
        if result.ageDifference < 0 { return .green }
        if result.ageDifference == 0 { return .teal }
        return .orange
    }

    private var deltaSummaryText: String {
        if result.ageDifference < 0 {
            return "Dein geschätztes Fitness-Alter liegt \(abs(result.ageDifference)) Jahre unter deinem chronologischen Alter."
        } else if result.ageDifference == 0 {
            return "Dein geschätztes Fitness-Alter entspricht aktuell deinem chronologischen Alter."
        } else {
            return "Dein geschätztes Fitness-Alter liegt \(result.ageDifference) Jahre über deinem chronologischen Alter – mit gezielten Routinen lässt sich das senken."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroComparisonCard

                if !result.hasBirthDate {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Hinterlege dein Geburtsdatum in den Einstellungen, damit der Vergleich mit deinem echten Alter exakt stimmt (aktuell Basis 30 Jahre).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
                    .padding(.horizontal)
                }

                factorsCard
                improvementTipsCard
            }
            .padding(.vertical, 20)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Fitness-Alter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroComparisonCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(accentColor.opacity(0.25), lineWidth: 10)
                        Circle()
                            .fill(accentColor.opacity(0.12))
                        VStack(spacing: 2) {
                            Text("\(result.estimatedFitnessAge)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Fitness-Alter")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(accentColor)
                        }
                    }
                    .frame(width: 118, height: 118)
                }

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chronologisch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(result.chronologicalAge) Jahre")
                            .font(.title3.bold())
                    }

                    Text(String(format: "%@%.1f Jahre", result.rawDeltaYears >= 0 ? "+" : "", result.rawDeltaYears))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            Text(deltaSummaryText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private var factorsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Einflussfaktoren")
                .font(.headline)

            ForEach(result.factors) { factor in
                HStack(spacing: 12) {
                    Image(systemName: factor.systemIcon)
                        .font(.subheadline)
                        .foregroundColor(factor.kind.color)
                        .frame(width: 32, height: 32)
                        .background(factor.kind.color.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(factor.valueText) • \(factor.targetText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if factor.hasData {
                        let d = factor.deltaYears
                        let impactColor: Color = d < -0.1 ? .green : (d > 0.1 ? .orange : .secondary)
                        Text(String(format: "%@%.1f J", d > 0 ? "+" : "", d))
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(impactColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(impactColor.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Text("Offen")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal)
    }

    private var improvementTipsCard: some View {
        let improvable = result.factors
            .filter { $0.hasData && $0.deltaYears > 0.1 }
            .sorted { $0.deltaYears > $1.deltaYears }

        return VStack(alignment: .leading, spacing: 12) {
            Label(
                improvable.isEmpty ? "Starke Gesundheits-Routine" : "Größte Hebel zum Senken",
                systemImage: improvable.isEmpty ? "checkmark.seal.fill" : "lightbulb.fill"
            )
            .font(.headline)
            .foregroundColor(improvable.isEmpty ? .green : .orange)

            if improvable.isEmpty {
                Text("Alle erfassten Faktoren wirken sich positiv oder stabil auf dein Fitness-Alter aus. Halte diese Konsistenz bei!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(improvable.prefix(3)) { factor in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: factor.systemIcon)
                            .font(.caption)
                            .foregroundColor(factor.kind.color)
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(factor.title)
                                .font(.subheadline.bold())
                            Text(factor.tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill((improvable.isEmpty ? Color.green : Color.orange).opacity(0.1))
        )
        .padding(.horizontal)
    }
}
