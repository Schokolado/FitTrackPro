import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.prefillExerciseHistory) private var prefillExerciseHistory = true

    @AppStorage(AppStorageKeys.timerFav1) private var timerFav1: Int = 30
    @AppStorage(AppStorageKeys.timerFav2) private var timerFav2: Int = 60
    @AppStorage(AppStorageKeys.timerFav3) private var timerFav3: Int = 90
    @AppStorage(AppStorageKeys.requireRestTimerConfirm) private var requireRestTimerConfirm = true

    var body: some View {
        NavigationStack {
            Form {
                trainingPlanSection
                restTimerSection
            }
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: - Sections

    private var trainingPlanSection: some View {
        Section(header: Text("Trainingsplan")) {
            Toggle("Werte aus Historie übernehmen", isOn: $prefillExerciseHistory)
            Text("Wenn aktiviert, werden beim Hinzufügen einer Übung zum Plan automatisch die Sätze, Wiederholungen und Gewichte aus dem letzten Training übernommen.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var restTimerSection: some View {
        Section(header: Text("Pausen-Timer")) {
            Toggle("Vorzeitiges Beenden bestätigen", isOn: $requireRestTimerConfirm)

            Stepper("Favorit 1: \(timerFav1) Sek", value: $timerFav1, in: 10...300, step: 10)
            Stepper("Favorit 2: \(timerFav2) Sek", value: $timerFav2, in: 10...300, step: 10)
            Stepper("Favorit 3: \(timerFav3) Sek", value: $timerFav3, in: 10...300, step: 10)
        }
    }
}

#Preview {
    SettingsView()
}
