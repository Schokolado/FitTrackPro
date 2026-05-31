import SwiftUI

// MARK: - SupersetIconStack
// Overlapping mini icon stack for collapsed superset display.
// Renders up to 3 category icons (28 × 28 pt) with −10 pt overlap,
// separated by a thin background-coloured border ring — inspired by
// the avatar-stack pattern used in Notion / Linear / GitHub.
struct SupersetIconStack: View {
    let exercises: [Exercise]
    @EnvironmentObject var themeManager: ThemeManager

    private let iconSize: CGFloat = 28
    private let overlap: CGFloat = 14 // Increased overlap to bring them closer

    private var step: CGFloat { iconSize - overlap }
    private var displayExercises: [Exercise] { Array(exercises.prefix(3)) }
    private var totalWidth: CGFloat {
        iconSize + CGFloat(max(0, displayExercises.count - 1)) * step
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(displayExercises.enumerated()), id: \.offset) { index, exercise in
                ZStack {
                    // Gradient fill (no border ring to be consistent with normal icons)
                    Circle()
                        .fill(LinearGradient(
                            colors: [
                                themeManager.color(for: exercise.category).opacity(0.7),
                                themeManager.color(for: exercise.category)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: iconSize, height: iconSize)

                    // Category icon
                    ExerciseIconView(exercise: exercise, size: 13)
                        .foregroundColor(.white)
                }
                // First icon on top (highest z), subsequent icons behind
                .zIndex(Double(displayExercises.count - index))
                .offset(x: CGFloat(index) * step)
            }
        }
        .frame(width: totalWidth, height: iconSize, alignment: .leading)

    }
}
