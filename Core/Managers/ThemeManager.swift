import SwiftUI
import Combine
import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Hell"
    case dark = "Dunkel"
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var categoryColors: [String: String] = [:]

    private func saveColors() {
        if let data = try? JSONEncoder().encode(categoryColors) {
            UserDefaults.standard.set(data, forKey: "categoryColorsHex")
        }
    }
    
    let standardCategories = [
        "Brust", "Rücken", "Beine", "Schultern", "Arme", "Bauch / Core", "Cardio", "Ganzkörper"
    ]
    
    private let defaultColors: [String: Color] = [
        "brust": .blue, "chest": .blue,
        "rücken": .indigo, "back": .indigo,
        "beine": .orange, "legs": .orange,
        "schultern": .purple, "shoulders": .purple,
        "arme": .cyan, "arms": .cyan,
        "bauch / core": .green, "abs / core": .green,
        "cardio": .red,
        "ganzkörper": .mint, "full body": .mint
    ]
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "categoryColorsHex"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.categoryColors = decoded
        }
    }
    
    func color(for category: String) -> Color {
        let key = category.lowercased()
        if let hex = categoryColors[key] {
            return Color(hex: hex)
        }
        return defaultColors[key] ?? .gray
    }
    
    func setColor(_ color: Color, for category: String) {
        let key = category.lowercased()
        categoryColors[key] = color.toHex()
        saveColors()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#808080" }
        let r = components.count >= 1 ? components[0] : 0.0
        let g = components.count >= 2 ? components[1] : 0.0
        let b = components.count >= 3 ? components[2] : 0.0
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }
}
