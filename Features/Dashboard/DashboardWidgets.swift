import SwiftUI
import SwiftData

struct NutritionSummaryCard: View {
    let consumed: Double
    let goal: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    var tolerance: Double = 300
    var eveningHour: Int = 18
    
    var progress: Double {
        min(consumed / max(goal, 1), 1.0)
    }

    private var ringState: CalorieRingState {
        CalorieRingEvaluator.evaluate(
            consumed: consumed,
            goal: goal,
            tolerance: tolerance,
            eveningHour: eveningHour
        )
    }

    private var remainingText: String {
        if consumed > goal {
            return "+\(Int(consumed - goal)) kcal über Ziel"
        }
        return "\(Int(max(goal - consumed, 0))) kcal verbleibend"
    }

    private var remainingColor: Color {
        switch ringState {
        case .surplusWarning: return .destructive
        case .eveningDeficitWarning: return .warning
        case .normal, .onTrack: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(ringState.color.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringState.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(ringState.color)
                        .font(.caption)
                    Text("\(Int(consumed))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 90, height: 90)
            
            // Texts
            VStack(alignment: .leading, spacing: 8) {
                Text("Ernährung heute")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(remainingText)
                    .font(.subheadline)
                    .foregroundColor(remainingColor)
                    
                HStack(spacing: 12) {
                    MacroBadge(label: "K", value: Int(carbs), color: .blue)
                    MacroBadge(label: "P", value: Int(protein), color: .purple)
                    MacroBadge(label: "F", value: Int(fat), color: .orange)
                }
                .padding(.top, 4)
            }
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(20)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}

struct MacroBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) \(value)g")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}

struct WeightSummaryCard: View {
    let entries: [WeightEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "scalemass")
                    .foregroundColor(.brand)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Gewicht")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let latest = entries.first {
                    Text("\(latest.weightKg, specifier: "%.1f") kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                    if entries.count > 1 {
                        let diff = latest.weightKg - entries[1].weightKg
                        let color: Color = diff > 0 ? .red : (diff < 0 ? .green : .secondary)
                        Text(String(format: "%@%.1f kg", diff > 0 ? "+" : "", diff))
                            .font(.caption.bold())
                            .foregroundColor(color)
                    } else {
                        Text("Erster Eintrag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("-- kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}

struct TrainingSummaryCard: View {
    let workouts: [WorkoutSession]
    var activeSession: WorkoutSession? = nil
    var lastWorkout: WorkoutSession? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
                    .font(.title2)
                    .frame(width: 28, height: 28)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let active = activeSession {
                    Text("Laufend")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.brand)
                    Text(active.plan?.name ?? "Freies Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if workouts.count > 1 {
                    Text("\(workouts.count) Erledigt")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Historie ansehen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let workout = workouts.first {
                    Text("Erledigt")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text(workout.plan?.name ?? "Freies Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Anstehend")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    if let last = lastWorkout {
                        Text("\(formatLastWorkoutDate(last.startTime)): \(last.plan?.name ?? "Freies Workout")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Tippen zum Starten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
    
    private func formatLastWorkoutDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) {
            return "Gestern"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM."
            return formatter.string(from: date)
        }
    }
}

struct StepSummaryCard: View {
    let steps: Int
    let goal: Int
    
    var progress: Double {
        min(Double(steps) / max(Double(goal), 1), 1.0)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(steps)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: 90, height: 90)
            
            // Texts
            VStack(alignment: .leading, spacing: 8) {
                Text("Schritte heute")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(max(goal - steps, 0)) Schritte verbleibend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(20)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}



struct CalorieBurnSummaryCard: View {
    let consumed: Double
    let effectiveGoal: Double
    let activeBurned: Double?
    let totalBurned: Double?

    private var balanceValue: Int {
        let reference = totalBurned ?? effectiveGoal
        return Int((consumed - reference).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Umsatz & Bilanz", systemImage: "flame.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                burnMetric(
                    title: "Aktiv verbrannt",
                    value: activeBurned.map { "\(Int($0)) kcal" } ?? "–",
                    color: .orange
                )

                burnMetric(
                    title: "Tagesumsatz",
                    value: totalBurned.map { "\(Int($0)) kcal" } ?? "–",
                    color: .brand
                )

                let prefix = balanceValue > 0 ? "+" : ""
                burnMetric(
                    title: totalBurned != nil ? "vs. Umsatz" : "vs. Ziel",
                    value: "\(prefix)\(balanceValue) kcal",
                    color: balanceValue <= 0 ? .green : .orange
                )
            }
        }
        .padding(20)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }

    private func burnMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MoodSummaryCard: View {
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                
                Image(systemName: "face.smiling.fill")
                    .foregroundColor(.yellow)
                    .font(.title)
            }
            .frame(width: 60, height: 60)
            
            // Texts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stimmung")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.yellow)
                        .clipShape(Capsule())
                }
                
                Text("Wie fühlst du dich heute?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}
