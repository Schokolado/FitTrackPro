import SwiftUI

struct SettingsView: View {
    @AppStorage("prefillExerciseHistory") private var prefillExerciseHistory = true
    
    @AppStorage("timerFav1") private var timerFav1: Int = 30
    @AppStorage("timerFav2") private var timerFav2: Int = 60
    @AppStorage("timerFav3") private var timerFav3: Int = 90
    @AppStorage("requireRestTimerConfirm") private var requireRestTimerConfirm = true
    
    @AppStorage("nutritionGoalCalories") private var nutritionGoalCalories: Double = 2000
    @AppStorage("nutritionGoalProtein") private var nutritionGoalProtein: Double = 150
    @AppStorage("nutritionGoalCarbs") private var nutritionGoalCarbs: Double = 250
    @AppStorage("nutritionGoalFat") private var nutritionGoalFat: Double = 70
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Trainingsplan")) {
                    Toggle("Werte aus Historie übernehmen", isOn: $prefillExerciseHistory)
                    Text("Wenn aktiviert, werden beim Hinzufügen einer Übung zum Plan automatisch die Sätze, Wiederholungen und Gewichte aus dem letzten Training übernommen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Darstellung")) {
                    NavigationLink("Farben & Kategorien") {
                        ThemeSettingsView()
                    }
                }
                
                Section(header: Text("Pausen-Timer")) {
                    Toggle("Vorzeitiges Beenden bestätigen", isOn: $requireRestTimerConfirm)
                    
                    Stepper("Favorit 1: \(timerFav1) Sek", value: $timerFav1, in: 10...300, step: 10)
                    Stepper("Favorit 2: \(timerFav2) Sek", value: $timerFav2, in: 10...300, step: 10)
                    Stepper("Favorit 3: \(timerFav3) Sek", value: $timerFav3, in: 10...300, step: 10)
                }
                
                Section(header: Text("Ernährungs-Ziele")) {
                    HStack {
                        Text("Kalorien")
                        Spacer()
                        TextField("kcal", value: $nutritionGoalCalories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("g", value: $nutritionGoalProtein, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Kohlenhydrate (g)")
                        Spacer()
                        TextField("g", value: $nutritionGoalCarbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fett (g)")
                        Spacer()
                        TextField("g", value: $nutritionGoalFat, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .withMiniPlayerSafeArea()
            .navigationTitle("Einstellungen")
        }
    }
}
