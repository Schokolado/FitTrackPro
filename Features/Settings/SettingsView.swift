import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.prefillExerciseHistory) private var prefillExerciseHistory = true
    
    @AppStorage("timerFav1") private var timerFav1: Int = 30
    @AppStorage("timerFav2") private var timerFav2: Int = 60
    @AppStorage("timerFav3") private var timerFav3: Int = 90
    @AppStorage("requireRestTimerConfirm") private var requireRestTimerConfirm = true
    
    @AppStorage("nutritionGoalCalories") private var nutritionGoalCalories: Double = 2500
    @AppStorage("nutritionGoalProtein") private var nutritionGoalProtein: Double = 150
    @AppStorage("nutritionGoalCarbs") private var nutritionGoalCarbs: Double = 250
    @AppStorage("nutritionGoalFat") private var nutritionGoalFat: Double = 70

    // Profil
    @AppStorage(AppStorageKeys.userName) private var userName: String = ""
    @AppStorage(AppStorageKeys.userBirthDate) private var birthDateInterval: Double = 0
    @AppStorage(AppStorageKeys.userBiologicalSex) private var userSex: String = "other"
    @AppStorage(AppStorageKeys.userHeightCm) private var heightCm: Double = 175
    @AppStorage(AppStorageKeys.dailyCalorieGoal) private var dailyCalorieGoal: Double = 2500
    @AppStorage(AppStorageKeys.dailyStepGoal) private var dailyStepGoal: Int = 10000
    
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Profil
                Section(header: Text("Mein Profil")) {
                    HStack {
                        Label("Name", systemImage: "person")
                        Spacer()
                        TextField("z.B. Max", text: $userName)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Geburtsdatum", systemImage: "calendar")
                        Spacer()
                        DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .onChange(of: birthDate) { _, new in
                                birthDateInterval = new.timeIntervalSince1970
                            }
                    }
                    HStack {
                        Label("Geschlecht", systemImage: "person.2")
                        Spacer()
                        Picker("", selection: $userSex) {
                            Text("Männlich").tag("male")
                            Text("Weiblich").tag("female")
                            Text("Divers").tag("other")
                        }
                        .labelsHidden()
                    }
                    HStack {
                        Label("Körpergröße", systemImage: "arrow.up.and.down")
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .foregroundColor(.secondary)
                        Stepper("", value: $heightCm, in: 140...220, step: 1)
                            .labelsHidden()
                    }
                }
                .onAppear {
                    if birthDateInterval > 0 {
                        birthDate = Date(timeIntervalSince1970: birthDateInterval)
                    }
                }

                // MARK: Ziele
                Section(header: Text("Tägliche Ziele")) {
                    HStack {
                        Label("Kalorien", systemImage: "flame")
                        Spacer()
                        TextField("kcal", value: $dailyCalorieGoal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: dailyCalorieGoal) { _, new in
                                nutritionGoalCalories = new // sync keys
                            }
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
                    HStack {
                        Label("Schritte / Tag", systemImage: "figure.walk")
                        Spacer()
                        TextField("Schritte", value: Binding(
                            get: { Double(dailyStepGoal) },
                            set: { dailyStepGoal = Int($0) }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    }
                }

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
            .navigationTitle("Einstellungen")
        }
    }
}
