import SwiftUI

extension Color {
    // Brand Colors
    static let brand = Color.blue // Später durch Assets Color "BrandPrimary" ersetzen
    static let brandSecondary = Color.cyan // Später durch Assets Color "BrandSecondary" ersetzen
    
    // Semantic Colors
    static let success = Color.green
    static let warning = Color.orange
    static let destructive = Color.red
    
    // Background Colors
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let backgroundCard = Color(uiColor: .tertiarySystemBackground)
    
    // Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
