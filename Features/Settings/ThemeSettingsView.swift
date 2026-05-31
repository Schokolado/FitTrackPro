import SwiftUI
import SwiftData

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Query private var exercises: [Exercise]
    
    private var allCategories: [String] {
        var uniqueCategories = [String: String]()
        
        for cat in themeManager.standardCategories {
            uniqueCategories[cat.lowercased()] = cat
        }
        
        for exercise in exercises {
            let cat = exercise.category.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cat.isEmpty, uniqueCategories[cat.lowercased()] == nil {
                uniqueCategories[cat.lowercased()] = cat
            }
        }
        
        let legacyAliases = ["chest", "back", "legs", "shoulders", "arms", "abs / core", "full body"]
        for key in themeManager.categoryColors.keys {
            if uniqueCategories[key] == nil && !legacyAliases.contains(key) {
                let capitalized = key.prefix(1).uppercased() + key.dropFirst()
                uniqueCategories[key] = String(capitalized)
            }
        }
        
        return uniqueCategories.values.sorted()
    }
    
    var body: some View {
        Form {
            Section(header: Text("Kategorien"), footer: Text("Hier kannst du eigene Farben für alle deine genutzten Muskelgruppen und Kategorien festlegen. Wenn du eine neue Kategorie erstellst, erscheint sie automatisch hier.")) {
                ForEach(allCategories, id: \.self) { category in
                    ColorPicker(category, selection: Binding(
                        get: { themeManager.color(for: category) },
                        set: { themeManager.setColor($0, for: category) }
                    ))
                }
            }
        }
        .navigationTitle("Farben & Kategorien")
        .navigationBarTitleDisplayMode(.inline)
    }
}
