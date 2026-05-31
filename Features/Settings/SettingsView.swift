import SwiftUI

struct SettingsView: View {
    @AppStorage("prefillExerciseHistory") private var prefillExerciseHistory = true
    
    @AppStorage("timerFav1") private var timerFav1: Int = 30
    @AppStorage("timerFav2") private var timerFav2: Int = 60
    @AppStorage("timerFav3") private var timerFav3: Int = 90
    @AppStorage("requireRestTimerConfirm") private var requireRestTimerConfirm = true
    
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
            }
            .navigationTitle("Einstellungen")
        }
    }
}
