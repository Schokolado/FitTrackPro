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
    let sleepSourceLabel: String?

    var hasActivityData: Bool {
        todayActiveKcal > 0 || todaySteps > 0
    }

    var sessionLoadRatio: Double {
        min(1.0, Double(result.rawWorkoutSessionsLast3Days) / 3.0)
    }

    var calorieLoadRatio: Double {
        min(1.0, todayActiveKcal / 600.0)
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
                    valueText: "\(Int(snapshot.todayActiveKcal)) / 600 kcal",
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
            return "Die Belastung (0–100%) zeigt, wie stark dein Körper aktuell beansprucht ist. Dazu kombiniert sie deine Workouts der letzten 3 Tage (Referenz: 3 Einheiten), deine heutigen aktiven Kalorien (Referenz: 600 kcal) und deine heutigen Schritte gegen dein Tagesziel."
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
