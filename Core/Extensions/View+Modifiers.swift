import SwiftUI

// MARK: - Card Style Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.backgroundCard)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonModifier: ViewModifier {
    var backgroundColor: Color = .brand

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

extension View {
    func primaryButtonStyle(backgroundColor: Color = .brand) -> some View {
        self.modifier(PrimaryButtonModifier(backgroundColor: backgroundColor))
    }
}
