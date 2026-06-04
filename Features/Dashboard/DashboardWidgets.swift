import SwiftUI
import SwiftData

struct NutritionSummaryCard: View {
    let consumed: Double
    let goal: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    
    var progress: Double {
        min(consumed / max(goal, 1), 1.0)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.brand.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.brand)
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
                
                Text("\(Int(max(goal - consumed, 0))) kcal verbleibend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
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
            Text("\(value)g \(label)")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}

struct WeightSummaryCard: View {
    let entries: [WeightEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(.brand)
                    .font(.title2)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
                    .font(.title2)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let workout = workouts.first {
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
                    Text("Tippen zum Starten")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}

struct WaterTrackerMockupCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
                    .font(.title2)
                Spacer()
                Text("Coming Soon")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Wasser")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("1.2 L")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("von 2.5 L")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

struct SleepTrackerMockupCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
                    .font(.title2)
                Spacer()
                Text("Coming Soon")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.indigo.opacity(0.2))
                    .foregroundColor(.indigo)
                    .clipShape(Capsule())
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Schlaf")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("7h 15m")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Gute Qualität")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

struct RecoveryMockupCard: View {
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.teal.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: 0.85)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Image(systemName: "battery.100.bolt")
                        .foregroundColor(.teal)
                        .font(.caption)
                    Text("85%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 90, height: 90)
            
            // Texts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Akku / Recovery")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.teal.opacity(0.2))
                        .foregroundColor(.teal)
                        .clipShape(Capsule())
                }
                
                Text("Bereit für ein intensives Training heute!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Stimmung (Heute)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Wie fühlst du dich heute?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.yellow)
                .font(.title2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.backgroundSecondary)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
}
