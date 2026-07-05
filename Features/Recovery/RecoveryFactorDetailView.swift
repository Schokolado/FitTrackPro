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
                    if let hrv = result.rawHRV, let baseHRV = result.rawHRVBaseline {
                        Text("\(Int(hrv)) ms")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("Aktuelle HRV (Ø \(Int(baseHRV)) ms)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let rhr = result.rawRHR, let baseRHR = result.rawRHRBaseline {
                        Text("\(Int(rhr)) bpm")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("Ruheherzfrequenz (Ø \(Int(baseRHR)) bpm)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
            if let hrv = result.rawHRV, let baseHRV = result.rawHRVBaseline {
                let ratio = hrv / baseHRV
                bioVisualizer(ratio: ratio, isGood: ratio >= 0.95, label: "HRV vs Baseline")
            } else if let rhr = result.rawRHR, let baseRHR = result.rawRHRBaseline {
                let ratio = baseRHR / rhr // Inverted: baseline 60, current 65 -> 60/65 = 0.92
                bioVisualizer(ratio: ratio, isGood: ratio >= 1.0, label: "RHR vs Baseline")
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
