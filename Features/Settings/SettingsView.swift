import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.prefillExerciseHistory) private var prefillExerciseHistory = true
    @AppStorage("zeroWeightIsBodyweight") private var zeroWeightIsBodyweight = true
    
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.healthKitAutoSync) private var healthKitAutoSync = true
    
    @AppStorage("timerFav1") private var timerFav1: Int = 30
    @AppStorage("timerFav2") private var timerFav2: Int = 60
    @AppStorage("timerFav3") private var timerFav3: Int = 90
    @AppStorage("requireRestTimerConfirm") private var requireRestTimerConfirm = true
    
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
    
    @Query(filter: #Predicate<WorkoutSession> { $0.syncedToHealthKit == false }) private var unsyncedWorkouts: [WorkoutSession]
    @Query(filter: #Predicate<WeightEntry> { $0.syncedToHealthKit == false }) private var unsyncedWeights: [WeightEntry]
    @Query(filter: #Predicate<FoodEntry> { $0.syncedToHealthKit == false }) private var unsyncedFoods: [FoodEntry]
    
    @State private var isSyncing = false
    @State private var showSyncCompleteAlert = false
    @State private var showWipeAlert = false
    @State private var showDeduplicateAlert = false
    
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var navId = UUID()
    
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
                    Toggle("0 kg als Körpergewicht werten", isOn: $zeroWeightIsBodyweight)
                    
                    Toggle("Werte aus Historie übernehmen", isOn: $prefillExerciseHistory)
                    Text("Wenn aktiviert, werden beim Hinzufügen einer Übung zum Plan automatisch die Sätze, Wiederholungen und Gewichte aus dem letzten Training übernommen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    HStack {
                        Toggle("Mit Apple Health verbinden", isOn: $healthKitEnabled)
                            .onChange(of: healthKitEnabled) { _, newValue in
                                if newValue {
                                    Task { @MainActor in
                                        do {
                                            try await HealthKitService.shared.requestAuthorization()
                                            await performInitialSync()
                                        } catch {
                                            print("HealthKit Authorization failed: \(error)")
                                        }
                                    }
                                }
                            }
                            .disabled(isSyncing)
                        
                        if isSyncing {
                            ProgressView()
                                .padding(.leading, 8)
                        }
                    }
                    
                    if healthKitEnabled {
                        Toggle("Automatisch synchronisieren", isOn: $healthKitAutoSync)
                        
                        Text(healthKitAutoSync
                            ? "Workouts und Gewichtsdaten werden nach dem Speichern automatisch exportiert."
                            : "Du kannst Daten manuell über einen Button exportieren.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Apple Health", systemImage: "heart.fill")
                } footer: {
                    if !HealthKitService.shared.isAvailable {
                        Text("Apple Health ist auf diesem Gerät nicht verfügbar.")
                    }
                }
                .alert("Sync abgeschlossen", isPresented: $showSyncCompleteAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Alle bisherigen Daten wurden erfolgreich mit Apple Health synchronisiert.")
                }
                
                Section {
                    HStack {
                        Label("Automatisch aktiv", systemImage: "checkmark.icloud.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Label("iCloud Sync", systemImage: "icloud.fill")
                } footer: {
                    Text("Deine Daten werden automatisch und sicher über deinen iCloud-Account synchronisiert (sofern dein iPhone in iCloud angemeldet ist).")
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

                Section(header: Text("Gefahrenzone").foregroundColor(.red)) {
                    Button(role: .destructive) {
                        showDeduplicateAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Duplikate bereinigen")
                        }
                    }
                    
                    Button(role: .destructive) {
                        showWipeAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Datenbank vollständig zurücksetzen")
                        }
                    }
                }
                
                Section {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        HStack {
                            Spacer()
                            Text("Version \(version) (\(build))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .alert("Duplikate löschen?", isPresented: $showDeduplicateAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Bereinigen", role: .destructive) {
                    deduplicateDatabase()
                }
            } message: {
                Text("Dies sucht nach allen doppelten Einträgen (z.B. Gewicht) und behält nur einen. Die gelöschten Duplikate werden auch aus iCloud entfernt.")
            }
            .alert("Datenbank zurücksetzen?", isPresented: $showWipeAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Endgültig löschen", role: .destructive) {
                    wipeDatabase()
                }
            } message: {
                Text("Bist du sicher? Alle lokal und in der iCloud gespeicherten Einträge (Gewicht, Mahlzeiten, Workouts, etc.) werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .alert("Synchronisation abgeschlossen", isPresented: $showSyncCompleteAlert) {
                Button("OK", role: .cancel) { }
            }
        }
        .id(navId)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabReselected"))) { notification in
            if let tab = notification.object as? Int, tab == 4 {
                navId = UUID()
            }
        }
        .onDisappear {
            CloudProfileService.shared.pushLocalToCloud()
        }
    }
    
    @MainActor
    private func wipeDatabase() {
        // Delete all models from SwiftData Context
        do {
            try modelContext.delete(model: DailyLog.self)
            try modelContext.delete(model: FoodEntry.self)
            try modelContext.delete(model: WeightEntry.self)
            try modelContext.delete(model: WorkoutSession.self)
            try modelContext.delete(model: WorkoutSet.self)
            try modelContext.delete(model: StepEntry.self)
            try modelContext.delete(model: SavedFood.self)
            try modelContext.delete(model: Recipe.self)
            try modelContext.delete(model: RecipeIngredient.self)
            try modelContext.delete(model: PlanExercise.self)
            try modelContext.delete(model: PlanGroup.self)
            try modelContext.delete(model: TrainingPlan.self)
            try modelContext.delete(model: Exercise.self)
            
            // Re-seed standard exercises
            SeedDataService.shared.seedExercisesIfNeeded(context: modelContext)
            
            healthKitEnabled = false
            healthKitAutoSync = false
            
            // Show alert or reset UI
            navId = UUID()
            
        } catch {
            print("Failed to wipe database: \(error)")
        }
    }
    
    @MainActor
    private func deduplicateDatabase() {
        do {
            let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp)])
            let allWeights = try modelContext.fetch(descriptor)
            
            var uniqueSeen: [(Date, Double)] = []
            var deleteCount = 0
            
            for entry in allWeights {
                let isDuplicate = uniqueSeen.contains {
                    abs($0.0.timeIntervalSince1970 - entry.timestamp.timeIntervalSince1970) < 60 &&
                    abs($0.1 - entry.weightKg) < 0.1
                }
                
                if isDuplicate {
                    modelContext.delete(entry)
                    deleteCount += 1
                } else {
                    uniqueSeen.append((entry.timestamp, entry.weightKg))
                }
            }
            
            // Deduplicate Exercises
            let exDescriptor = FetchDescriptor<Exercise>()
            let allExercises = try modelContext.fetch(exDescriptor)
            var canonicalExercises: [String: Exercise] = [:]
            
            for ex in allExercises {
                let nameKey = ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if let canonical = canonicalExercises[nameKey] {
                    if let sets = ex.workoutSets {
                        for s in sets { s.exercise = canonical }
                    }
                    if let plans = ex.planExercises {
                        for p in plans { p.exercise = canonical }
                    }
                    modelContext.delete(ex)
                    deleteCount += 1
                } else {
                    canonicalExercises[nameKey] = ex
                }
            }
            
            try modelContext.save()
            print("Deduplication finished. Deleted \(deleteCount) duplicate entries.")
            navId = UUID()
        } catch {
            print("Failed to deduplicate: \(error)")
        }
    }
    
    @MainActor
    private func performInitialSync() async {
        isSyncing = true
        
        let service = HealthKitService.shared
        
        // Import historical weights
        do {
            let imported = try await service.importHistoricalWeights()
            
            // Check for existing weights to prevent duplicates
            let descriptor = FetchDescriptor<WeightEntry>()
            let existingWeights = (try? modelContext.fetch(descriptor)) ?? []
            
            for item in imported {
                // Check if a weight entry already exists with similar timestamp and weight
                let exists = existingWeights.contains {
                    abs($0.timestamp.timeIntervalSince1970 - item.timestamp.timeIntervalSince1970) < 60 &&
                    abs($0.weightKg - item.weightKg) < 0.1
                }
                
                if !exists {
                    let entry = WeightEntry(weightKg: item.weightKg, timestamp: item.timestamp, notes: "Aus Apple Health importiert")
                    entry.syncedToHealthKit = true
                    modelContext.insert(entry)
                }
            }
        } catch {
            print("Failed to import historical weights: \(error)")
        }
        
        // Export existing data
        for workout in unsyncedWorkouts {
            do {
                try await service.exportWorkout(session: workout)
                workout.syncedToHealthKit = true
            } catch {
                print("Failed to sync workout: \(error)")
            }
        }
        
        for weight in unsyncedWeights {
            do {
                try await service.exportWeight(entry: weight)
                weight.syncedToHealthKit = true
            } catch {
                print("Failed to sync weight: \(error)")
            }
        }
        
        for food in unsyncedFoods {
            do {
                try await service.exportNutrition(entry: food)
                food.syncedToHealthKit = true
            } catch {
                print("Failed to sync food: \(error)")
            }
        }
        
        isSyncing = false
        showSyncCompleteAlert = true
    }
}
