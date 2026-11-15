import SwiftUI

struct ExerciseCardView: View {
    let exercise: Exercise
    
    @EnvironmentObject var themeManager: ThemeManager
    
    private var categoryColor: Color {
        themeManager.color(for: exercise.category)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 50, height: 50)
                    
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [categoryColor.opacity(0.7), categoryColor]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                ExerciseIconView(exercise: exercise, size: 24)
                    .foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 1, y: 0)
            
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
