import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    
    @State private var mood: Int = 3
    @State private var intensity: Int = 3
    @State private var notes: String = ""
    @State private var showConfetti = false
    @State private var showingCancelAlert = false
    
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @AppStorage(AppStorageKeys.healthKitAutoSync) private var healthKitAutoSync = true
    @AppStorage(AppStorageKeys.userBirthDate) private var birthDateInterval: Double = 0
    @AppStorage(AppStorageKeys.userBiologicalSex) private var userSex: String = "other"
    @AppStorage(AppStorageKeys.onboardingWeightKg) private var onboardingWeightKg: Double = 0
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weightEntries: [WeightEntry]
    @State private var syncToHealth: Bool = false
    @State private var calorieEstimate: WorkoutCalorieEstimate? = nil
    @State private var showingShareSheet = false
    
    // Computed statistics
    private var totalVolume: Double {
        session.sets?.filter { $0.isCompleted }
            .reduce(0) { $0 + ($1.actualWeight * Double($1.actualReps)) } ?? 0
    }
    
    private var totalSets: Int {
        session.sets?.filter { $0.isCompleted }.count ?? 0
    }
    
    private var durationString: String {
        let start = session.startTime
        let end = session.endTime ?? Date()
        let interval = end.timeIntervalSince(start)
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) Min."
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Success Header
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .scaleEffect(showConfetti ? 1.0 : 0.5)
                            .opacity(showConfetti ? 1.0 : 0.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5).delay(0.1), value: showConfetti)
                        
                        Text("Workout abgeschlossen!")
                            .font(.title2.bold())
                    }
                    .padding(.top, 20)
                    
                    // Stats Card
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            StatBadge(title: "Dauer", value: durationString, icon: "clock")
                            StatBadge(title: "Volumen", value: "\(Int(totalVolume)) kg", icon: "scalemass")
                            StatBadge(title: "Sätze", value: "\(totalSets)", icon: "number")
                            if let estimate = calorieEstimate {
                                StatBadge(title: "Verbrannt", value: "\(Int(estimate.calories)) kcal", icon: "flame.fill")
                            }
                        }
                        if let estimate = calorieEstimate {
                            HStack(spacing: 10) {
                                Text("Quelle: \(estimate.source.rawValue)")
                                if let avgHR = estimate.averageHeartRate {
                                    Text("• Ø Puls: \(Int(avgHR.rounded())) bpm")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)

                    // Share Workout inkl. optionalem Selfie
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.brand)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Workout teilen")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Grafik mit Stats & optionalem Selfie")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.brand)
                        }
                        .padding(14)
                        .background(Color.backgroundCard)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    // Muskelgruppen-Balance
                    let sessionBalanceStats = StatisticsViewModel.muscleGroupBreakdown(in: session)
                    if !sessionBalanceStats.isEmpty {
                        MuscleBalanceCard(
                            title: "Muskelgruppen-Balance",
                            stats: sessionBalanceStats,
                            availableMetrics: [.sets, .volume, .exercises],
                            showInsight: true,
                            configuredFocus: session.plan?.focus ?? .auto,
                            planName: session.plan?.name
                        )
                    }
                    
                    // Ratings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Wie fühlst du dich?")
                            .font(.headline)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: { mood = rating }) {
                                    Image(systemName: rating <= mood ? "star.fill" : "star")
                                        .font(.title)
                                        .foregroundColor(rating <= mood ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Divider().padding(.vertical, 8)
                        
                        Text("Wie anstrengend war es? (RPE)")
                            .font(.headline)
                        
                        Picker("Intensität", selection: $intensity) {
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5").tag(5)
                        }
                        .pickerStyle(.segmented)
                        
                        Text("1 = Sehr leicht • 5 = Maximum")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notizen")
                            .font(.headline)
                        
                        RichNotesEditor(text: $notes, minHeight: 120, placeholder: "Notizen zum Workout eingeben...")
                            
                        if healthKitEnabled {
                            Divider().padding(.vertical, 4)
                            Toggle("In Apple Health eintragen", isOn: $syncToHealth)
                        }
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(16)
                    
                }
                .padding()
            }
            .background(Color.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        showingCancelAlert = true
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveAndClose()
                    }
                    .bold()
                }
            }
            .onAppear {
                // Trigger animation
                showConfetti = true
                
                // Set endTime if not already set
                if session.endTime == nil {
                    session.endTime = Date()
                }
                
                // Init sync toggle
                syncToHealth = healthKitEnabled && healthKitAutoSync
            }
            .task {
                await resolveCalories()
            }
            .onChange(of: intensity) { _, _ in
                if calorieEstimate?.source == .metEstimate {
                    Task { await resolveCalories() }
                }
            }
            .alert("Training verwerfen?", isPresented: $showingCancelAlert) {
                Button("Ja, verwerfen", role: .destructive) {
                    cancelWorkout()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Bist du sicher, dass du das Training abbrechen und verwerfen möchtest? Alle bisherigen Einträge gehen verloren.")
            }
            .sheet(isPresented: $showingShareSheet) {
                WorkoutShareSheet(
                    session: session,
                    burnedCaloriesOverride: calorieEstimate?.calories,
                    averageHeartRateOverride: calorieEstimate?.averageHeartRate
                )
            }
        }
    }
    
    private func saveAndClose() {
        session.moodRating = mood
        session.intensityRating = intensity
        session.notes = notes
        if let estimate = calorieEstimate {
            session.burnedCalories = estimate.calories
            session.averageHeartRate = estimate.averageHeartRate
            session.calorieSource = estimate.source.rawValue
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
        
        if syncToHealth {
            Task {
                do {
                    try await HealthKitService.shared.exportWorkout(session: session)
                    session.syncedToHealthKit = true
                    try? modelContext.save()
                } catch {
                    print("HealthKit sync failed: \(error)")
                }
            }
        }
        
        // Let the caller know we're done so the fullScreenCover can be dismissed
        // In this architecture, we dismiss the sheet. The parent (WorkoutSessionView)
        // should observe the session's state or we dismiss the parent as well.
        // Easiest way: Post a notification or use a binding.
        NotificationCenter.default.post(name: .workoutFinished, object: nil)
    }
    
    private func cancelWorkout() {
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting session: \(error)")
        }
        NotificationCenter.default.post(name: .workoutCancelled, object: nil)
    }

    @MainActor
    private func resolveCalories() async {
        let weight = weightEntries.first?.weightKg ?? (onboardingWeightKg > 0 ? onboardingWeightKg : nil)
        let estimate = await HealthKitService.shared.resolveWorkoutCalories(
            startTime: session.startTime,
            endTime: session.endTime ?? Date(),
            rpeIntensity: intensity,
            weightKg: weight,
            birthDateTimestamp: birthDateInterval,
            biologicalSex: userSex,
            healthKitEnabled: healthKitEnabled
        )
        calorieEstimate = estimate
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.brand)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
