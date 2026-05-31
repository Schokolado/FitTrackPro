import SwiftUI

struct ExerciseCardView: View {
    let exercise: Exercise
    
    private var categoryColor: Color {
        switch exercise.category.lowercased() {
        case "brust": return .blue
        case "rücken": return .indigo
        case "beine": return .orange
        case "schultern": return .purple
        case "arme": return .cyan
        case "bauch": return .green
        case "cardio": return .red
        case "ganzkörper": return .mint
        default: return .gray
        }
    }
    
    private var categoryIcon: String {
        switch exercise.category.lowercased() {
        case "brust": return "figure.strengthtraining.traditional"
        case "rücken": return "figure.core.training"
        case "beine": return "figure.run"
        case "schultern": return "figure.cross.training"
        case "arme": return "figure.mind.and.body"
        case "bauch": return "figure.pilates"
        case "cardio": return "heart.fill"
        case "ganzkörper": return "figure.highintensity.intervaltraining"
        default: return "dumbbell.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [categoryColor.opacity(0.7), categoryColor]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Image(systemName: categoryIcon)
                    .foregroundColor(.white)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Category Badge
                Text(exercise.category.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Color(.systemGray3))
                .font(.footnote.weight(.semibold))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
