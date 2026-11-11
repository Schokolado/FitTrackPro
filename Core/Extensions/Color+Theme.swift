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
    static let backgroundPrimary = Color(uiColor: .systemGroupedBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemGroupedBackground)
    static let backgroundCard = Color(uiColor: .secondarySystemGroupedBackground)
    
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

// MARK: - Dynamic Calorie Ring Evaluation

enum CalorieRingState: Equatable {
    case normal
    case onTrack
    case eveningDeficitWarning
    case surplusWarning

    var color: Color {
        switch self {
        case .normal: return .brand
        case .onTrack: return .success
        case .eveningDeficitWarning: return .warning
        case .surplusWarning: return .destructive
        }
    }
}

enum CalorieRingEvaluator {
    /// Evaluates calorie ring status for a given day using the configured ±tolerance and evening cutoff hour.
    static func evaluate(
        consumed: Double,
        goal: Double,
        tolerance: Double,
        date: Date = Date(),
        eveningHour: Int = 18,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CalorieRingState {
        let safeGoal = max(goal, 1)
        let safeTolerance = max(tolerance, 0)
        let diff = consumed - safeGoal

        if diff > safeTolerance {
            return .surplusWarning
        }

        let startOfDay = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: now)
        if startOfDay > startOfToday {
            return .normal
        }

        let isPastDay = startOfDay < startOfToday
        let isEveningOrPast = isPastDay || calendar.component(.hour, from: now) >= eveningHour

        if isEveningOrPast && (safeGoal - consumed) > safeTolerance {
            return .eveningDeficitWarning
        }

        if abs(diff) <= safeTolerance && consumed > 0 {
            return .onTrack
        }

        return .normal
    }
}
