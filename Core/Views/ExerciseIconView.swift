import SwiftUI

struct ExerciseIconView: View {
    let exercise: Exercise
    var size: CGFloat = 20

    var body: some View {
        if let customIconName = exercise.customIconName,
           UIImage(named: customIconName) != nil {
            Image(customIconName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: exercise.themeIcon)
                .font(.system(size: size * 0.85)) // Adjust SF Symbol size to match custom icons visually
        }
    }
}
